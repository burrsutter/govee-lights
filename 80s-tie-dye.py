#!/usr/bin/env python3
"""80s tie-dye animation — cycles groovy colors across all lights for ~30s."""

import time
from control import DEVICES, turn_on, set_brightness, set_color

# 80s tie-dye palette
PALETTE = [
    (255,  20, 147),  # hot pink
    (255, 165,   0),  # electric orange
    (255, 255,   0),  # neon yellow
    (  0, 255, 127),  # spring green
    (  0, 255, 255),  # cyan
    ( 75,   0, 130),  # deep purple
    (255,   0, 255),  # magenta
    (255,  69,   0),  # red-orange
]

DEVICE_NAMES = list(DEVICES.keys())
CYCLE_TIME = 2.0   # seconds per color shift
TOTAL_TIME = 32     # total animation length


def main():
    # Turn everything on bright
    for ip in DEVICES.values():
        turn_on(ip)
        time.sleep(0.1)
    for ip in DEVICES.values():
        set_brightness(ip, 100)
        time.sleep(0.1)

    print("~ 80s Tie-Dye Mode ~")
    print(f"  {len(PALETTE)} colors, {TOTAL_TIME}s, {CYCLE_TIME}s per shift\n")

    steps = int(TOTAL_TIME / CYCLE_TIME)
    for step in range(steps):
        for i, name in enumerate(DEVICE_NAMES):
            color_idx = (step + i) % len(PALETTE)
            r, g, b = PALETTE[color_idx]
            set_color(DEVICES[name], r, g, b)
            time.sleep(0.1)

        colors = [PALETTE[(step + i) % len(PALETTE)] for i in range(len(DEVICE_NAMES))]
        labels = " | ".join(
            f"{name}: ({r},{g},{b})"
            for name, (r, g, b) in zip(DEVICE_NAMES, colors)
        )
        remaining = TOTAL_TIME - int(step * CYCLE_TIME)
        print(f"  [{remaining:2d}s] {labels}")

        time.sleep(CYCLE_TIME)

    print("\nDone! Lights left on last color.")


if __name__ == "__main__":
    main()
