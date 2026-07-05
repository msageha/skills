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

# Color temperature / scenes
curl -s -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "warmer", "repeat": 2}' | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "night"}' | jq .
```

## Playback Status

```bash
curl -s "https://popin-aladdin.msageha.net/api/status" | jq .

# Details
curl -s "https://popin-aladdin.msageha.net/api/position" | jq .
curl -s "https://popin-aladdin.msageha.net/api/media" | jq .
```

## Volume / Mute

```bash
curl -s "https://popin-aladdin.msageha.net/api/volume" | jq .

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

## Remote Keys (D-pad / hardware)

`power` toggles the whole device — confirm with the user first.

```bash
# Navigate: down twice, then OK
curl -s -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "down", "repeat": 2}' | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "ok"}' | jq .

# Back / Home
curl -s -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "back"}' | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "home"}' | jq .
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

## Maintenance

```bash
curl -s -X POST "https://popin-aladdin.msageha.net/api/memory/free" | jq .
curl -s -X POST "https://popin-aladdin.msageha.net/api/capture" | jq .
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
