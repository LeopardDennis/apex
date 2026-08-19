#!/usr/bin/env python3
"""Generate Apex track JSON for MADRING and Sepang from verified references."""

from __future__ import annotations

import argparse
import json
import math
import re
import xml.etree.ElementTree as ET
from pathlib import Path


MADRING_CORNERS = {
    1: (0.14, 0.46),
    2: (0.075, 0.50),
    3: (0.075, 0.36),
    4: (0.36, 0.11),
    5: (0.44, 0.225),
    6: (0.49, 0.14),
    7: (0.55, 0.205),
    8: (0.62, 0.075),
    9: (0.64, 0.19),
    10: (0.81, 0.10),
    11: (0.83, 0.225),
    12: (0.97, 0.22),
    13: (0.735, 0.225),
    14: (0.68, 0.305),
    15: (0.55, 0.28),
    16: (0.56, 0.42),
    17: (0.57, 0.49),
    18: (0.485, 0.585),
    19: (0.475, 0.76),
    20: (0.275, 0.73),
    21: (0.33, 0.94),
    22: (0.17, 0.99),
}

SEPANG_CORNER_SOURCE_INDICES = {
    1: 96,
    2: 107,
    3: 123,
    4: 140,
    5: 157,
    6: 169,
    7: 4,
    8: 11,
    9: 18,
    10: 30,
    11: 40,
    12: 48,
    13: 56,
    14: 64,
    15: 78,
}


def distance(first: tuple[float, float], second: tuple[float, float]) -> float:
    return math.hypot(second[0] - first[0], second[1] - first[1])


def resample_closed(points: list[tuple[float, float]], count: int) -> list[tuple[float, float]]:
    if points[0] != points[-1]:
        points = points + [points[0]]
    segment_lengths = [distance(points[index], points[index + 1]) for index in range(len(points) - 1)]
    cumulative = [0.0]
    for segment_length in segment_lengths:
        cumulative.append(cumulative[-1] + segment_length)
    total = cumulative[-1]
    result: list[tuple[float, float]] = []
    segment_index = 0
    for sample_index in range(count):
        target = total * sample_index / count
        while segment_index + 1 < len(cumulative) and cumulative[segment_index + 1] < target:
            segment_index += 1
        segment_length = segment_lengths[segment_index]
        fraction = 0.0 if segment_length == 0 else (target - cumulative[segment_index]) / segment_length
        start = points[segment_index]
        end = points[segment_index + 1]
        result.append((start[0] + (end[0] - start[0]) * fraction, start[1] + (end[1] - start[1]) * fraction))
    return result


def nearest_index(points: list[tuple[float, float]], target: tuple[float, float]) -> int:
    return min(range(len(points)), key=lambda index: distance(points[index], target))


def rotate(points: list[tuple[float, float]], start_index: int) -> list[tuple[float, float]]:
    return points[start_index:] + points[:start_index]


def normalize(points: list[tuple[float, float]], bounds: tuple[float, float, float, float]) -> list[dict[str, float]]:
    min_x, min_y, width, height = bounds
    return [
        {"x": round((x_value - min_x) / width, 6), "y": round((y_value - min_y) / height, 6)}
        for x_value, y_value in points
    ]


def tangent_angle(points: list[tuple[float, float]], index: int) -> float:
    previous = points[(index - 2) % len(points)]
    following = points[(index + 2) % len(points)]
    return round(math.degrees(math.atan2(following[1] - previous[1], following[0] - previous[0])), 2)


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def base_asset(track_asset_id: str, circuit_key: int, circuit_name: str, source: dict) -> dict:
    return {
        "schemaVersion": 1,
        "trackAssetId": track_asset_id,
        "circuitKey": circuit_key,
        "circuitName": circuit_name,
        "geometryStatus": "available",
        "rendering": {
            "stroke": "singleColor",
            "showsCornerNumbers": True,
            "showsSegmentColors": False,
        },
        "source": source,
        "rotationDegrees": 0,
    }


def parse_madring_path(svg_path: Path) -> tuple[list[tuple[float, float]], tuple[float, float]]:
    root = ET.parse(svg_path).getroot()
    view_box = [float(value) for value in root.attrib["viewBox"].split()]
    track = next(
        element
        for element in root.iter()
        if element.tag.endswith("path") and element.attrib.get("class") == "st0"
    )
    tokens = re.findall(r"[A-Za-z]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?", track.attrib["d"])
    cursor = 0
    command = ""
    current = (0.0, 0.0)
    start = (0.0, 0.0)
    points: list[tuple[float, float]] = []

    while cursor < len(tokens):
        if tokens[cursor].isalpha():
            command = tokens[cursor]
            cursor += 1
        if command == "M":
            current = (float(tokens[cursor]), float(tokens[cursor + 1]))
            start = current
            points.append(current)
            cursor += 2
            command = "c"
        elif command == "c":
            values = [float(value) for value in tokens[cursor : cursor + 6]]
            cursor += 6
            control_1 = (current[0] + values[0], current[1] + values[1])
            control_2 = (current[0] + values[2], current[1] + values[3])
            end = (current[0] + values[4], current[1] + values[5])
            for step in range(1, 25):
                t_value = step / 24
                inverse = 1 - t_value
                x_value = (
                    inverse**3 * current[0]
                    + 3 * inverse**2 * t_value * control_1[0]
                    + 3 * inverse * t_value**2 * control_2[0]
                    + t_value**3 * end[0]
                )
                y_value = (
                    inverse**3 * current[1]
                    + 3 * inverse**2 * t_value * control_1[1]
                    + 3 * inverse * t_value**2 * control_2[1]
                    + t_value**3 * end[1]
                )
                points.append((x_value, y_value))
            current = end
        elif command in {"Z", "z"}:
            points.append(start)
            cursor += 1
            break
        else:
            raise ValueError(f"Unsupported SVG command: {command}")
    return points, (view_box[2], view_box[3])


