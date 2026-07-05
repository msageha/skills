# popIn Aladdin API Reference

Base URL: `https://popin-aladdin.msageha.net/api`
FastAPI wrapper (popin-aladdin-api v0.1.0) around the popIn Aladdin
(ceiling-light projector, UPnP friendly name `Aladdin 2`). Requests to this
instance don't need any authentication header/cookie. Interactive docs:
`https://popin-aladdin.msageha.net/docs`.

Two control planes on the unit:

1. **UPnP/DLNA MediaRenderer** — playback, volume, cast (`/status`, `/play`,
   `/volume`, `/cast`, `/soap`, …)
2. **Proprietary popIn/MAXHUB protocol** — ceiling light, remote keys, text
   input, voice (`/light`, `/key`, `/keyboard`, `/voice`, `/memory/free`,
   `/capture`; reachability via `POST /remote/ping`)

## Errors

| Status | Meaning |
|---|---|
| 400 / 422 | Request validation error (invalid button/mode/URI, `/soap` Set-action without `confirm: true`) |
| 502 | UPnP/SOAP fault from the unit — body has `detail`, `fault_code`, `upnp_error_code` |
| 504 | Unit unreachable on the LAN (`AladdinConnectionError`) |

Requests are serialized behind a server-side lock; concurrent calls queue up.

---

## System

### GET /health

Server status without touching the unit.

```json
{ "status": "ok", "host": "http://172.16.1.113" }
```

### GET /remote/buttons

Available button names, no device round-trip:
`{ "light": [...], "key": [...], "key_stateless": [...] }`

### POST /remote/ping

TCP reachability check of the proprietary control plane → `{ "ok": true }`.

---

## Status

### GET /info

UPnP device description. All fields nullable.

| Field | Type | Description |
|-------|------|-------------|
| friendly_name | string | e.g. `Aladdin 2` |
| manufacturer / model_name / model_description | string | Renderer identity |
| udn | string | Unique Device Name (UUID, per-unit) |
| services | string[] | e.g. `["AVTransport", "ConnectionManager", "RenderingControl"]` |
| description_url | string | Device description URL on the LAN |

### GET /status

Aggregated playback state.

```json
{
  "state": "PLAYING",
  "status": "OK",
  "volume": 35,
  "mute": false,
  "current_uri": "http://192.168.1.50:8200/video/sample.mp4",
  "track_duration_seconds": 212.0,
  "position_seconds": 30.0
}
```

`state`: `STOPPED` / `PLAYING` / `PAUSED_PLAYBACK` / … (UPnP transport states).

### GET /transport / GET /position / GET /media / GET /protocol-info

Detail views behind `/status`:

| Endpoint | Fields |
|---|---|
| `/transport` | `state`, `status`, `speed` |
| `/position` | `track`, `track_duration(_seconds)`, `track_uri`, `track_metadata`, `rel_time(_seconds)`, `abs_time` |
| `/media` | `nr_tracks`, `media_duration`, `current_uri(_metadata)`, `play_medium` |
| `/protocol-info` | `{ "source": [...], "sink": [...] }` (supported formats) |

---

## Playback control

### GET /volume / POST /volume

`GET` → `{ "volume": 35 }`. `POST` body: `{ "volume": <0..100> }`.

### GET /mute / POST /mute

`GET` → `{ "mute": false }`. `POST` body: `{ "mute": true|false }`.

### POST /play / /pause / /stop / /next / /previous

No body required (`/play` optionally takes `{ "speed": "1" }`).
Response: `{ "action": "<name>" }`.

### POST /seek

Body: `{ "seconds": <float ≥ 0> }` — absolute position (REL_TIME).

### POST /play-mode

Body: `{ "mode": ... }` — one of `NORMAL` / `REPEAT_ONE` / `REPEAT_ALL` /
`SHUFFLE` / `SHUFFLE_NOREPEAT`.

### POST /cast

Load (and by default play) a media URL on the projector. The URL must be
reachable from the device's LAN. Replaces the current content.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| uri | string | yes | Absolute media URL (`://` required) |
| title | string | no | Title for the generated DIDL-Lite metadata (default `popin-aladdin-api`) |
| upnp_class | string | no | `object.item.videoItem` (default) / `object.item.audioItem` / `object.item.imageItem` |
| metadata | string | no | Explicit DIDL-Lite XML; auto-generated when omitted |
| autoplay | boolean | no | Send Play right after loading (default `true`) |

Response: `{ "uri": ..., "autoplay": true }`

---

## Remote control (proprietary protocol)

### POST /light

Ceiling light operation.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| button | enum | yes | `switch` `brighter` `darker` `cooler` `warmer` `full` `night` `on` `off` `eco` `sleep` |
| repeat | integer | no | Press N times, 1..50 (default 1) — for stepwise `brighter`/`darker`/`cooler`/`warmer` |

Button semantics: `on`/`off` explicit states, `switch` toggles, `full` max
brightness, `night`/`eco`/`sleep` preset scenes, `brighter`/`darker` one
brightness step each, `cooler`/`warmer` one color-temperature step each.

### POST /key

Projector key input. Same body shape as `/light` (`button` + `repeat`).

- D-pad: `up` `down` `left` `right` `ok` `home`
- Hardware: `back` `menu` `vol_up` `vol_down` `power` — **`power` toggles the
  whole device; confirm with the user first**

### POST /keyboard

Body: `{ "text": "..." }` — types into the currently focused on-screen input.
The device must already be showing a text field (navigate with `/key` first).

### POST /voice

Body: `{ "text": "..." }` — sends the text as if spoken to the voice assistant.

### POST /memory/free / POST /capture

No body. `memory/free` kills background apps to free RAM; `capture` sends the
device's capture maintenance command. Response: `{ "action": "<name>" }`.

---

## POST /soap

Raw UPnP SOAP passthrough. Get-actions are treated as read-only; any other
action (Play/Set*/…) **requires `confirm: true`** and can change device state
— prefer the typed endpoints above.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| service | string | yes | `AVTransport` / `RenderingControl` / `ConnectionManager` |
| action | string | yes | SOAP action name |
| args | object | no | Action arguments (most need `"InstanceID": 0`) |
| confirm | boolean | no* | Required `true` unless the action is in the read-only list |

Read-only (no `confirm` needed): `GetTransportInfo`, `GetPositionInfo`,
`GetMediaInfo`, `GetTransportSettings`, `GetCurrentTransportActions`,
`GetDeviceCapabilities`, `GetVolume`, `GetVolumeDB`, `GetVolumeDBRange`,
`GetMute`, `ListPresets`, `GetProtocolInfo`, `GetCurrentConnectionIDs`,
`GetCurrentConnectionInfo`.

Unknown body fields are rejected (`extra=forbid`).

Response: `{ "service": ..., "action": ..., "result": <SOAP response fields> }`
