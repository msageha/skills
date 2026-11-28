---
name: deco
description: "TP-Link Deco BE85 mesh router management. Use when: user asks about home network / Wi-Fi status, connected clients, mesh (Deco) nodes, toggling or reconfiguring Wi-Fi (incl. guest Wi-Fi), WAN/internet status, router system logs, firmware update check or upgrade, running or reading a speed test, the Deco LEDs, DHCP reservations, port forwarding, client blocking, or rebooting the Deco. Controls the router via the deco-be85-api REST wrapper."
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
Deco BE85 local APIs). `https://deco.msageha.net` is the router's own web UI, not
this API. Requests to this instance don't need any authentication
header/cookie — the server logs into the router itself with stored credentials.
The reverse proxy only admits allowlisted LAN client IPs, and rejects requests
whose `Origin` header names another site — a `403` with an nginx HTML page
means one of these, not an API error.

## Key facts

- The server reaches the router over two paths: luci (the web UI's API; the
  typed `GET` endpoints, `/raw`, `/reboot`, `/api/luci/...`) and TMP (the Deco
  app's protocol; Wi-Fi writes and `/api/app/...`). Each logs in lazily on its
  first call (slower) and re-logs in automatically when the session expires.
  Requests on each path are serialized server-side — call sequentially.
- `band` is `band2_4` / `band5_1` / `band6`; `network` is `host` / `guest`.
- Guest Wi-Fi: `POST /wireless` with `network: guest` and no `band` toggles
  the 2.4 + 5 GHz guests together (the bands whose guest isn't
  `is_separate`). The 6 GHz guest is separate, unconfigured, and uses OWE (no
  password) — don't enable `band6` guest without warning the user that it
  would broadcast a guest SSID with no password.
- `GET /wireless` returns `ssid`/`password` base64-encoded;
  `POST /wireless/config` takes them in plain text (the server encodes them),
  while `/api/app/...` and `/raw` pass `params` as-is. Decode `ssid` for
  display. Responses (`/wireless`, `/api/app/wireless/wlan/read`, VPN, PPPoE
  …) can hold Wi-Fi passwords and keys — don't decode or print them unless
  the user explicitly asks.
- `GET` endpoints are read-only. `GET /system/firmware` asks TP-Link cloud
  and takes a few seconds; `GET /system/log` pages the router log (`level`
  1..8 from `/system/log-types`, `index`, `limit`).
- `POST /api/luci/<module>/<form>/<operation>` and
  `POST /api/app/<controller>/<form>/<operation>` expose the operations
  catalogued from the firmware (≈540, excluding file transfer and reads
  that return the admin password or cloud tokens; list them from
  `/openapi.json`). Body is
  `{"params": {...}}` (optional), passed through unvalidated; a router-side
  rejection is `502`. Read-like operations (`read`, `get`, `getlist`, `list`,
  `load`, `check`) are safe. Operations that cut off the network or can't be
  undone (`x-deco-destructive`) also need `"confirm": true`.
- Confirm with the user before any write: Wi-Fi toggles/config changes
  briefly disconnect clients, rebooting all nodes or a firmware upgrade takes
  the whole network down for minutes (rebooting one node drops the clients
  and mesh links behind it — name the node when asking), and non-read `/raw` / `/api/luci/...` /
  `/api/app/...` operations change router settings (non-destructive ones run
  without `confirm`). Running a speed test the user asked for is fine.
- After a TMP write the router may close the TMP port while applying it; the
  next `/api/app/...` or Wi-Fi write can get `504` for a short while — wait
  and re-read the state rather than blindly resending.
- `POST /reboot` with `macs` omitted, `null` or `[]` reboots every node —
  when targeting specific nodes and the MAC lookup comes back empty, stop.
- Treat a request as successful only when curl exits 0 and the HTTP status
  is the one the operation returns on success; `| jq` output proves neither
  (without `set -o pipefail`, `curl … | jq` exits with jq's status, and
  `curl -f` lets a `3xx` through). Save the body with `-o <file>`, read the
  status with `-w '%{http_code}'`, and process the body only after both
  checks pass.
- Errors: `400` `confirm: false`, `401` router auth failure (a rejected TMP
  login persists until the server restarts with fixed credentials), `404` nothing
  to reboot / no guest band to toggle, `413` `params` too large for one TMP
  packet, `422` request validation (missing `confirm`, unknown field, bad
  enum), `502` router-side error (`detail` + `error_code`), `504` router
  unreachable.

## Core operations

| Task                                                                                    | Endpoint                                                                                    |
| --------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Overview (WAN/CPU/mem/node & client counts)                                             | `GET /dashboard`                                                                            |
| Deco units (mesh nodes)                                                                 | `GET /devices`                                                                              |
| Connected clients                                                                       | `GET /clients?online_only=true`                                                             |
| Blocked clients                                                                         | `GET /clients/blocked`                                                                      |
| Wi-Fi settings (all bands, host/guest)                                                  | `GET /wireless`                                                                             |
| Wi-Fi ON/OFF per band, or the non-separate guest bands at once                          | `POST /wireless`                                                                            |
| Change SSID/password/channel/encryption/guest limits                                    | `POST /wireless/config`                                                                     |
| Radio details (DFS / beamforming / operation mode / bridge / 802.11r roaming / 160 MHz) | `GET /wireless/{power,beamforming,operation-mode,bridge,roaming,bandwidth}`                 |
| WAN / internet / LAN / IPv6 status                                                      | `GET /network/wan`, `/network/internet`, `/network/lan`, `/network/ipv6`                    |
| WAN details (port mode / DHCP dial / IGMP / fast xmit / VLAN / DDNS / MAC clone)        | `GET /network/{wan-mode,dhcp-dial,igmp,fast-xmit,vlan,ddns,mac-clone}`                      |
| CPU / memory usage                                                                      | `GET /network/performance`                                                                  |
| Router mode / time settings / last speed test                                           | `GET /device/mode`, `/device/time`, `/device/speedtest`                                     |
| Run a speed test                                                                        | `POST /api/luci/device/speedtest/write`, then poll `GET /device/speedtest`                  |
| TP-Link cloud binding / ID login state                                                  | `GET /cloud/device-info`, `/cloud/login-status`                                             |
| System log / firmware update check                                                      | `GET /system/log`, `GET /system/firmware`                                                   |
| Firmware upgrade (destructive)                                                          | `/api/luci/cloud/firmware/download` → `firmware_status/{read,upgrade}`                      |
| Deco LEDs                                                                               | `POST /api/app/device/led/{read,write}`                                                     |
| DHCP reservations / port forwarding / block a client                                    | `/api/luci/client/addr_reservation/*`, `/api/app/nat/vs/*`, `/api/luci/client/black_list/*` |
| Component info / UI feature switches / log types                                        | `GET /system/component-info`, `/system/switch-list`, `/system/log-types`                    |
| Reboot Deco units (destructive)                                                         | `POST /reboot`                                                                              |
| Any other router operation                                                              | `POST /api/luci/...`, `POST /api/app/...`, `POST /raw`                                      |
| Server health / explicit login                                                          | `GET /health`, `POST /login`, `POST /logout`                                                |

Errors, behaviour the OpenAPI document doesn't describe, and how to look up an
endpoint's request/response schema in it: see
[references/api-reference.md](references/api-reference.md). Ready-to-run curl
examples: [references/commands.md](references/commands.md).
