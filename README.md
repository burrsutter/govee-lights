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
pip install -r requirements.txt
```

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

### Scenes

Define reusable presets as YAML files in `scenes/` and apply them with one command:

```bash
python apply.py movie-night          # load scenes/movie-night.yaml
python apply.py scenes/custom.yaml   # or pass a direct path
python apply.py --list               # list available scenes
```

Example scene (`scenes/movie-night.yaml`):

```yaml
lights:
  floor-lamp-1:
    on: true
    brightness: 30
    white: 3000
  floor-lamp-2:
    on: false
  neon-rope-black:
    on: true
    brightness: 50
    color: [0, 0, 128]
```

Use `all:` to set every device at once, with optional per-light overrides:

```yaml
all:
  on: true
  brightness: 20
  white: 3000
lights:
  neon-rope-black:
    brightness: 100
    color: [255, 0, 0]
```

Supported keys: `on` (bool), `brightness` (0-100), `color` ([r, g, b]), `white` (kelvin).

## Protocol

- Discovery: UDP multicast `239.255.255.250:4001`, responses on `:4002`
- Commands: UDP unicast to device IP, port `4003`
- Payload: `{"msg": {"cmd": "...", "data": {...}}}`
- Must enable **LAN Control** in the Govee app per device (Device → Gear → LAN Control)

## Native Mac App (GoveeMenuBar)

SwiftUI menu bar app that mirrors the Python LAN control, no cloud or API key.

### Quick Start

```bash
# 1. Secrets
cp .env.example .env
# edit GOVEE_LIGHT_IPS if your IPs differ (see .env.example)

# 2. CLI (bash wrapper around Python LAN protocol)
scripts/govee status
scripts/govee on all
scripts/govee color 255 0 128 neon-rope-black
scripts/govee white 4000 all
scripts/govee discover   # multicast scan ~6s

# 3. Menu Bar App
swift run GoveeMenuBar          # icon: lightstrip.2
# or build release
swift build -c release --disable-sandbox
open .build/debug/GoveeMenuBar
```

For a persistent app that launches after login:

```bash
scripts/install-macos-app
open -n ~/Applications/GoveeMenuBar.app --args --enable-launch-at-login
```

The installed app has a **Launch at Login** checkbox in its menu. macOS may ask
you to approve it under **System Settings → General → Login Items**. The installer
copies `.env` to `~/.config/govee-lights/.env` only when that file does not already
exist, keeping the installed app independent of this repository.

The installer also seeds `~/.config/govee-lights/scenes/` with the repository's
YAML scenes without overwriting existing files. Add new `.yaml` or `.yml` files to
that directory and restart the app; they will appear in the searchable scene picker.
The filename becomes the scene ID and display name. Optional top-level `name:` and
`icon:` fields can override the displayed label and SF Symbol.

> Requires **LAN Control** enabled per device (Govee app → Device → Gear → LAN Control) and same LAN/VLAN. UDP ports 4001-4003 must not be firewalled.

### Configuration

Secrets live in `.env` (git-ignored, see `.env.example`).

```bash
GOVEE_LIGHT_IPS=192.168.4.49,192.168.4.28,192.168.4.42,192.168.4.43
# Alternatives:
# GOVEE_LIGHTS_JSON={"floor-lamp-1":"192.168.4.49",...}
# GOVEE_FLOOR_LAMP_1_IP=192.168.4.49
```

Resolution order: shell env → `.env` next to executable/repo → `~/.config/govee-lights/.env` → defaults. See `GoveeMenuBar/Services/GoveeConfig.swift`.

### App

- **Linked** toggle + **All Lights** sliders (brightness, ColorPicker → Apply, temperature 2000-9000K)
- **Independent** per-light disclosure with on/off, brightness, color, white
- **Presets**: Bright White, Movie (warm floor + blue neon), Vibrant, Ambient, 80s Tie-Dye, All Off — maps to `scenes/*.yaml`
- Polling is optimistic (UDP fire-and-forget); state is local, no HTTP GET. Future `devStatus` listener can be added.

### Project Layout

```
GoveeMenuBar/
  GoveeMenuBarApp.swift          # MenuBarExtra, GoveeManager @StateObject
  Models/GoveeDevice.swift       # GoveeDevice, GoveeState, RGBColor, GoveePreset
  Services/
    GoveeConfig.swift            # env/.env resolution
    GoveeLANClient.swift         # actor, UDP to :4003 (turn/brightness/colorwc)
    GoveeDiscovery.swift         # BSD multicast scan 239.255.255.250:4001→:4002
    GoveeManager.swift           # @MainActor, presets, all/per-device control
  Views/
    GoveeMenuBarView.swift
    GoveeAllLightsView.swift
    GoveeLightControlView.swift
scripts/govee                    # bash CLI (sources .env, delegates to python sockets)
Package.swift                    # swift-tools-version 5.9, macOS 14
```

See also [`elgato-key-lights`](../elgato-key-lights) for the Elgato Key Light Air companion app.
