# govee-lights

Programmatic control of Govee smart lights via the local LAN API — no cloud, no API key.

## Devices

| Name | IP | MAC | SKU | Description |
|---|---|---|---|---|
| floor-lamp-1 | 192.168.4.49 | 30:BA:C1:30:38:37:52:48 | H6076 | Govee RGBIC Floor Lamp Basic 2 |
| floor-lamp-2 | 192.168.4.28 | 3D:97:EF:8D:84:C6:40:93 | H6076 | Govee RGBIC Floor Lamp Basic 2 |
| neon-rope-black | 192.168.4.42 | 16:89:C2:32:34:39:05:54 | H61D5 | Govee RGBIC Neon Rope Light 2 |
| neon-rope-white | 192.168.4.43 | 11:21:CF:39:32:35:3D:2A | H61D5 | Govee RGBIC Neon Rope Light 2 |

## Setup

```bash
python3 -m venv .venv
source .venv/bin/activate
```

No external dependencies — uses only Python stdlib (`socket`, `json`).

## Usage

```bash
# Discover devices
python discover.py

# Control
python control.py on all
python control.py off floor-lamp-1
python control.py color 255 0 128 neon-rope-1
python control.py white 4000 all
python control.py dim 30 all
```

## Protocol

- Discovery: UDP multicast `239.255.255.250:4001`, responses on `:4002`
- Commands: UDP unicast to device IP, port `4003`
- Payload: `{"msg": {"cmd": "...", "data": {...}}}`
- Must enable **LAN Control** in the Govee app per device (Device → Gear → LAN Control)
