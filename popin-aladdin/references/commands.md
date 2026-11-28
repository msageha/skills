# popIn Aladdin Command Recipes

Ready-to-run `curl` examples for common tasks. For other endpoints and for
request/response schemas, see [api-reference.md](api-reference.md): how to look
them up in the server's OpenAPI document, and what the document leaves out. Base URL: `https://popin-aladdin.msageha.net/api`.
Run requests sequentially — the server serializes them behind one device session.

The examples call curl with `-sSf` under `set -o pipefail`: a request that
fails (no connection, or an HTTP status of 400 or above) makes the command exit
non-zero with the error on stderr and no body, as the success check in SKILL.md
expects. Free text taken from responses, web pages or other external sources
(names, descriptions, URLs) goes into the body through a file, not pasted into
the command: `jq -n --rawfile v "<text-file>" '($v | sub("\r?\n$"; "")) as $v | <filter>' > "<body-file>"`
builds the body (dropping the file's trailing LF or CRLF), and
`--data-binary @"<body-file>"` sends it. Build a body whose value holds a quote
or backslash with jq (`--arg <name> '<value>'`) too, since it breaks a JSON
literal in `-d '…'`.

## Health / Device Info

```bash
set -o pipefail
curl -sSf "https://popin-aladdin.msageha.net/api/health" | jq .
curl -sSf "https://popin-aladdin.msageha.net/api/info" | jq .

# Proprietary control plane reachable?
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/remote/ping" | jq .

# Light / remote button names accepted by /light and /key
curl -sSf "https://popin-aladdin.msageha.net/api/remote/buttons" | jq .

# Model / OS / storage / feature flags (TCP Version handshake)
curl -sSf "https://popin-aladdin.msageha.net/api/remote/version" | jq .
```

## What's on Screen

```bash
set -o pipefail
# Foreground app (apps like YouTube are invisible to the DLNA /status)
curl -sSf "https://popin-aladdin.msageha.net/api/remote/device" | jq '{foreground_app, foreground_package}'

# Screenshot — the returned image_url is served by the device on its LAN
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/capture" | jq .
```

## Ceiling Light

```bash
set -o pipefail
# Turn the light on / off
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "on"}' | jq .
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "off"}' | jq .

# Brightness: 5 steps up / 3 steps down
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "brighter", "repeat": 5}' | jq .
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "darker", "repeat": 3}' | jq .

# Color temperature / presets
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "warmer", "repeat": 2}' | jq .
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/light" \
  -H "Content-Type: application/json" -d '{"button": "night"}' | jq .
```

## Playback Status

```bash
set -o pipefail
curl -sSf "https://popin-aladdin.msageha.net/api/status" | jq 'del(.. | objects | .current_uri?, .current_uri_metadata?, .track_uri?, .track_metadata?)'   # URIs can carry tokens

# Position and media details
curl -sSf "https://popin-aladdin.msageha.net/api/position" | jq 'del(.. | objects | .current_uri?, .current_uri_metadata?, .track_uri?, .track_metadata?)'
curl -sSf "https://popin-aladdin.msageha.net/api/media" | jq 'del(.. | objects | .current_uri?, .current_uri_metadata?, .track_uri?, .track_metadata?)'

# Transport state / supported protocols
curl -sSf "https://popin-aladdin.msageha.net/api/transport" | jq .
curl -sSf "https://popin-aladdin.msageha.net/api/protocol-info" | jq .
```

## Volume / Mute

```bash
set -o pipefail
curl -sSf "https://popin-aladdin.msageha.net/api/volume" | jq .
curl -sSf "https://popin-aladdin.msageha.net/api/mute" | jq .

curl -sSf -X POST "https://popin-aladdin.msageha.net/api/volume" \
  -H "Content-Type: application/json" -d '{"volume": 40}' | jq .

curl -sSf -X POST "https://popin-aladdin.msageha.net/api/mute" \
  -H "Content-Type: application/json" -d '{"mute": true}' | jq .
```

## Playback Control

Stopping active playback (or skipping away from it) is visible in the room —
unless the user asked for it, confirm first if something is playing.

```bash
set -o pipefail
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/play" | jq .
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/pause" | jq .
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/stop" | jq .
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/next" | jq .
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/previous" | jq .

# Seek to 1:30
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/seek" \
  -H "Content-Type: application/json" -d '{"seconds": 90}' | jq .

# Repeat all
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/play-mode" \
  -H "Content-Type: application/json" -d '{"mode": "REPEAT_ALL"}' | jq .
```

## Cast a Media URL (replaces current content)

The URL must be reachable from the device's LAN. Casting replaces the DLNA
media (even with `"autoplay": false`) — confirm first if something is being
watched, or if you can't tell (`/status` only sees DLNA playback; the
foreground app doesn't say whether it is playing). The URI is set before Play,
so after a failure check `/media` (URI) and `/transport` (state) before
resending.

```bash
set -o pipefail
# Public URLs only: a signed URI would stay in the command line; send it as SKILL.md describes
# Video (autoplay)
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/cast" \
  -H "Content-Type: application/json" \
  -d '{"uri": "<video-url>",
       "upnp_class": "object.item.videoItem"}' | jq '{autoplay}'   # the response echoes the URI

# Image
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/cast" \
  -H "Content-Type: application/json" \
  -d '{"uri": "<image-url>",
       "upnp_class": "object.item.imageItem"}' | jq '{autoplay}'
```

## Launch Apps (deeplink / shortcut keys)

```bash
set -o pipefail
# Open a URL / app scheme on the device
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/deeplink" \
  -H "Content-Type: application/json" -d '{"url": "https://www.youtube.com/tv"}' -o /dev/null -w '%{http_code}\n'   # the response echoes the URL
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/deeplink" \
  -H "Content-Type: application/json" -d '{"url": "tver://"}' -o /dev/null -w '%{http_code}\n'

# Remote shortcut keys
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "youtube"}' | jq .

# Is an app installed?
curl -sSf "https://popin-aladdin.msageha.net/api/remote/apps/jp.co.tver.tvapp" | jq .
```

## Remote Keys (D-pad / focus / hardware)

`power` only opens the on-screen power menu; to switch the unit off use
`POST /power/off` below. A 200 means the UDP datagram was sent, not that the
unit is on.

```bash
set -o pipefail
# Navigate: down twice, then OK
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "down", "repeat": 2}' | jq . \
  && curl -sSf -X POST "https://popin-aladdin.msageha.net/api/key" \
    -H "Content-Type: application/json" -d '{"button": "ok"}' | jq .

# Back / Home / Settings
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "back"}' | jq .
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "home"}' | jq .
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "settings"}' | jq .

# Focus adjustment (one step each)
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/key" \
  -H "Content-Type: application/json" -d '{"button": "focus_plus"}' | jq .
```

## Text / Voice Input

```bash
# Type into the focused on-screen input (focus it with /key first). The response echoes
# the text; for a secret the user handed over, see SKILL.md
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/keyboard" \
  -H "Content-Type: application/json" -d '{"text": "<text>"}' -o /dev/null -w '%{http_code}\n'

# Voice command as text
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/voice" \
  -H "Content-Type: application/json" -d '{"text": "<voice-command>"}' -o /dev/null -w '%{http_code}\n'
```

## Maintenance / Power

```bash
set -o pipefail
# Free memory (kills background apps)
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/memory/free" | jq .

# Photo memory (on-device album) and light-unit firmware
curl -sSf "https://popin-aladdin.msageha.net/api/remote/album" | jq '{count, free_space, light_version}'

# Power off — this API can't turn it back on; confirm with the user first
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/power/off" \
  -H "Content-Type: application/json" -d '{"confirm": true}' | jq .
```

## Raw SOAP Passthrough (advanced)

Only the read-only actions listed in api-reference.md (`GetTransportInfo`,
`GetVolume`, `ListPresets`, …) skip `confirm`; anything else needs
`confirm: true` — confirm with the user and prefer the typed endpoints.

```bash
set -o pipefail
# Read transport info
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/soap" \
  -H "Content-Type: application/json" \
  -d '{"service": "AVTransport", "action": "GetTransportInfo",
       "args": {"InstanceID": 0}}' | jq .

# Set volume via raw SOAP (confirm required)
curl -sSf -X POST "https://popin-aladdin.msageha.net/api/soap" \
  -H "Content-Type: application/json" \
  -d '{"service": "RenderingControl", "action": "SetVolume",
       "args": {"InstanceID": 0, "Channel": "Master", "DesiredVolume": 20},
       "confirm": true}' | jq .
```
