#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
resources="$repo_root/Resources"
teams="$resources/Seed/2026/teams.json"
drivers="$resources/Seed/2026/drivers.json"
circuits="$resources/Seed/2026/circuits.json"
tracks="$resources/Tracks/2026"

find "$resources" -name '*.json' -type f -exec jq empty {} \;

jq -e '
  .schemaVersion == 1
  and (.teams | length == 11)
  and ([.teams[].teamId] | unique | length == 11)
  and (all(.teams[]; (.localizedName | length > 0) and (.primaryColor | test("^#[0-9A-F]{6}$"))))
' "$teams" >/dev/null

jq -e --slurpfile teams "$teams" '
  .schemaVersion == 1
  and (.drivers | length == 22)
  and ([.drivers[].id] | unique | length == 22)
  and ([.drivers[].number] | unique | length == 22)
  and (all(.drivers[]; (.localizedName | length > 0)))
  and (($teams[0].teams | map(.teamId)) as $teamIds | ([.drivers[].teamId] - $teamIds | length == 0))
' "$drivers" >/dev/null

jq -e '
  .schemaVersion == 1
  and (.circuits | length == 23)
  and ([.circuits[].round] == [range(1; 24)])
  and ([.circuits[].meetingKey] | unique | length == 23)
  and ([.circuits[].trackAssetId] | unique | length == 23)
  and (all(.circuits[]; .geometryStatus == "available"))
' "$circuits" >/dev/null

track_count=$(find "$tracks" -name 'circuit-*-2026.json' -type f | wc -l | tr -d ' ')
test "$track_count" -eq 23

available_track_count=$(find "$tracks" -name 'circuit-*-2026.json' -type f -exec jq -r 'select(.geometryStatus == "available") | .trackAssetId' {} \; | wc -l | tr -d ' ')
test "$available_track_count" -eq 23

for track in "$tracks"/circuit-*-2026.json; do
  jq -e '
    .schemaVersion == 1
    and (.rendering.stroke == "singleColor")
    and (.rendering.showsCornerNumbers == true)
    and (.rendering.showsSegmentColors == false)
    and (
      if .geometryStatus == "available"
      then (.pathPoints | length > 10) and (.corners | length > 0)
      else .geometryStatus == "pendingManual" and (.pathPoints | length == 0) and (.corners | length == 0)
      end
    )
    and (all(.pathPoints[]; .x >= 0 and .x <= 1 and .y >= 0 and .y <= 1))
    and (all(.corners[]; .x >= 0 and .x <= 1 and .y >= 0 and .y <= 1))
  ' "$track" >/dev/null
done

printf 'Apex resources valid: 11 teams, 22 drivers, 23 rounds, %s track files.\n' "$track_count"
