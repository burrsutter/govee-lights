#!/usr/bin/env bash
# Cycle through 80s tie-dye scenes. Press Ctrl+C to stop.

SCENES=(
  80s-tie-dye
  80s-tie-dye-shift
  80s-tie-dye-flip
  80s-tie-dye-inverse
  all-off
)

echo "Starting 80s tie-dye cycle. Press Ctrl+C to stop."

while true; do
  for scene in "${SCENES[@]}"; do
    python3 apply.py "$scene"
    sleep 6  # hold each scene after the fade completes
  done
done
