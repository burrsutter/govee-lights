#!/usr/bin/env python3
"""Discover all Govee devices on the local network via LAN API."""

import socket
import json
import time

MULTICAST_GRP = "239.255.255.250"
SEND_PORT = 4001
RECV_PORT = 4002
SCAN_DURATION = 12  # seconds — some devices respond slowly


def discover():
    scan_msg = json.dumps(
        {"msg": {"cmd": "scan", "data": {"account_topic": "reserve"}}}
    ).encode()

    recv_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    recv_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    recv_sock.bind(("", RECV_PORT))
    recv_sock.settimeout(1)

    send_sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    found = {}
    deadline = time.time() + SCAN_DURATION
    last_send = 0

    while time.time() < deadline:
        if time.time() - last_send > 2:
            send_sock.sendto(scan_msg, (MULTICAST_GRP, SEND_PORT))
            last_send = time.time()
        try:
            data, addr = recv_sock.recvfrom(4096)
            d = json.loads(data)["msg"]["data"]
            ip = d.get("ip", addr[0])
            found[ip] = d
        except Exception:
            pass

    recv_sock.close()
    send_sock.close()
    return found


if __name__ == "__main__":
    print(f"Scanning for {SCAN_DURATION}s...")
    devices = discover()
    print(f"\nFound {len(devices)} device(s):\n")
    for ip, d in sorted(devices.items()):
        print(f"  {ip}  SKU={d.get('sku')}  device={d.get('device')}")
