# popIn Aladdin API Reference

Base URL: `https://popin-aladdin.msageha.net/api`
FastAPI wrapper (popin-aladdin-api v0.1.0) around the popIn Aladdin
(ceiling-light projector, UPnP friendly name `Aladdin 2`). Requests to this
instance don't need any authentication header/cookie; the reverse proxy admits
only allowlisted LAN client IPs (`403` otherwise). Interactive docs:
`https://popin-aladdin.msageha.net/docs`.

Two control planes on the unit:

1. **UPnP/DLNA MediaRenderer** — playback, volume, cast (`/status`, `/play`,
   `/volume`, `/cast`, `/soap`, …)
2. **Proprietary protocols reconstructed from the official Aladdin X app** —
   popIn's TCP protocol (light, text, voice, deeplink, version / album / app
   info) and the XGIMI GMSDK UDP protocol (keys, screenshot, memory, power
   off, device info, LAN discovery): `/light`, `/key`, `/keyboard`, `/voice`,
   `/deeplink`, `/remote/*`, `/discover`, `/memory/free`, `/capture`,
   `/power/off`; TCP reachability via `POST /remote/ping`.

Verified on the real unit (popIn Aladdin 2): light buttons, D-pad, `back`
`menu` `vol_up` `vol_down` `power`, `/keyboard`, `/voice`, `/remote/ping`.
Everything else on the proprietary side (`focus_*`, `*_long`, `settings`, app
shortcut keys, `/remote/version` `/remote/album` `/remote/apps` `/remote/device`,
`/discover`, `/deeplink`, `/memory/free`, `/capture`, `/power/off`) comes from
static analysis of the app and is not yet confirmed to work.

## Errors

| Status | Meaning                                                                                                                                            |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| 400    | `confirm: true` missing on a `/soap` action that can change state, or on `/power/off`                                                              |
| 403    | Reverse proxy rejected the caller's IP (nginx HTML page, not JSON)                                                                                 |
| 422    | Request body validation (unknown button / mode / package name, volume out of range, URI without scheme, …)                                         |
| 502    | Device returned a SOAP fault or an unexpected answer — body has `detail`; for SOAP faults also `fault_code` (SOAP faultcode) and `upnp_error_code` |
| 504    | Unit unreachable on the LAN (connection refused / timeout), or a UDP JSON command got no reply within the server's timeout                         |

UDP-based commands (`/key`, `/memory/free`, `/power/off`) don't wait for an
answer: a 200 means the datagram was sent, not that the unit acted on it.

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

```json
{
  "light": [
    "switch",
    "brighter",
    "darker",
    "cooler",
    "warmer",
    "full",
    "night",
    "on",
    "off",
    "eco",
    "sleep"
  ],
  "key": [
    "home",
    "up",
    "right",
    "down",
    "ok",
    "left",
    "focus_plus",
    "focus_minus",
    "home_long"
  ],
  "key_stateless": [
    "back",
    "vol_up",
    "vol_down",
    "power",
    "menu",
    "menu_long",
    "settings",
    "netflix",
    "youtube",
    "prime_video",
    "custom",
    "custom_long"
  ]
}
```

`key` entries are sent as press + release, `key_stateless` as single key
presses; both go to `POST /key`.

### POST /remote/ping

TCP reachability check of the proprietary control plane → `{ "ok": true }`.

### GET /discover

Broadcast on the LAN and list the Aladdins that answer; independent of the
configured host. Query `wait` = seconds to wait for answers (0.5..15, default
`3`). Response: array of

| Field      | Type    | Description                           |
| ---------- | ------- | ------------------------------------- |
| ip_address | string  | Device IP                             |
| model      | string  | e.g. `Aladdin 2`                      |
| name       | string  | Device name                           |
| pid        | string  | Unit ID                               |
| mac        | string  | MAC address                           |
| version    | integer | Protocol version                      |
| zipcode    | string  | Postal code configured on the device  |
| connected  | boolean | Another client is currently connected |

---

## Status

### GET /info

UPnP device description. All fields nullable.

| Field                                         | Type     | Description                                                     |
| --------------------------------------------- | -------- | --------------------------------------------------------------- |
| friendly_name                                 | string   | e.g. `Aladdin 2`                                                |
| manufacturer / model_name / model_description | string   | Renderer identity                                               |
| udn                                           | string   | Unique Device Name (UUID, per-unit)                             |
| services                                      | string[] | e.g. `["AVTransport", "ConnectionManager", "RenderingControl"]` |
| description_url                               | string   | Device description URL on the LAN                               |

