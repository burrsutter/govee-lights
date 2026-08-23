#!/usr/bin/env python3
"""Apply a scene (YAML preset) to Govee lights."""

import json
import os
import sys
import time
import yaml
from control import DEVICES, turn_on, turn_off, set_brightness, set_color, set_white

SCENES_DIR = os.path.join(os.path.dirname(__file__), "scenes")
STATE_FILE = os.path.join(os.path.dirname(__file__), ".scene-state.json")


def list_scenes():
    """Print available scene names."""
    files = sorted(f for f in os.listdir(SCENES_DIR) if f.endswith(".yaml"))
    if not files:
        print("No scenes found in scenes/")
        return
    print("Available scenes:")
    for f in files:
        print(f"  {f.removesuffix('.yaml')}")


def resolve_path(name):
    """Resolve a scene name or path to a YAML file path."""
    if "/" in name or name.endswith(".yaml"):
        return name
    return os.path.join(SCENES_DIR, f"{name}.yaml")


def normalize_keys(d):
    """Fix PyYAML 1.1 treating 'on'/'off' as boolean keys."""
    if not isinstance(d, dict):
        return d
    fixed = {}
    for k, v in d.items():
        if k is True:
            k = "on"
        elif k is False:
            k = "off"
        fixed[k] = v
    return fixed


def build_device_settings(scene):
    """Merge 'all' defaults with per-light overrides."""
    defaults = normalize_keys(scene.get("all", {}) or {})
    per_light = scene.get("lights", {}) or {}

    settings = {}
    for name in DEVICES:
        merged = dict(defaults)
        if name in per_light:
            merged.update(normalize_keys(per_light[name]))
        if merged:
            settings[name] = merged
    return settings


def apply_settings(name, cfg):
    """Send commands for one device. Order: on/off, brightness, color/white."""
    ip = DEVICES[name]

    if "on" in cfg:
        if cfg["on"]:
            turn_on(ip)
        else:
            turn_off(ip)
        time.sleep(0.1)

    if "brightness" in cfg:
        set_brightness(ip, cfg["brightness"])
        time.sleep(0.1)

    if "color" in cfg:
        r, g, b = cfg["color"]
        set_color(ip, r, g, b)
    elif "white" in cfg:
        set_white(ip, cfg["white"])


def load_state():
    """Load persisted light state. Returns empty dict if file missing."""
    if not os.path.exists(STATE_FILE):
        return {}
    with open(STATE_FILE) as f:
        return json.load(f)


def save_state(state):
    """Persist light state to disk."""
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def lerp(a, b, t):
    """Linear interpolate from a to b at fraction t (0.0–1.0). Returns int."""
    return int(round(a + (b - a) * t))


def lerp_color(start_rgb, end_rgb, t):
    """Lerp each RGB channel. Returns list of 3 ints."""
    return [lerp(s, e, t) for s, e in zip(start_rgb, end_rgb)]


def apply_transition(device_settings, transition_secs):
    """Fade all devices from current state to target over transition_secs."""
    state = load_state()
    steps = max(5, int(transition_secs * 5))
    interval = transition_secs / steps

    # Snapshot start and target per device before the loop begins
    transitions = {
        name: {"start": state.get(name, {}), "target": target}
        for name, target in device_settings.items()
    }

    for step in range(steps):
        t = (step + 1) / steps  # 1/steps on first step, 1.0 on last
        step_start = time.time()
        is_first = step == 0
        is_last = step == steps - 1

        for name, info in transitions.items():
            ip = DEVICES[name]
            start = info["start"]
            target = info["target"]

            target_on = target.get("on", True)
            start_on = start.get("on", True)  # assume on if state unknown

            # off → on: power on at first step; brightness will fade from 0
            if is_first and target_on and not start_on:
                turn_on(ip)
                time.sleep(0.05)

            # Brightness: lerp from start to target (0 when off)
            start_bri = 0 if not start_on else start.get("brightness", 100)
            end_bri = 0 if not target_on else target.get("brightness", 100)
            set_brightness(ip, lerp(start_bri, end_bri, t))
            time.sleep(0.05)

            # Color / white: interpolate within same mode, switch at midpoint across modes
            start_color = start.get("color")
            start_white = start.get("white")
            target_color = target.get("color")
            target_white = target.get("white")

            if target_color and start_color:
                # color → color: lerp each channel
                set_color(ip, *lerp_color(start_color, target_color, t))
            elif target_white and start_white:
                # white → white: lerp kelvin
                set_white(ip, lerp(start_white, target_white, t))
            elif target_color and start_white:
                # white → color: keep white first half, switch to color at midpoint
                if t >= 0.5:
                    set_color(ip, *target_color)
                else:
                    set_white(ip, start_white)
            elif target_white and start_color:
                # color → white: keep color first half, switch to white at midpoint
                if t >= 0.5:
                    set_white(ip, target_white)
                else:
                    set_color(ip, *start_color)
            elif target_color:
                set_color(ip, *target_color)
            elif target_white:
                set_white(ip, target_white)

            # on → off: power off only at final step (after brightness hits 0)
            if is_last and not target_on:
                turn_off(ip)

        elapsed = time.time() - step_start
        time.sleep(max(0, interval - elapsed))

    # Persist final state
    for name, info in transitions.items():
        target = info["target"]
        state[name] = {
            "on": target.get("on", True),
            "brightness": target.get("brightness", 100),
            "color": target.get("color"),
            "white": target.get("white"),
        }
    save_state(state)


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print("Usage:")
        print("  python apply.py <scene-name>          # e.g. movie-night")
        print("  python apply.py scenes/custom.yaml      # direct path")
        print("  python apply.py --list                 # list available scenes")
        sys.exit(0)

    if sys.argv[1] == "--list":
        list_scenes()
        sys.exit(0)

    path = resolve_path(sys.argv[1])
    if not os.path.exists(path):
        print(f"Scene not found: {path}")
        sys.exit(1)

    with open(path) as f:
        scene = yaml.safe_load(f)

    device_settings = build_device_settings(scene)
    if not device_settings:
        print("No device settings found in scene.")
        sys.exit(1)

    scene_name = os.path.basename(path).removesuffix(".yaml")
    transition = scene.get("transition") or 0

    print(f"Applying scene: {scene_name}")

    if transition and os.path.exists(STATE_FILE):
        print(f"  Fading over {transition}s ({max(5, int(transition * 5))} steps)...")
        apply_transition(device_settings, transition)
    else:
        if transition:
            print("  No prior state — applying instantly.")
        state = load_state()
        for name, cfg in device_settings.items():
            parts = []
            if "on" in cfg:
                parts.append("ON" if cfg["on"] else "OFF")
            if "brightness" in cfg:
                parts.append(f"brightness={cfg['brightness']}%")
            if "color" in cfg:
                parts.append(f"color={cfg['color']}")
            if "white" in cfg:
                parts.append(f"white={cfg['white']}K")
            apply_settings(name, cfg)
            print(f"  {name}: {', '.join(parts)}")
            time.sleep(0.1)
            state[name] = {
                "on": cfg.get("on", True),
                "brightness": cfg.get("brightness", 100),
                "color": cfg.get("color"),
                "white": cfg.get("white"),
            }
        save_state(state)

    print("Done.")


if __name__ == "__main__":
    main()
