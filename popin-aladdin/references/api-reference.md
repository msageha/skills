# popIn Aladdin API Reference

Base URL: `https://popin-aladdin.msageha.net/api`
FastAPI wrapper (popin-aladdin-api) around the popIn Aladdin (ceiling-light
projector, UPnP friendly name `Aladdin 2`). Requests to this instance don't
need any authentication header/cookie; the reverse proxy admits only
allowlisted LAN client IPs and rejects requests whose `Origin` header names
another site (`403` otherwise). Interactive docs:
`https://popin-aladdin.msageha.net/docs`.

This file holds what the OpenAPI document doesn't say: errors, what each
control plane can and can't observe, what was verified on the unit, and the
behaviour behind the buttons, casting and SOAP. Read field-level schemas from
the OpenAPI document.

## Request / response schemas

`https://popin-aladdin.msageha.net/openapi.json` (generated from the server
code, same access rules as the API) has every endpoint's fields, types,
required flags, enums and response models, with descriptions in Japanese. Look
up one operation instead of reading the whole document:

```bash
set -o pipefail  # a failed download must fail the command
# List operations
curl -sf "https://popin-aladdin.msageha.net/openapi.json" | jq -er '.paths | to_entries[]
  | .key as $p | .value | to_entries[] | "\(.key | ascii_upcase) \($p)  \(.value.summary // "")"'

# One operation with its schemas inlined — set --arg path / --arg method
curl -sf "https://popin-aladdin.msageha.net/openapi.json" | jq -e --arg path /api/cast --arg method post '
  . as $root
  | def deref($seen):
      if type == "object" then
        if has("$ref") then (."$ref" | split("/") | last) as $n
          | (if ($seen | index($n)) then {"$ref": $n} else ($root.components.schemas[$n] | deref($seen + [$n])) end)
            + (del(."$ref") | deref($seen))
        else map_values(deref($seen)) end
      elif type == "array" then map(deref($seen)) else . end;
    .paths[$path][$method]
    | {summary, description, parameters, request: .requestBody,
       responses: (.responses | with_entries(.value |= if .content and (.description != "Validation Error") then .content else .description end))}
    | deref([])'
```

`GET /remote/buttons` lists the button names without touching the device:
`light` (for `/light`), and `key` / `key_stateless` (both for `/key`; `key`
entries are sent as press + release, `key_stateless` as a single press).

## Errors

The OpenAPI document lists only `200` / `422`; the server also returns:

| Status | Meaning                                                                                                                                            |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| 400    | `confirm: true` missing on a `/soap` action that can change state, or on `/power/off`                                                              |
| 403    | Reverse proxy rejected the caller's IP or a cross-site `Origin` (nginx HTML page, not JSON)                                                        |
| 422    | Request body validation (unknown button / mode / package name, volume out of range, URI without scheme, …)                                         |
| 502    | Device returned a SOAP fault or an unexpected answer — body has `detail`; for SOAP faults also `fault_code` (SOAP faultcode) and `upnp_error_code` |
| 504    | Unit unreachable on the LAN (connection refused / timeout — DLNA endpoints while the projector isn't running), or no UDP reply in time             |

UDP-based commands (`/key`, `/memory/free`, `/power/off`) don't wait for an
answer: a 200 means the datagram was sent, not that the unit acted on it.

Requests are serialized behind a server-side lock; concurrent calls queue up.

## Control planes

1. UPnP/DLNA MediaRenderer — playback, volume, cast (`/status`, `/transport`,
   `/position`, `/media`, `/protocol-info`, `/volume`, `/mute`, `/play` …,
   `/cast`, `/soap`). It answers only while the projector is running; `/info`
   (the device description) is cached by the server after the first fetch.
   `/status` sees DLNA playback only: apps running on the projector (YouTube
   etc.) are invisible there — use `GET /remote/device` for the foreground app.
2. Proprietary protocols reconstructed from the official Aladdin X app —
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

`GET /discover` always returns `[]` on this instance: the server runs on a
Docker bridge network, so its LAN broadcast reaches no device.

## Buttons and keys

- `/light`: `on` / `off` set explicit states and `switch` toggles; `brighter` /
  `darker` and `cooler` / `warmer` move one step each (use `repeat` for
  several). `full` / `night` / `eco` / `sleep` send the app's preset buttons of
  the same name (exact scene behaviour not documented). The light's on/off
  state can't be read.
- `/key`: `power` only opens the on-screen power menu; use `POST /power/off` to
  switch the projector off. `/keyboard` types into the focused on-screen input,
  so a text field must already be showing (navigate with `/key` first).
- `POST /capture` returns `{"action": "capture", "image_url": …}`; the image
  is served by the device, so fetch it from the device's LAN.

Responses the document leaves untyped: `/play`, `/pause`, `/stop`, `/next`,
`/previous` → `{"action": "<name>"}` (`/play` adds `speed`); `/cast` →
`{"uri", "autoplay"}`; `/remote/ping` → `{"ok": true}`; `/memory/free` (asks
the projector to free memory by closing background apps) →
`{"action": "free_memory"}`; `/power/off` → `{"action": "power_off"}`;
`/health` → `{"status": "ok", "host": <unit URL>}`.

## Playback and casting

- `/stop`, `/next` and `/previous` change DLNA playback — confirm with the user
  first if something is playing. They don't affect apps such as YouTube.
- `POST /cast` needs a media URL reachable from the device's LAN. It replaces
  the current DLNA media even with `autoplay: false` — if something is being
  watched (or you can't tell), confirm with the user first. The URI is set
  before Play is sent, so if the call fails, check `GET /media` and
  `GET /transport` before resending. `upnp_class` is free text
  (`object.item.videoItem` by default; e.g. `object.item.audioItem`,
  `object.item.imageItem`).

## POST /power/off

Powers the projector down. **Irreversible from this API — it cannot turn the
unit back on. Confirm with the user first.** The body is required (none →
422). Send the JSON `true` for `confirm`; omitted or false-like (`false`,
`"off"`, …) → 400. The API also coerces true-like strings (`"yes"`, `"TRUE"`,
`1`), so never pass an unchecked value. The command is sent over UDP; a 200
doesn't prove the unit received it.

## POST /soap

Raw UPnP SOAP passthrough to `AVTransport` / `RenderingControl` /
`ConnectionManager` (most actions need `"InstanceID": 0` in `args`). Only the
actions below are read-only; any other action (Play / Set* / an unlisted Get*)
**requires `confirm: true`** and can change device state — confirm with the
user before sending one, and prefer the typed endpoints.

Read-only (no `confirm` needed): `GetTransportInfo`, `GetPositionInfo`,
`GetMediaInfo`, `GetTransportSettings`, `GetCurrentTransportActions`,
`GetDeviceCapabilities`, `GetVolume`, `GetVolumeDB`, `GetVolumeDBRange`,
`GetMute`, `ListPresets`, `GetProtocolInfo`, `GetCurrentConnectionIDs`,
`GetCurrentConnectionInfo`. The response is `{"service", "action",
"result"}` with the SOAP response's out-arguments in `result`.
