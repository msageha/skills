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
  typed `GET` endpoints, `/raw`, `/reboot`, `/luci/...`) and TMP (the Deco
  app's protocol; Wi-Fi writes and `/app/...`). Each logs in lazily on its
  first call (slower) and re-logs in automatically when the session expires.
  Requests on each path are serialized server-side — call sequentially.
- `band` is `band2_4` / `band5_1` / `band6`; `network` is `host` / `guest`.
- Guest Wi-Fi: `POST /wireless` with `network: guest` and no `band` toggles
  the 2.4 + 5 GHz guests together (the bands whose guest isn't
  `is_separate`). The 6 GHz guest is separate, unconfigured, and uses OWE (no
  password): enabling the `band6` guest broadcasts a guest SSID with no
  password, so confirm it as an access change (below).
- `GET /wireless` returns `ssid`/`password` base64-encoded;
  `POST /wireless/config` takes them in plain text (the server encodes them),
  while `/app/...` and `/raw` pass `params` as-is. Decode `ssid` for
  display. Responses (`/wireless`, `/app/wireless/wlan/read`, VPN, PPPoE,
  `/raw` …) can hold Wi-Fi passwords and keys: select only the fields needed
  with jq, so a password or key never reaches your output. When the user wants
  to see one, give them a command to run themselves instead of running it.
  A `502` puts the router's raw answer in `detail`, which can hold the same
  secrets: on an error, print only the status and `error_code`, not the body
  (`curl -sf` prints no error body).
- `GET` endpoints don't change settings. `GET /system/log` builds a log
  snapshot on the router (`feedback_log` `build`) before reading it, which is
  fine when the user asks for the log. `GET /system/firmware` asks TP-Link cloud
  and takes a few seconds; `GET /system/log` pages the router log (`level`
  1..8 from `/system/log-types`, `index`, `limit`).
- `POST /luci/<module>/<form>/<operation>` and
  `POST /app/<controller>/<form>/<operation>` expose the operations
  catalogued from the firmware (≈540, excluding file transfer and reads
  that return the admin password or cloud tokens; list them from
  `/openapi.json`, whose paths start with `/api`). Body is
  `{"params": {...}}` (optional), passed through unvalidated; a router-side
  rejection is `502`. An operation's name doesn't show whether it is
  side-effect free: some reads may mark messages read or start a scan or test
  (`cloud/message/read`, `acs_optimize/read`, `internet_test/get`). A call
  the user didn't ask for (one you make to look something up) runs without
  asking only when its OpenAPI entry has `x-deco-read-only: true`; confirm
  any other one first. A call the user asked for follows the confirmation
  rules below.
  Operations that cut off the network or can't be undone
  (`x-deco-destructive`) also need `"confirm": true`.
- Confirm these even when the user asked for them, naming the target, the
  effect and how to undo it: rebooting (all nodes take the network down for
  minutes; one node drops the clients and mesh links behind it), a firmware
  upgrade (network down for minutes), and any other `x-deco-destructive`
  operation (factory reset, unbinding, WAN disconnect …): say what is lost
  and how to recover it before sending `"confirm": true`.
- Also confirm these even when the request is specific, after reading the
  current entries and showing current → new (for a password, say that it
  changes without showing either value): Wi-Fi writes (`POST /wireless`,
  `POST /wireless/config`; they briefly disconnect clients on the band) and
  other changes to who can reach what — guest isolation, port forwarding,
  client blocking, DHCP reservations, WAN / IPv6 DNS, DDNS, remote management
  and VPN. Guest settings are per band: change and read back every band the
  request covers. Open only the ports and hosts the use needs.
- Any other write the user asked for, with its target settled, runs without
  asking again; confirm once when you chose it yourself or when the request
  doesn't settle the target (which node, band or network). `/luci/...` /
  `/app/...` operations can change router settings (non-destructive ones run
  without `confirm`). `/raw` reaches any form, so confirm it too unless it
  calls one of the read path + operation pairs that back the typed `GET`
  endpoints (listed in api-reference; for `feedback_log`, only `read`).
- After a TMP write the router may close the TMP port while applying it; the
  next `/app/...` or Wi-Fi write can get `504` for a short while — wait
  and re-read the state rather than blindly resending.
- `POST /reboot` with `macs` omitted, `null` or `[]` reboots every node —
  when targeting specific nodes and the MAC lookup comes back empty, stop.
- Send requests as commands.md does, with `curl -sSf` under
  `set -o pipefail`. A failed connection or an HTTP status of 400 or above
  then exits non-zero and prints the error to stderr instead of the body, so
  an error body never reaches a jq filter, which would print it or turn its
  missing fields into `null` that reads like a result. A `502` body can also hold secrets, which `-f` keeps out of your output. Treat a write
  as done only when curl exited 0. A 4xx means the request was rejected and
  nothing changed: check it against the operation's schema
  (api-reference) rather than resending it to read the error. After
  a 5xx, a timeout or a dropped connection the write may have taken effect:
  read the state before resending.
- Report a write as done only after reading the new state back with the
  matching read (`GET /wireless` for Wi-Fi, `POST /app/wireless/wlan/read` for
  the guest-only `host_isolation` / `access_duration` / `bandwidth_limit`, the
  form's `read` / `getlist` for
  `/luci/...` and `/app/...` writes). A TMP write can take a moment to apply.
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
| Run a speed test                                                                        | `POST /luci/device/speedtest/write`, then poll `GET /device/speedtest`                      |
| TP-Link cloud binding / ID login state                                                  | `GET /cloud/device-info`, `/cloud/login-status`                                             |
| System log / firmware update check                                                      | `GET /system/log`, `GET /system/firmware`                                                   |
| Firmware upgrade (destructive)                                                          | `GET /system/firmware` → `/luci/cloud/firmware/download` → `firmware_status/{read,upgrade}` |
| Deco LEDs                                                                               | `POST /app/device/led/{read,write}`                                                         |
| DHCP reservations / port forwarding / block a client                                    | `/luci/client/addr_reservation/*`, `/app/nat/vs/*`, `/luci/client/black_list/*`             |
| Component info / UI feature switches / log types                                        | `GET /system/component-info`, `/system/switch-list`, `/system/log-types`                    |
| Reboot Deco units (destructive)                                                         | `POST /reboot`                                                                              |
| Any other router operation                                                              | `POST /luci/...`, `POST /app/...`, `POST /raw`                                              |
| Server health / explicit login                                                          | `GET /health`, `POST /login`, `POST /logout`                                                |

Errors, behaviour the OpenAPI document doesn't describe, and how to look up an
endpoint's request/response schema in it: see
[references/api-reference.md](references/api-reference.md). Ready-to-run curl
examples: [references/commands.md](references/commands.md).
