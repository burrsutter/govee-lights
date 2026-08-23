#!/usr/bin/env python3
"""
Interactive setup: discover Govee lights, flash each one to identify it,
assign a human-readable name, and save the mapping to devices.json.
"""

import json
import socket
import time

DEVICES_FILE = "devices.json"
CMD_PORT = 4003


# ---------- LAN control helpers ----------

def _send(ip: str, cmd: dict):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.sendto(json.dumps({"msg": cmd}).encode(), (ip, CMD_PORT))
    s.close()

def flash(ip: str):
    """Briefly turn the light on at full brightness, then off."""
    _send(ip, {"cmd": "brightness", "data": {"value": 100}})
    _send(ip, {"cmd": "turn", "data": {"value": 1}})
    time.sleep(2)
    _send(ip, {"cmd": "turn", "data": {"value": 0}})


# ---------- Discovery ----------

def discover(scan_duration: int = 12) -> dict:
    MULTICAST_GRP = "239.255.255.250"
    SEND_PORT = 4001
    RECV_PORT = 4002

    scan_msg = json.dumps(
        {"msg": {"cmd": "scan", "data": {"account_topic": "reserve"}}}
    ).encode()

    recv_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    recv_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    recv_sock.bind(("", RECV_PORT))
    recv_sock.settimeout(1)

    send_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    found = {}
    deadline = time.time() + scan_duration
    last_send = 0

    print(f"Scanning for {scan_duration}s", end="", flush=True)
    while time.time() < deadline:
        if time.time() - last_send > 2:
            send_sock.sendto(scan_msg, (MULTICAST_GRP, SEND_PORT))
            last_send = time.time()
        try:
            data, addr = recv_sock.recvfrom(4096)
            d = json.loads(data)["msg"]["data"]
            ip = d.get("ip", addr[0])
            if ip not in found:
                print(".", end="", flush=True)
            found[ip] = d
        except Exception:
            pass
    print()

    recv_sock.close()
    send_sock.close()
    return found


# ---------- Config helpers ----------

def load_config() -> dict:
    try:
        with open(DEVICES_FILE) as f:
            return json.load(f)
    except FileNotFoundError:
        return {"devices": {}}

def save_config(config: dict):
    with open(DEVICES_FILE, "w") as f:
        json.dump(config, f, indent=2)
    print(f"Saved to {DEVICES_FILE}")

def mac_already_named(config: dict, mac: str) -> str | None:
    """Return the existing name for this MAC, or None."""
    for name, info in config["devices"].items():
        if info.get("mac") == mac:
            return name
    return None


# ---------- Main ----------

def main():
    print("=== Govee Light Setup ===\n")

    config = load_config()
    devices = discover()

    if not devices:
        print("No devices found. Make sure LAN Control is enabled in the Govee app.")
        return

    print(f"\nFound {len(devices)} device(s). Will flash each one so you can identify it.\n")
    print("  Press Enter to skip naming a device, or type a name and press Enter.\n")

    for ip, d in sorted(devices.items()):
        mac = d.get("device", "unknown")
        sku = d.get("sku", "unknown")

        existing_name = mac_already_named(config, mac)
        if existing_name:
            print(f"  [{ip}]  SKU={sku}  MAC={mac}")
            print(f"    Already named: '{existing_name}' — skipping.")
            print()
            continue

        print(f"  [{ip}]  SKU={sku}  MAC={mac}")
        print(f"    Flashing now...", flush=True)
        flash(ip)

        name = input("    Enter a name for this light (or Enter to skip): ").strip()
        if name:
            config["devices"][name] = {
                "mac": mac,
                "sku": sku,
                "ip":  ip,
            }
            print(f"    Saved as '{name}'.")
        else:
            print("    Skipped.")
        print()

    if config["devices"]:
        save_config(config)
        print("\nCurrent device map:")
        for name, info in config["devices"].items():
            print(f"  {name:20s}  MAC={info['mac']}  IP={info['ip']}  SKU={info['sku']}")
    else:
        print("No devices named — nothing saved.")


if __name__ == "__main__":
    main()
