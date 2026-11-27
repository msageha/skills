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
admits allowlisted LAN client IPs, and rejects requests whose `Origin` header
names another site — a `403` with an nginx HTML page means one of these, not
an API error.

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
- DLNA endpoints (`/status`, `/volume`, `/mute`, playback, `/cast`, `/soap`)
  need the projector running: with only the ceiling light on, or the
  projector off, they fail with `504` "cannot reach". The light's on/off
  state can't be read in any state. A `504` from them doesn't
  by itself prove the projector is off (any network failure gives it).
- `GET /discover` returns `[]` on this instance (the server runs on a Docker
  bridge network, so its LAN broadcast reaches no device); the unit's address
  is fixed in the server config, so it isn't needed.
- `GET /remote/device` reports the foreground app; `GET /status` only knows
  the DLNA playback state.
- `POST /cast` needs a media URL reachable from the device's LAN. It replaces
  the current DLNA media — confirm if something is being watched or you
  can't tell. It sets the URI before sending Play, so after a failure check
  `GET /media` (URI) and `GET /transport` (playing or not) before resending.
  `/stop`, `/next`, `/previous` act on DLNA playback only (`/status`
  `STOPPED` says nothing about an app like YouTube).
- UDP-based commands (`/key`, `/memory/free`, `/power/off`) only report that
  the datagram was sent: they return 200 even when the unit is off. When it
  matters, look for the effect with `/remote/device` (foreground app) or
  `/capture` (screenshot URL) where it is observable there; `/remote/ping`
  only shows the TCP control port is reachable.
- Verified on the real unit: light, D-pad, `back` `menu` `vol_up` `vol_down`
  `power`, text input, voice, ping. The other keys, `/remote/*` info
  endpoints, `/discover`, `/deeplink`, `/memory/free`, `/capture` and
  `/power/off` were reconstructed from the official app and are unverified.
- Writes are immediately visible in the room (light/volume/playback). Safe to
  do when asked; confirm first for `/power/off`, stopping or skipping active playback,
  casting over running content (or when you can't tell), and `/soap` actions outside its read-only
  list (`confirm: true` required).
- Errors: `400` missing or false `confirm` (`/soap` non-read-only actions, `/power/off`), `422`
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
| Free memory / remote ping                                          | `POST /memory/free`, `POST /remote/ping`                                     |
| Raw SOAP action (escape hatch)                                     | `POST /soap`                                                                 |
| Server health / button list                                        | `GET /health`, `GET /remote/buttons`                                         |

Errors, behaviour the OpenAPI document doesn't describe, and how to look up an
endpoint's request/response schema in it: see
[references/api-reference.md](references/api-reference.md). Ready-to-run curl
examples: [references/commands.md](references/commands.md).
