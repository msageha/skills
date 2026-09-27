# popIn Aladdin Command Recipes

Ready-to-run `curl` examples for the endpoints listed in
[api-reference.md](api-reference.md). Base URL: `https://popin-aladdin.msageha.net/api`.
Run requests sequentially — the server serializes them behind one device session.

## Health / Device Info

```bash
curl -s "https://popin-aladdin.msageha.net/api/health" | jq .
curl -s "https://popin-aladdin.msageha.net/api/info" | jq .

# Proprietary control plane reachable?
curl -s -X POST "https://popin-aladdin.msageha.net/api/remote/ping" | jq .

# Light / remote button names accepted by /light and /key
curl -s "https://popin-aladdin.msageha.net/api/remote/buttons" | jq .

# Model / OS / storage / feature flags (TCP Version handshake)
curl -s "https://popin-aladdin.msageha.net/api/remote/version" | jq .

# Find Aladdins on the LAN (wait up to 3 s for answers)
curl -s "https://popin-aladdin.msageha.net/api/discover?wait=3" | jq .
```

## What's on Screen

```bash
# Foreground app (apps like YouTube are invisible to the DLNA /status)
curl -s "https://popin-aladdin.msageha.net/api/remote/device" | jq '{foreground_app, foreground_package}'

# Screenshot — the returned image_url is served by the device on its LAN
curl -s -X POST "https://popin-aladdin.msageha.net/api/capture" | jq .
```

## Ceiling Light

```bash
# Turn the light on / off
curl -s -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "on"}' | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "off"}' | jq .

# Brightness: 5 steps up / 3 steps down
curl -s -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "brighter", "repeat": 5}' | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "darker", "repeat": 3}' | jq .

# Color temperature / presets
curl -s -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "warmer", "repeat": 2}' | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "night"}' | jq .
```

## Playback Status

```bash
curl -s "https://popin-aladdin.msageha.net/api/status" | jq .

# Position and media details
curl -s "https://popin-aladdin.msageha.net/api/position" | jq .
curl -s "https://popin-aladdin.msageha.net/api/media" | jq .

# Transport state / supported protocols
curl -s "https://popin-aladdin.msageha.net/api/transport" | jq .
curl -s "https://popin-aladdin.msageha.net/api/protocol-info" | jq .
```

## Volume / Mute

```bash
curl -s "https://popin-aladdin.msageha.net/api/volume" | jq .
curl -s "https://popin-aladdin.msageha.net/api/mute" | jq .

curl -s -X POST "https://popin-aladdin.msageha.net/api/volume" \
  -H "Content-Type: application/json" -d '{"volume": 40}' | jq .

curl -s -X POST "https://popin-aladdin.msageha.net/api/mute" \
  -H "Content-Type: application/json" -d '{"mute": true}' | jq .
```

## Playback Control

```bash
curl -s -X POST "https://popin-aladdin.msageha.net/api/play" | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/pause" | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/stop" | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/next" | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/previous" | jq .

# Seek to 1:30
curl -s -X POST "https://popin-aladdin.msageha.net/api/seek" \
  -H "Content-Type: application/json" -d '{"seconds": 90}' | jq .

# Repeat all
curl -s -X POST "https://popin-aladdin.msageha.net/api/play-mode" \
  -H "Content-Type: application/json" -d '{"mode": "REPEAT_ALL"}' | jq .
```

## Cast a Media URL (replaces current content)

The URL must be reachable from the device's LAN.

```bash
# Video (autoplay)
curl -s -X POST "https://popin-aladdin.msageha.net/api/cast" \
  -H "Content-Type: application/json" \
  -d '{"uri": "http://192.168.1.50:8200/video/sample.mp4",
       "upnp_class": "object.item.videoItem"}' | jq .

# Image
curl -s -X POST "https://popin-aladdin.msageha.net/api/cast" \
  -H "Content-Type: application/json" \
  -d '{"uri": "http://192.168.1.50:8200/photo.jpg",
       "upnp_class": "object.item.imageItem"}' | jq .
```

## Launch Apps (deeplink / shortcut keys)

```bash
# Open a URL / app scheme on the device
curl -s -X POST "https://popin-aladdin.msageha.net/api/deeplink" \
  -H "Content-Type: application/json" -d '{"url": "https://www.youtube.com/tv"}' | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/deeplink" \
  -H "Content-Type: application/json" -d '{"url": "tver://"}' | jq .

# Remote shortcut keys
curl -s -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "youtube"}' | jq .

# Is an app installed?
curl -s "https://popin-aladdin.msageha.net/api/remote/apps/jp.co.tver.tvapp" | jq .
```

## Remote Keys (D-pad / focus / hardware)

`power` only opens the on-screen power menu; to switch the unit off use
`POST /power/off` below. A 200 means the UDP datagram was sent, not that the
unit is on.

```bash
# Navigate: down twice, then OK
curl -s -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "down", "repeat": 2}' | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "ok"}' | jq .

# Back / Home / Settings
curl -s -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "back"}' | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "home"}' | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "settings"}' | jq .

# Focus adjustment (one step each)
curl -s -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "focus_plus"}' | jq .
```

## Text / Voice Input

```bash
# Type into the focused on-screen input (focus it with /key first)
curl -s -X POST "https://popin-aladdin.msageha.net/api/keyboard" \
  -H "Content-Type: application/json" -d '{"text": "hello world"}' | jq .

# Voice command as text
curl -s -X POST "https://popin-aladdin.msageha.net/api/voice" \
  -H "Content-Type: application/json" -d '{"text": "天気を教えて"}' | jq .
```

## Maintenance / Power

```bash
# Free memory (kills background apps)
curl -s -X POST "https://popin-aladdin.msageha.net/api/memory/free" | jq .

# Photo memory (on-device album) and light-unit firmware
curl -s "https://popin-aladdin.msageha.net/api/remote/album" | jq '{count, free_space, light_version}'

# Power off — irreversible from this API, confirm with the user first
curl -s -X POST "https://popin-aladdin.msageha.net/api/power/off" \
  -H "Content-Type: application/json" -d '{"confirm": true}' | jq .
```

## Raw SOAP Passthrough (advanced)

Get-actions are read-only; anything else needs `confirm: true` — confirm with
the user and prefer the typed endpoints.

```bash
# Read transport info
curl -s -X POST "https://popin-aladdin.msageha.net/api/soap" \
  -H "Content-Type: application/json" \
  -d '{"service": "AVTransport", "action": "GetTransportInfo",
       "args": {"InstanceID": 0}}' | jq .

# Set volume via raw SOAP (confirm required)
curl -s -X POST "https://popin-aladdin.msageha.net/api/soap" \
  -H "Content-Type: application/json" \
  -d '{"service": "RenderingControl", "action": "SetVolume",
       "args": {"InstanceID": 0, "Channel": "Master", "DesiredVolume": 20},
       "confirm": true}' | jq .
```