### GET /status

Aggregated DLNA playback state.

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
Apps running on the projector (YouTube etc.) are not visible here — use
`GET /remote/device`.

### GET /transport / GET /position / GET /media / GET /protocol-info

Detail views behind `/status`:

| Endpoint         | Fields                                                                                               |
| ---------------- | ---------------------------------------------------------------------------------------------------- |
| `/transport`     | `state`, `status`, `speed`                                                                           |
| `/position`      | `track`, `track_duration(_seconds)`, `track_uri`, `track_metadata`, `rel_time(_seconds)`, `abs_time` |
| `/media`         | `nr_tracks`, `media_duration`, `current_uri(_metadata)`, `play_medium`                               |
| `/protocol-info` | `{ "source": [...], "sink": [...] }` (supported formats)                                             |

### GET /remote/device

Runtime info from the UDP control channel — the only way to know what is in
the foreground. All fields nullable.

| Field              | Type    | Description                                     |
| ------------------ | ------- | ----------------------------------------------- |
| device_name        | string  | Device name                                     |
| device_mode        | string  | Device mode                                     |
| foreground_app     | string  | Foreground app name                             |
| foreground_package | string  | Foreground app package                          |
| runtime            | integer | Uptime as reported by the device (unit unknown) |
| rom                | integer | ROM size as reported                            |
| mst / tips         | string  | Device-reported values, purpose unknown         |

### GET /remote/version

Self-description returned by the TCP Version handshake. All fields nullable.

| Field                    | Type             | Description                                                                    |
| ------------------------ | ---------------- | ------------------------------------------------------------------------------ |
| code                     | integer          | Protocol version, e.g. `10`                                                    |
| model                    | string           | e.g. `Aladdin 2`                                                               |
| device_name / pid        | string           | Device name / unit ID                                                          |
| aladdin_id               | string           | Aladdin account link ID                                                        |
| platform                 | string           | `Android` / `webos`                                                            |
| os_version / sdk_int     | string / integer | OS version / Android API level                                                 |
| lang / country           | string           | Locale                                                                         |
| total_space / free_space | integer          | Storage in bytes                                                               |
| server_access            | boolean          | Cloud connectivity                                                             |
| feature_access           | object           | Feature → `1` = available (keys like `focus`, `input`, `memory_release`)       |
| capability               | object           | Capability → `1` = supported, `null` = unknown (keys `screenshot`, `app_list`) |

### GET /remote/album

Photo memory (on-device album): `count`, `total_space`, `free_space`,
`light_version` (firmware of the light unit), `files[]` with `name`, `size`,
`type` (`1` photo, `2` thumbnail, `10`..`12` clock).

### GET /remote/apps/{package}

Whether an Android package is installed and its version. `package` must be a
dotted identifier (e.g. `jp.co.tver.tvapp`, `com.google.android.youtube.tv`).
Response: `{ "package", "installed", "version_code", "version_name" }`.

---

## Playback control

### GET /volume / POST /volume

`GET` → `{ "volume": 35 }`. `POST` body: `{ "volume": <0..100> }`.

### GET /mute / POST /mute

`GET` → `{ "mute": false }`. `POST` body: `{ "mute": true|false }`.

### POST /play / /pause / /stop / /next / /previous

No body required (`/play` optionally takes `{ "speed": "1" }`).
Response: `{ "action": "<name>" }` (`/play` adds `"speed"`).

### POST /seek

Body: `{ "seconds": <float ≥ 0> }` — absolute position (REL_TIME).

### POST /play-mode

Body: `{ "mode": ... }` — one of `NORMAL` / `REPEAT_ONE` / `REPEAT_ALL` /
`SHUFFLE` / `SHUFFLE_NOREPEAT`.

### POST /cast

Load (and by default play) a media URL on the projector. The URL must be
reachable from the device's LAN. Replaces the current content.

