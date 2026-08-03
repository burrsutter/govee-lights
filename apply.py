#!/usr/bin/env python3
"""Apply a scene (YAML preset) to Govee lights."""

import os
import sys
import time
import yaml
from control import DEVICES, turn_on, turn_off, set_brightness, set_color, set_white

SCENES_DIR = os.path.join(os.path.dirname(__file__), "scenes")


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
        time.sleep(0.05)

    if "brightness" in cfg:
        set_brightness(ip, cfg["brightness"])
        time.sleep(0.05)

    if "color" in cfg:
        r, g, b = cfg["color"]
        set_color(ip, r, g, b)
    elif "white" in cfg:
        set_white(ip, cfg["white"])


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
    print(f"Applying scene: {scene_name}")

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
        time.sleep(0.05)

    print("Done.")


if __name__ == "__main__":
    main()
