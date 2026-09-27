---
name: popin-aladdin
description: "popIn Aladdin (ceiling-light projector) control. Use when: user asks about the projector / ceiling light — turning the light on/off or adjusting brightness/color, media playback state or volume, casting a video/image URL to the projector, launching an app (YouTube / Netflix / TVer …) or opening a deeplink, navigating its UI with remote keys / text input, taking a screenshot or checking what's on screen, or powering the projector off. Controls the unit via the popin-aladdin-api REST wrapper."
metadata:
  openclaw:
    emoji: "📽️"
    requires:
      bins:
        - curl
        - jq
---

# popIn Aladdin

Base URL: `https://popin-aladdin.msageha.net/api` (FastAPI wrapper around the
popIn Aladdin's local UPnP/DLNA MediaRenderer plus the proprietary control
protocols the official app uses — popIn's own TCP protocol and the XGIMI GMSDK
UDP protocol). Requests to this instance don't need any authentication
header/cookie; the server talks to the unit directly. The reverse proxy only
admits allowlisted LAN client IPs — a `403` with an nginx HTML page means the
caller isn't on that list, not an API error.

## Key facts

- Two control planes: DLNA (playback / volume / cast / `/soap`) and the
  proprietary remote protocols (`/light`, `/key`, `/keyboard`, `/voice`,
  `/deeplink`, `/remote/*`, `/discover`, `/memory/free`, `/capture`,
  `/power/off`). `POST /remote/ping` checks the latter's TCP reachability.
- Requests are serialized behind a server-side lock; call endpoints
  sequentially, don't fan out parallel requests.
- Light buttons: `switch` `brighter` `darker` `cooler` `warmer` `full`
  `night` `on` `off` `eco` `sleep`. `repeat` (1..50) presses any button N
  times — use it for the step buttons (`brighter`/`darker`/`cooler`/`warmer`).
- Remote keys (`POST /key`): D-pad `up` `down` `left` `right` `ok` `home`,
  focus `focus_plus` `focus_minus`, long-press `home_long` `menu_long`,
  hardware `back` `menu` `vol_up` `vol_down` `power` `settings`, app
  shortcuts `netflix` `youtube` `prime_video` `custom` `custom_long`. `power`
  only opens the on-screen power menu — it does not switch the unit off.
- `POST /power/off` (`{"confirm": true}` required) really powers the
  projector down, and this API cannot turn it back on — always confirm with
  the user first.
- `GET /remote/device` reports the foreground app; `GET /status` only knows
  the DLNA playback state.
- `POST /cast` needs a media URL reachable from the device's LAN. It replaces
  whatever is currently showing — confirm if something is playing.
- UDP-based commands (`/key`, `/memory/free`, `/power/off`) only report that
  the datagram was sent: they return 200 even when the unit is off. When it
  matters, verify with `/remote/ping`, `/remote/device` or `/capture`.
- Verified on the real unit: light, D-pad, `back` `menu` `vol_up` `vol_down`
  `power`, text input, voice, ping. The other keys, `/remote/*` info
  endpoints, `/discover`, `/deeplink`, `/memory/free`, `/capture` and
  `/power/off` were reconstructed from the official app and are unverified.
- Writes are immediately visible in the room (light/volume/playback). Safe to
  do when asked; confirm first for `/power/off`, stopping active playback,
  casting over running content, and `/soap` Set-actions (`confirm: true`
  required).
- Errors: `400` missing `confirm` (`/soap` Set-actions, `/power/off`), `422`
  body validation (unknown button, volume out of range, …), `502` device
  returned a SOAP fault or an unexpected answer (`detail`; SOAP faults add
  `fault_code` + `upnp_error_code`), `504` unit unreachable or no UDP reply in
  time.

## Core operations

| Task                                                               | Endpoint                                                                     |
| ------------------------------------------------------------------ | ---------------------------------------------------------------------------- |
| Ceiling light on/off/brightness/color                              | `POST /light`                                                                |
| Aggregated playback state (transport/volume/mute/URI/position)     | `GET /status`                                                                |
| What's on screen (foreground app)                                  | `GET /remote/device`                                                         |
| Volume / mute                                                      | `GET`/`POST /volume`, `GET`/`POST /mute`                                     |
| Play / pause / stop / next / previous                              | `POST /play`, `/pause`, `/stop`, `/next`, `/previous`                        |
| Seek (seconds) / play mode                                         | `POST /seek`, `POST /play-mode`                                              |
| Cast a media URL to the projector                                  | `POST /cast`                                                                 |
| Launch an app / open a URL on the device                           | `POST /deeplink` (or `POST /key` with `youtube` / `netflix` / `prime_video`) |
| Remote key input (D-pad / focus / hardware keys)                   | `POST /key`                                                                  |
| Type text into focused input                                       | `POST /keyboard`                                                             |
| Voice command as text                                              | `POST /voice`                                                                |
| Screenshot (returns an image URL on the device's LAN)              | `POST /capture`                                                              |
| Power off (destructive, `confirm: true`)                           | `POST /power/off`                                                            |
| Device info / playback details                                     | `GET /info`, `/transport`, `/position`, `/media`, `/protocol-info`           |
| Model / OS / storage / features, photo memory, is an app installed | `GET /remote/version`, `/remote/album`, `/remote/apps/{package}`             |
| Find Aladdins on the LAN                                           | `GET /discover?wait=3`                                                       |
| Free memory / remote ping                                          | `POST /memory/free`, `POST /remote/ping`                                     |
| Raw SOAP action (escape hatch)                                     | `POST /soap`                                                                 |
| Server health / button list                                        | `GET /health`, `GET /remote/buttons`                                         |

Full request/response schemas and ready-to-run curl examples: see
[references/api-reference.md](references/api-reference.md) and
[references/commands.md](references/commands.md).