| Field      | Type    | Required | Description                                                                           |
| ---------- | ------- | -------- | ------------------------------------------------------------------------------------- |
| uri        | string  | yes      | Absolute media URL (`://` required)                                                   |
| title      | string  | no       | Title for the generated DIDL-Lite metadata (default `popin-aladdin-api`)              |
| upnp_class | string  | no       | `object.item.videoItem` (default) / `object.item.audioItem` / `object.item.imageItem` |
| metadata   | string  | no       | Explicit DIDL-Lite XML; auto-generated when omitted                                   |
| autoplay   | boolean | no       | Send Play right after loading (default `true`)                                        |

Response: `{ "uri": ..., "autoplay": true }`

---

## Remote control (proprietary protocols)

### POST /light

Ceiling light operation (TCP).

| Field  | Type    | Required | Description                                                                            |
| ------ | ------- | -------- | -------------------------------------------------------------------------------------- |
| button | enum    | yes      | `switch` `brighter` `darker` `cooler` `warmer` `full` `night` `on` `off` `eco` `sleep` |
| repeat | integer | no       | Press N times, 1..50 (default 1) — meant for `brighter`/`darker`/`cooler`/`warmer`     |

`on`/`off` set explicit states and `switch` toggles; `brighter`/`darker` and
`cooler`/`warmer` move one step each. `full`/`night`/`eco`/`sleep` send the
app's preset buttons of the same name (exact scene behaviour not documented).
Response echoes the body.

### POST /key

Projector key input (UDP). Same body shape as `/light` (`button` + `repeat`).

| Group         | Buttons                                                                                                          |
| ------------- | ---------------------------------------------------------------------------------------------------------------- |
| D-pad         | `up` `down` `left` `right` `ok` `home`                                                                           |
| Focus         | `focus_plus` `focus_minus`                                                                                       |
| Long press    | `home_long` `menu_long`                                                                                          |
| Hardware      | `back` `menu` `vol_up` `vol_down` `power` (opens the power menu; use `POST /power/off` to switch off) `settings` |
| App shortcuts | `netflix` `youtube` `prime_video` `custom` `custom_long`                                                         |

Returns 200 once the datagrams are sent, even if the unit is off. Response
echoes the body.

### POST /keyboard

Body: `{ "text": "..." }` — types into the currently focused on-screen input.
The device must already be showing a text field (navigate with `/key` first).

### POST /voice

Body: `{ "text": "..." }` — sends the text as if spoken to the voice assistant.

### POST /deeplink

Body: `{ "url": "..." }` — opens the URL scheme / intent on the device, i.e.
launches an app (`https://www.youtube.com/tv`, `tver://`, …). Response echoes
the body.

### POST /memory/free

No body. Frees memory by killing background apps (UDP, no reply awaited).
Response: `{ "action": "free_memory" }`.

### POST /capture

No body. Takes a screenshot and returns the image URL served by the device;
fetch it from the device's LAN.
Response: `{ "action": "capture", "image_url": "http://172.16.1.113:.../....png" }`.

### POST /power/off

Powers the projector down. **Irreversible from this API — it cannot turn the
unit back on. Confirm with the user first.**

| Field   | Type    | Required | Description                   |
| ------- | ------- | -------- | ----------------------------- |
| confirm | boolean | yes      | Must be `true`, otherwise 400 |

Response: `{ "action": "power_off" }` (sent over UDP; 200 doesn't prove the
unit received it).

---

## POST /soap

Raw UPnP SOAP passthrough. Get-actions are treated as read-only; any other
action (Play/Set*/…) **requires `confirm: true`** and can change device state
— prefer the typed endpoints above.

| Field   | Type    | Required | Description                                                |
| ------- | ------- | -------- | ---------------------------------------------------------- |
| service | string  | yes      | `AVTransport` / `RenderingControl` / `ConnectionManager`   |
| action  | string  | yes      | SOAP action name                                           |
| args    | object  | no       | Action arguments (most need `"InstanceID": 0`)             |
| confirm | boolean | no*      | Required `true` unless the action is in the read-only list |

Read-only (no `confirm` needed): `GetTransportInfo`, `GetPositionInfo`,
`GetMediaInfo`, `GetTransportSettings`, `GetCurrentTransportActions`,
`GetDeviceCapabilities`, `GetVolume`, `GetVolumeDB`, `GetVolumeDBRange`,
`GetMute`, `ListPresets`, `GetProtocolInfo`, `GetCurrentConnectionIDs`,
`GetCurrentConnectionInfo`.

Unknown body fields are rejected (`extra=forbid`).

Response: `{ "service": ..., "action": ..., "result": <SOAP response fields> }`
