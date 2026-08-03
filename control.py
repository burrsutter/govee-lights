#!/usr/bin/env python3
"""Control Govee devices via LAN API (UDP, no cloud)."""

import socket
import json

CMD_PORT = 4003

# Known devices (from discovery)
DEVICES = {
    "floor-lamp-1": "192.168.4.28",
    "floor-lamp-2": "192.168.4.49",
    "neon-rope-1":  "192.168.4.42",
    "neon-rope-2":  "192.168.4.43",
}


def send_cmd(ip: str, cmd: dict):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.sendto(json.dumps({"msg": cmd}).encode(), (ip, CMD_PORT))
    s.close()


def turn_on(ip: str):
    send_cmd(ip, {"cmd": "turn", "data": {"value": 1}})


def turn_off(ip: str):
    send_cmd(ip, {"cmd": "turn", "data": {"value": 0}})


def set_brightness(ip: str, level: int):
    """level: 0–100"""
    send_cmd(ip, {"cmd": "brightness", "data": {"value": level}})


def set_color(ip: str, r: int, g: int, b: int):
    """RGB values 0–255."""
    send_cmd(ip, {"cmd": "colorwc", "data": {"color": {"r": r, "g": g, "b": b}, "colorTemInKelvin": 0}})


def set_white(ip: str, kelvin: int = 4000):
    """Color temperature in Kelvin (2000–9000)."""
    send_cmd(ip, {"cmd": "colorwc", "data": {"color": {"r": 0, "g": 0, "b": 0}, "colorTemInKelvin": kelvin}})


def all_devices(fn, *args):
    for ip in DEVICES.values():
        fn(ip, *args)


if __name__ == "__main__":
    import sys

    usage = """
Usage:
  python control.py on  [name|all]
  python control.py off [name|all]
  python control.py color <r> <g> <b> [name|all]
  python control.py white <kelvin>     [name|all]
  python control.py dim  <0-100>       [name|all]

Device names: """ + ", ".join(DEVICES.keys()) + " or 'all'\n"

    if len(sys.argv) < 2:
        print(usage)
        sys.exit(1)

    cmd = sys.argv[1]
    target = sys.argv[-1] if sys.argv[-1] in {**DEVICES, "all"} else "all"
    ips = list(DEVICES.values()) if target == "all" else [DEVICES[target]]

    if cmd == "on":
        for ip in ips: turn_on(ip)
        print(f"ON → {target}")
    elif cmd == "off":
        for ip in ips: turn_off(ip)
        print(f"OFF → {target}")
    elif cmd == "color" and len(sys.argv) >= 5:
        r, g, b = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
        for ip in ips: set_color(ip, r, g, b)
        print(f"COLOR ({r},{g},{b}) → {target}")
    elif cmd == "white" and len(sys.argv) >= 3:
        k = int(sys.argv[2])
        for ip in ips: set_white(ip, k)
        print(f"WHITE {k}K → {target}")
    elif cmd == "dim" and len(sys.argv) >= 3:
        level = int(sys.argv[2])
        for ip in ips: set_brightness(ip, level)
        print(f"DIM {level}% → {target}")
    else:
        print(usage)
