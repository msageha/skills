---
name: popin-aladdin
description: "popIn Aladdin (ceiling-light projector) control. Use when: user asks about the projector / ceiling light — turning the light on/off or adjusting brightness/color, media playback state or volume, casting a video/image URL to the projector, or navigating its UI with remote keys / text input. Controls the unit via the popin-aladdin-api REST wrapper."
metadata:
  openclaw:
    emoji: "📽️"
    requires:
      bins:
        - curl
---

# popIn Aladdin

Base URL: `https://popin-aladdin.msageha.net/api` (FastAPI wrapper around the
popIn Aladdin's local UPnP/DLNA MediaRenderer + its proprietary popIn/MAXHUB
control protocol). No authentication header/cookie needed — the unit itself
is unauthenticated on the LAN and the server talks to it directly.

## Key facts

- Two control planes: DLNA (playback/volume/cast) and the proprietary remote
  protocol (`/light`, `/key`, `/keyboard`, `/voice`). `POST /remote/ping`
  checks the latter's reachability.
- Requests are serialized behind a server-side lock; call endpoints
  sequentially, don't fan out parallel requests.
- Light buttons: `switch` `brighter` `darker` `cooler` `warmer` `full`
  `night` `on` `off` `eco` `sleep`. Step buttons (`brighter`/`darker`/
  `cooler`/`warmer`) accept `repeat` (1..50) to move several steps.
- Remote keys: D-pad `up` `down` `left` `right` `ok` `home` / hardware
  `back` `menu` `vol_up` `vol_down` `power`. `power` affects the whole
  device — confirm with the user before sending it.
- `POST /cast` needs a media URL reachable from the device's LAN. It replaces
  whatever is currently showing — confirm if something is playing.
- Writes are immediately visible in the room (light/volume/playback). Safe to
  do when asked; for `power`, stopping active playback, or `/soap` Set-actions
  (`confirm: true` required), confirm with the user first.
- Errors: `502` UPnP/SOAP fault (`detail` + `fault_code` + `upnp_error_code`),
  `504` unit unreachable, `400`/`422` validation or missing `confirm`.

## Core operations

| Task | Endpoint |
|---|---|
| Ceiling light on/off/brightness/color | `POST /light` |
| Aggregated state (transport/volume/mute/URI/position) | `GET /status` |
| Volume / mute | `GET`/`POST /volume`, `GET`/`POST /mute` |
| Play / pause / stop / next / previous | `POST /play`, `/pause`, `/stop`, `/next`, `/previous` |
| Seek (seconds) / play mode | `POST /seek`, `POST /play-mode` |
| Cast a media URL to the projector | `POST /cast` |
| Remote key input (D-pad / hardware keys) | `POST /key` |
| Type text into focused input | `POST /keyboard` |
| Voice command as text | `POST /voice` |
| Device info / playback details | `GET /info`, `/transport`, `/position`, `/media`, `/protocol-info` |
| Free memory / capture / remote ping | `POST /memory/free`, `/capture`, `/remote/ping` |
| Raw SOAP action (escape hatch) | `POST /soap` |
| Server health / button list | `GET /health`, `GET /remote/buttons` |

Full request/response schemas and ready-to-run curl examples: see
[references/api-reference.md](references/api-reference.md) and
[references/commands.md](references/commands.md).
