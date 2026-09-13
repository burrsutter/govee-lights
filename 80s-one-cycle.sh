#!/usr/bin/env bash
# Run through all 80s tie-dye scenes once, ending with lights off.

SCENES=(
  80s-tie-dye
  all-off
)

echo "Running 80s tie-dye cycle once..."

for scene in "${SCENES[@]}"; do
  python3 apply.py "$scene"
  sleep 6  # hold each scene after the fade completes
done

echo "Done."
