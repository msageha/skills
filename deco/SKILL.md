---
name: deco
description: "TP-Link Deco BE85 mesh router management. Use when: user asks about home network / Wi-Fi status, connected clients, mesh (Deco) nodes, toggling or reconfiguring Wi-Fi (incl. guest Wi-Fi), WAN/internet status, or rebooting the Deco. Controls the router via the deco-be85-api REST wrapper."
metadata:
  openclaw:
    emoji: "🛜"
    requires:
      bins:
        - curl
---

# Deco BE85

Base URL: `https://daikin.msageha.net/api` (FastAPI wrapper around the TP-Link
Deco BE85 local API). Requests to this instance don't need any authentication
header/cookie — the server logs into the router itself with stored credentials.

## Key facts

- Login to the router is lazy: the first call after startup/idle triggers it
  and is slower. Expired sessions are re-logged-in and retried automatically.
- Requests are serialized behind a server-side lock (single router session).
  Call endpoints sequentially; don't fan out parallel requests.
- `band` is `band2_4` / `band5_1` / `band6`; `network` is `host` / `guest`.
- `GET /wireless` returns `ssid`/`password` base64-encoded; write endpoints
  accept them in plain text (the server encodes them).
- Confirm with the user before any write: Wi-Fi toggles/config changes briefly
  disconnect clients on that band, `POST /reboot` (requires `confirm: true`)
  takes the whole network down for minutes, and `POST /raw` with a non-read
  `operation` can change arbitrary router settings.
- Errors: `401` router auth failure, `502` router-side error (`detail` +
  `error_code`), `504` router unreachable, `400`/`422` request validation.

## Core operations

| Task | Endpoint |
|---|---|
| Overview (WAN/CPU/mem/node & client counts) | `GET /dashboard` |
| Deco units (mesh nodes) | `GET /devices` |
| Connected clients | `GET /clients?online_only=true` |
| Blocked clients | `GET /clients/blocked` |
| Wi-Fi settings (all bands, host/guest) | `GET /wireless` |
| Wi-Fi ON/OFF per band | `POST /wireless` |
| Change SSID/password/channel etc. | `POST /wireless/config` |
| WAN / internet / LAN / IPv6 status | `GET /network/wan`, `/network/internet`, `/network/lan`, `/network/ipv6` |
| CPU / memory usage | `GET /network/performance` |
| Reboot Deco units (destructive) | `POST /reboot` |
| Any other Deco endpoint (escape hatch) | `POST /raw` |
| Server health / explicit login | `GET /health`, `POST /login`, `POST /logout` |

Full request/response schemas and ready-to-run curl examples: see
[references/api-reference.md](references/api-reference.md) and
[references/commands.md](references/commands.md).