def make_madring(svg_path: Path) -> dict:
    dense, image_size = parse_madring_path(svg_path)
    points = resample_closed(dense, 800)
    image_width, image_height = image_size
    targets = {
        number: (x_percent * image_width, y_percent * image_height)
        for number, (x_percent, y_percent) in MADRING_CORNERS.items()
    }

    current_indices = [nearest_index(points, targets[number]) for number in range(1, 23)]
    forward_distance = sum(
        (current_indices[index + 1] - current_indices[index]) % len(points)
        for index in range(len(current_indices) - 1)
    )
    reverse_distance = sum(
        (current_indices[index] - current_indices[index + 1]) % len(points)
        for index in range(len(current_indices) - 1)
    )
    if reverse_distance < forward_distance:
        points.reverse()

    start_target = (0.128 * image_width, 0.575 * image_height)
    points = rotate(points, nearest_index(points, start_target))
    min_x = min(point[0] for point in points)
    max_x = max(point[0] for point in points)
    min_y = min(point[1] for point in points)
    max_y = max(point[1] for point in points)
    bounds = (min_x, min_y, max_x - min_x, max_y - min_y)
    normalized = normalize(points, bounds)
    corners = []
    for number in range(1, 23):
        index = nearest_index(points, targets[number])
        corners.append(
            {
                "number": number,
                "angleDegrees": tangent_angle(points, index),
                **normalized[index],
            }
        )

    asset = base_asset(
        "circuit-153",
        153,
        "Madring",
        {
            "provider": "MADRING official circuit map",
            "url": "https://www.madring.com/en/circuit",
            "sourceYear": 2026,
            "note": "Centerline sampled from the official SVG; corner positions snapped from the official interactive 1–22 markers. Official artwork is not redistributed.",
        },
    )
    asset.update(
        {
            "viewBox": {"minX": round(min_x, 3), "minY": round(min_y, 3), "width": round(bounds[2], 3), "height": round(bounds[3], 3)},
            "pathPoints": normalized,
            "corners": corners,
            "startFinishMarker": normalized[0],
            "directionMarker": normalized[18],
            "pitLanePath": [],
        }
    )
    return asset


def make_sepang(overpass_path: Path) -> dict:
    source = json.loads(overpass_path.read_text(encoding="utf-8"))
    elements = {element["id"]: element for element in source["elements"]}
    first = elements[23410503]["geometry"]
    second = elements[144359489]["geometry"]
    geometry = first + second[1:]
    mean_latitude = sum(point["lat"] for point in geometry) / len(geometry)
    longitude_scale = math.cos(math.radians(mean_latitude))

    def project(point: dict) -> tuple[float, float]:
        return (point["lon"] * longitude_scale, -point["lat"])

    raw_points = [project(point) for point in geometry]
    corner_targets = {
        number: raw_points[source_index]
        for number, source_index in SEPANG_CORNER_SOURCE_INDICES.items()
    }
    start_target = project(geometry[85])
    points = resample_closed(raw_points, 800)
    points = rotate(points, nearest_index(points, start_target))

    min_x = min(point[0] for point in points)
    max_x = max(point[0] for point in points)
    min_y = min(point[1] for point in points)
    max_y = max(point[1] for point in points)
    bounds = (min_x, min_y, max_x - min_x, max_y - min_y)
    normalized = normalize(points, bounds)
    corners = []
    for number in range(1, 16):
        index = nearest_index(points, corner_targets[number])
        corners.append(
            {
                "number": number,
                "angleDegrees": tangent_angle(points, index),
                **normalized[index],
            }
        )

    pit_lane = [project(point) for point in elements[144359483]["geometry"]]
    asset = base_asset(
        "circuit-12",
        12,
        "Sepang International Circuit",
        {
            "provider": "OpenStreetMap geometry, verified with PETRONAS Sepang and Yamaha official references",
            "url": "https://www.openstreetmap.org/way/23410503",
            "sourceYear": 2026,
            "note": "Main course combines OSM ways 23410503 and 144359489 (© OpenStreetMap contributors, ODbL). The 15 corner positions were cross-checked against official circuit references.",
        },
    )
    asset.update(
        {
            "viewBox": {"minX": round(min_x, 8), "minY": round(min_y, 8), "width": round(bounds[2], 8), "height": round(bounds[3], 8)},
            "pathPoints": normalized,
            "corners": corners,
            "startFinishMarker": normalized[0],
            "directionMarker": normalized[18],
            "pitLanePath": normalize(pit_lane, bounds),
        }
    )
    return asset


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--madring-svg", type=Path, required=True)
    parser.add_argument("--sepang-osm", type=Path, required=True)
    parser.add_argument("--output-directory", type=Path, required=True)
    arguments = parser.parse_args()
    write_json(arguments.output_directory / "circuit-153-2026.json", make_madring(arguments.madring_svg))
    write_json(arguments.output_directory / "circuit-12-2026.json", make_sepang(arguments.sepang_osm))


if __name__ == "__main__":
    main()
