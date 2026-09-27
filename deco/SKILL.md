---
name: deco
description: "TP-Link Deco BE85 mesh router management. Use when: user asks about home network / Wi-Fi status, connected clients, mesh (Deco) nodes, toggling or reconfiguring Wi-Fi (incl. guest Wi-Fi), WAN/internet status, router system logs, firmware update availability, the last speed test, or rebooting the Deco. Controls the router via the deco-be85-api REST wrapper."
metadata:
  openclaw:
    emoji: "🛜"
    requires:
      bins:
        - curl
        - jq
---

# Deco BE85

Base URL: `https://deco-api.msageha.net/api` (FastAPI wrapper around the TP-Link
Deco BE85 local API). `https://deco.msageha.net` is the router's own web UI, not
this API. Requests to this instance don't need any authentication
header/cookie — the server logs into the router itself with stored credentials.
The reverse proxy only admits allowlisted LAN client IPs — a `403` with an nginx
HTML page means the caller isn't on that list, not an API error.

## Key facts

- Login to the router is lazy: the first call after startup/idle triggers it
  and is slower. Expired sessions are re-logged-in and retried automatically.
- Requests are serialized behind a server-side lock (single router session).
  Call endpoints sequentially; don't fan out parallel requests.
- `band` is `band2_4` / `band5_1` / `band6`; `network` is `host` / `guest`.
- `GET /wireless` returns `ssid`/`password` base64-encoded; write endpoints
  accept them in plain text (the server encodes them). Decode `ssid` for
  display; don't decode or print `password` unless the user explicitly asks
  for the Wi-Fi password.
- Everything under `GET /network/*`, `/wireless/*`, `/device/*`, `/cloud/*`
  and `/system/*` is read-only. `GET /system/firmware` asks TP-Link cloud and
  takes a few seconds; `GET /system/log` pages the router log
  (`level` 1..8 from `/system/log-types`, `index`, `limit`).
- Confirm with the user before any write: Wi-Fi toggles/config changes briefly
  disconnect clients on that band, `POST /reboot` (requires `confirm: true`)
  takes the whole network down for minutes, and `POST /raw` with a non-read
  `operation` can change arbitrary router settings.
- Errors: `401` router auth failure, `502` router-side error (`detail` +
  `error_code`), `504` router unreachable, `422` request validation (missing
  `confirm`, unknown field, bad enum), `400` `confirm: false` on `/reboot`,
  `404` `/reboot` found no Deco units.

## Core operations

| Task                                                                                    | Endpoint                                                                    |
| --------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Overview (WAN/CPU/mem/node & client counts)                                             | `GET /dashboard`                                                            |
| Deco units (mesh nodes)                                                                 | `GET /devices`                                                              |
| Connected clients                                                                       | `GET /clients?online_only=true`                                             |
| Blocked clients                                                                         | `GET /clients/blocked`                                                      |
| Wi-Fi settings (all bands, host/guest)                                                  | `GET /wireless`                                                             |
| Wi-Fi ON/OFF per band                                                                   | `POST /wireless`                                                            |
| Change SSID/password/channel etc.                                                       | `POST /wireless/config`                                                     |
| Radio details (DFS / beamforming / operation mode / bridge / 802.11r roaming / 160 MHz) | `GET /wireless/{power,beamforming,operation-mode,bridge,roaming,bandwidth}` |
| WAN / internet / LAN / IPv6 status                                                      | `GET /network/wan`, `/network/internet`, `/network/lan`, `/network/ipv6`    |
| WAN details (port mode / DHCP dial / IGMP / fast xmit / VLAN / DDNS / MAC clone)        | `GET /network/{wan-mode,dhcp-dial,igmp,fast-xmit,vlan,ddns,mac-clone}`      |
| CPU / memory usage                                                                      | `GET /network/performance`                                                  |
| Router mode / time settings / last speed test                                           | `GET /device/mode`, `/device/time`, `/device/speedtest`                     |
| TP-Link cloud binding / ID login state                                                  | `GET /cloud/device-info`, `/cloud/login-status`                             |
| System log / firmware update check                                                      | `GET /system/log`, `GET /system/firmware`                                   |
| Component info / UI feature switches / log types                                        | `GET /system/component-info`, `/system/switch-list`, `/system/log-types`    |
| Reboot Deco units (destructive)                                                         | `POST /reboot`                                                              |
| Any other Deco endpoint (escape hatch)                                                  | `POST /raw`                                                                 |
| Server health / explicit login                                                          | `GET /health`, `POST /login`, `POST /logout`                                |

Full request/response schemas and ready-to-run curl examples: see
[references/api-reference.md](references/api-reference.md) and
[references/commands.md](references/commands.md).
