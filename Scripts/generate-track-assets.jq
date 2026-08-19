def minimum: reduce .[] as $value (null; if . == null or $value < . then $value else . end);
def maximum: reduce .[] as $value (null; if . == null or $value > . then $value else . end);

(.x | minimum) as $minX
| (.x | maximum) as $maxX
| (.y | minimum) as $minY
| (.y | maximum) as $maxY
| ($maxX - $minX) as $width
| ($maxY - $minY) as $height
| {
    schemaVersion: 1,
    trackAssetId: "circuit-\(.circuitKey)",
    circuitKey: .circuitKey,
    circuitName: .circuitName,
    geometryStatus: "available",
    rendering: {
      stroke: "singleColor",
      showsCornerNumbers: true,
      showsSegmentColors: false
    },
    source: {
      provider: "MultiViewer via OpenF1 circuit_info_url",
      url: "https://api.multiviewer.app/api/v1/circuits/\(.circuitKey)/2026",
      sourceYear: .year,
      note: "Normalized for Apex; verify redistribution terms before release."
    },
    rotationDegrees: (.rotation // 0),
    viewBox: {
      minX: $minX,
      minY: $minY,
      width: $width,
      height: $height
    },
    pathPoints: [
      range(0; (.x | length)) as $index
      | {
          x: ((.x[$index] - $minX) / $width),
          y: ((.y[$index] - $minY) / $height)
        }
    ],
    corners: [
      .corners[]
      | {
          number: .number,
          angleDegrees: .angle,
          x: ((.trackPosition.x - $minX) / $width),
          y: ((.trackPosition.y - $minY) / $height)
        }
    ],
    startFinishMarker: {
      x: ((.x[0] - $minX) / $width),
      y: ((.y[0] - $minY) / $height)
    },
    directionMarker: null,
    pitLanePath: []
  }
