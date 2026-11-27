# Deco BE85 API Reference

Base URL: `https://deco-api.msageha.net/api`
FastAPI wrapper (deco-be85-api v0.1.0) around the TP-Link Deco BE85 (FW 1.3.0)
local APIs. `https://deco.msageha.net` is the router's own web UI (proxied to
the Deco at `172.16.1.1`), not this API. Requests to this instance don't need
any authentication header/cookie; the server logs into the router itself. The
reverse proxy admits only allowlisted LAN client IPs and rejects requests whose
`Origin` header names another site (`403` otherwise). Interactive docs:
`https://deco-api.msageha.net/docs`.

The server talks to the router over two paths, each with its own session and
its own server-side lock (requests on one path queue up):

- luci — the web UI's encrypted JSON API. Backs the typed `GET` endpoints,
  `/login`, `/logout`, `/reboot`, `/raw` and `/api/luci/...`. Login is lazy;
  on 401/403, a login page or an empty `{"data": ""}` (another client such as
  the web UI took the session) it re-logs in and resends once.
- TMP — the Deco app's protocol (TLS on port 30001, SPAKE2+ login with the
  owner's TP-Link ID). Backs `POST /wireless`, `POST /wireless/config` and
  `/api/app/...`. Connected on first use and reconnected on the next call if
  dropped. After a write the router may close the TMP port while applying it;
  requests in that window, or right after the router drops the session, get
  `504` and are not resent.

Most read endpoints return the decrypted router response as-is; field sets
can vary by firmware. Model-backed endpoints (`/devices`, `/clients`,
`/network/performance`, `/network/mac-clone`, `/wireless/power`, `/device/*`,
`/cloud/device-info`, `/system/firmware`, and the `decos` in `/dashboard`)
have the documented fields, all nullable, and also keep unknown router fields
(`extra=allow`). `/dashboard` itself has exactly the fields listed.

## Errors

| Status | Meaning                                                                                                                                                                  |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 400    | `confirm: false` on `POST /reboot` or a destructive `/api/luci/...` / `/api/app/...` operation                                                                           |
| 401    | Router authentication failed (`DecoAuthError`). Once TMP rejects the email / password, every later TMP call returns 401 until the server restarts with fixed credentials |
| 403    | Reverse proxy rejected the caller's IP or a cross-site `Origin` (nginx HTML page, not JSON)                                                                              |
| 404    | `POST /reboot` without `macs` found no Deco units; guest toggle without `band` found no band                                                                             |
| 413    | `params` (or Wi-Fi settings) don't fit in one TMP packet (about 64 KiB)                                                                                                  |
| 422    | Request validation error (missing `confirm`, unknown `settings` field, invalid enum / `path`, …)                                                                         |
| 502    | Router returned an error or an invalid response — body has `detail` and router `error_code`                                                                              |
| 504    | Router unreachable on the LAN (`DecoConnectionError`), or the TMP port is closed after a write                                                                           |

`422` details say which field is wrong and why, without echoing the values sent.

---

## System

### GET /health

Server status and login state of both paths.

```json
{
  "status": "ok",
  "host": "http://172.16.1.1",
  "logged_in": true,
  "tmp_connected": false
}
```

`logged_in` is the luci session; `tmp_connected` is whether a TMP session is
open (checked live unless a TMP request is in flight). `false` just means the
next call will log in.

### POST /login / POST /logout

Explicit router login/logout. Rarely needed — login is lazy and automatic.
`POST /login` → `{ "logged_in": true }`, `POST /logout` → `{ "logged_in": false }`.

### GET /system/log

One page of the router's system log. The router first builds a snapshot
filtered by `level`, then the page is read (same two-step as the web UI).

| Parameter | Type    | Default | Description                                                                                                                   |
| --------- | ------- | ------- | ----------------------------------------------------------------------------------------------------------------------------- |
| level     | integer | `8`     | 1..8 — the `value` of an entry in `GET /system/log-types` (1 ALERT … 7 DEBUG, 8 ALL); includes everything up to that severity |
| index     | integer | `0`     | 0-based page number                                                                                                           |
| limit     | integer | `100`   | Entries per page (≥ 1)                                                                                                        |

Response: `{ "totalNum": <pages at this limit>, "currentIndex": <index>, "logList": [{ "content": "..." }] }`

### GET /system/firmware

Asks TP-Link cloud whether each node has a firmware update (takes a few
seconds; nothing is downloaded or applied). Response: array of (every field
nullable — a node with `need_to_upgrade` or `software_ver` `null` is unknown,
not up to date)

| Field                                | Type    | Description                        |
| ------------------------------------ | ------- | ---------------------------------- |
| mac / device_model / software_ver    | string  | Node identity and current version  |
| new_version                          | string  | Latest available version           |
| need_to_upgrade / need_force_upgrade | boolean | Update available / forced          |
| release_date                         | string  | Release date of the latest version |

### GET /system/component-info / GET /system/switch-list / GET /system/log-types

Raw router responses: ERP / power-saving component info, UI feature switches,
and the log categories (`value` = the `level` accepted by `/system/log`).

---

## Status

### GET /dashboard

Aggregated overview (device list + client list + performance + WAN).

| Field                 | Type           | Description                 |
| --------------------- | -------------- | --------------------------- |
| internet_online       | boolean        | WAN IPv4 address present    |
| connection_type       | string \| null | WAN dial type (e.g. `dhcp`) |
| wan_ipv4              | string \| null | Current WAN IPv4 address    |
| cpu_usage / mem_usage | number \| null | Main Deco usage, 0..1 ratio |
| deco_count            | integer        | Number of mesh nodes        |
| online_clients        | integer        | Currently online clients    |
| decos                 | DecoNode[]     | See `GET /devices`          |

---

## Devices

### GET /devices

Deco units (mesh nodes). Response: `DecoNode[]` (every field nullable).

| Field                                     | Type    | Description                                                                |
| ----------------------------------------- | ------- | -------------------------------------------------------------------------- |
| mac                                       | string  | Node MAC address (used by `POST /reboot`)                                  |
| role                                      | string  | `master` / `slave`                                                         |
| device_model                              | string  | e.g. `BE85`                                                                |
| device_type / hardware_ver / software_ver | string  | Model/firmware info                                                        |
| device_ip                                 | string  | Node LAN IP                                                                |
| nickname                                  | string  | Location name (server-side decoded to plain text; so is `custom_nickname`) |
| online                                    | boolean | Node online state                                                          |
| inet_status                               | string  | Internet reachability of the node                                          |

---

## Clients

### GET /clients

Connected client devices. Response: `ClientDevice[]` (every field nullable).

| Parameter   | Type    | Description                                             |
| ----------- | ------- | ------------------------------------------------------- |
| online_only | boolean | `true` = only currently online clients (default: false) |

| Field                       | Type    | Description                                     |
| --------------------------- | ------- | ----------------------------------------------- |
| mac / ip                    | string  | Client addresses                                |
| name                        | string  | Client name (server-side decoded to plain text) |
| online                      | boolean | Online state                                    |
| interface                   | string  | Which Wi-Fi/LAN interface                       |
| connection_type / wire_type | string  | e.g. `band5`, wired vs wireless                 |
| client_type                 | string  | Device category reported by the router          |
| down_speed / up_speed       | integer | Current traffic in kbps (not the link speed)    |
| access_host                 | boolean | Whether the client may access the router        |

### GET /clients/blocked

Clients on the router's block list. Same `ClientDevice[]` shape.

---

## Network

### GET /network/wan

Raw WAN IPv4 status. Known structure: `wan.dial_type` (connection type),
`wan.ip_info.ip` (public IPv4), plus gateway/DNS fields.

### GET /network/internet

Internet connection info for IPv4/IPv6 (raw router response).

### GET /network/lan

LAN IP / DHCP DNS / WAN IP (raw router response).

### GET /network/ipv6

IPv6 enable state (raw router response).

### GET /network/performance

```json
{ "cpu_usage": 0.12, "mem_usage": 0.47 }
```

### GET /network/mac-clone

MAC clone setting: `{ "enable": ... }`.

### Other WAN settings (raw router responses)

| Endpoint                 | Contents                              |
| ------------------------ | ------------------------------------- |
| `GET /network/wan-mode`  | WAN port operating mode               |
| `GET /network/dhcp-dial` | WAN DHCP dial settings (unicast etc.) |
| `GET /network/igmp`      | IGMP (multicast) settings             |
| `GET /network/fast-xmit` | Fast xmit enable state                |
| `GET /network/vlan`      | VLAN (IPTV) settings                  |
| `GET /network/ddns`      | DDNS enable state and domain          |

---

## Wireless

`band`: `band2_4` / `band5_1` / `band6`. `network`: `host` / `guest`.

### GET /wireless

Full Wi-Fi config, keyed by band with `host` / `guest` sub-objects
(enable, ssid, password, channel, channel_width, mode, …).
**`ssid` and `password` are base64-encoded** in this response — decode `ssid`
with `@base64d` (jq) when showing it to the user. `password` is a secret: leave
it encoded and out of the output unless the user explicitly asks for it.

### POST /wireless

Toggle Wi-Fi ON/OFF for one band, or for the non-separate guest bands at once. Written over
TMP. **Briefly disconnects clients — confirm first.**

| Field   | Type    | Required       | Description                     |
| ------- | ------- | -------------- | ------------------------------- |
| band    | enum    | unless `guest` | `band2_4` / `band5_1` / `band6` |
| network | enum    | no             | `host` (default) / `guest`      |
| enable  | boolean | yes            | Target state                    |

With `network: guest` and `band` omitted or `null`, one write toggles the guest network on
every band whose guest isn't `is_separate` in `/api/app/wireless/wlan/read`
(2.4 and 5 GHz on the BE85); `404` if there is none. The 6 GHz guest
(`is_separate: true`) is untouched even by `enable: false` — pass `band6` to
change it. It is configured separately in the Deco app, and on this unit is
unconfigured with `encryption_mode: owe` (no password), so enabling it can
broadcast a passwordless guest SSID.

Response: `{ "updated": { "<band>": { "<network>": { "enable": ... } }, ... } }`
(one entry per band changed).

### POST /wireless/config

Change Wi-Fi settings for one band+network over TMP. Only provided fields are
written. **Briefly disconnects clients on that band — confirm first.**

| Field    | Type   | Required | Description                               |
| -------- | ------ | -------- | ----------------------------------------- |
| band     | enum   | yes      | `band2_4` / `band5_1` / `band6`           |
| network  | enum   | no       | `host` (default) / `guest`                |
| settings | object | yes      | At least 1 field; unknown fields rejected |

`settings` fields (all optional):

| Field                          | Type                  | Notes                                                                                                                     |
| ------------------------------ | --------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| enable                         | bool                  |                                                                                                                           |
| ssid / password                | string                | Plain text — the server base64-encodes them                                                                               |
| enable_hide_ssid               | bool                  |                                                                                                                           |
| channel / channel_width / mode | int / string / string | Radio settings: apply to the whole band whatever `network` is. `channel: 0` = auto                                        |
| encryption_mode                | string                | e.g. `wpa2`, `wpa3`, `owe`                                                                                                |
| enable_wpa3                    | bool                  |                                                                                                                           |
| host_isolation                 | bool                  | Guest only: block guest clients from reaching the main network                                                            |
| access_duration                | int ≥ -1              | Guest only: how long guest Wi-Fi stays on; `-1` = no limit, else the unit `/api/app/wireless/wlan/read` uses              |
| bandwidth_limit                | object                | Guest only: at least one of `enable` (bool), `downstream_bandwidth` / `upstream_bandwidth` (int ≥ 0, unit as in the read) |

Guest-only fields on `host` are rejected with `422`. Current values come from
`GET /wireless` (`band.host` / `band.guest`); guest-only fields from
`POST /api/app/wireless/wlan/read`. With an automatic channel, `GET /wireless`
reports the channel in use, so it may differ from what was written.

Response: `{ "updated": { "<band>": { "<network>": { ...settings, "password": "***" } } }, "result": <router result> }`.
Only `updated.*.password` is masked; show `updated` rather than the whole body.

### GET /wireless/power

Radio capabilities, e.g. `{ "support_dfs": true, ... }`.

### Other radio settings (raw router responses)

| Endpoint                       | Contents                              |
| ------------------------------ | ------------------------------------- |
| `GET /wireless/beamforming`    | Beamforming enable state              |
| `GET /wireless/operation-mode` | Wireless operation mode (AP / router) |
| `GET /wireless/bridge`         | Bridge / PLC state                    |
| `GET /wireless/roaming`        | 802.11r fast roaming enable state     |
| `GET /wireless/bandwidth`      | 160 MHz width (HT160) enable state    |

---

## Device / Cloud info

| Endpoint                  | Response                                                                                                                |
| ------------------------- | ----------------------------------------------------------------------------------------------------------------------- |
| `GET /device/mode`        | `{ region, workmode, sysmode }` (region may be a dict like `{"device": "JP"}`)                                          |
| `GET /device/time`        | `{ time, date, timezone, tz_region, continent, dst_status }`                                                            |
| `GET /device/speedtest`   | Last speed test `{ down_speed, up_speed (kbps), last_speed_test_time (Unix s), ever_tested, status }` — doesn't run one |
| `GET /cloud/device-info`  | `{ cloudUserName, role, model }` (TP-Link cloud binding)                                                                |
| `GET /cloud/login-status` | TP-Link ID login state (raw)                                                                                            |

---

## POST /reboot

Reboot Deco units. **Destructive — rebooting all units takes the whole
network down for a few minutes; rebooting one drops its clients and the mesh
links behind it. Always confirm with the user first, naming the nodes.**

| Field   | Type     | Required | Description                                                                                                                  |
| ------- | -------- | -------- | ---------------------------------------------------------------------------------------------------------------------------- |
| confirm | boolean  | yes      | Must be `true`; `false` → 400, missing → 422                                                                                 |
| macs    | string[] | no       | Node MACs (from `GET /devices`). Omitted, `null` or `[]` = all units (404 if none) — never send an empty list meaning "none" |

Response: `{ "rebooting": ["AA-BB-CC-DD-EE-FF", ...] }`

---

## POST /raw

Generic passthrough to any Deco endpoint — not limited to the catalogue of
`/api/luci/...`, so it can reach forms that return credentials; print only the
fields needed. Returns the full decrypted envelope
(`result`/`error_code` or `success`/`data`) unmodified.

| Field     | Type   | Required | Description                                                                                                              |
| --------- | ------ | -------- | ------------------------------------------------------------------------------------------------------------------------ |
| path      | string | yes      | Relative path like `admin/<module>?form=<form>` (letters/digits/underscore, single `?form=`; no scheme, no `..`)         |
| operation | enum   | no       | `read` (default) / `write` / `load` / `list` / `get` / `set` / `add` / `edit` / `remove` / `operate` / `check` / `build` |
| params    | object | no       | Extra params passed through to the router                                                                                |

**Non-`read` operations can change arbitrary router settings — confirm with
the user and prefer the typed endpoints above when one exists.** The
`reboot` operation used by `POST /reboot` is deliberately not in the enum.
A router-side error in the envelope comes back as `200`; an HTTP error or
invalid response from the called endpoint is `502`.

Paths used internally by the typed endpoints (useful starting points):

| Path                                                                                                                                                | Operation    | Backs                                                         |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ------------------------------------------------------------- |
| `admin/device?form=device_list`                                                                                                                     | read         | `/devices`                                                    |
| `admin/client?form=client_list` (`params: {"device_mac": "default"}`)                                                                               | read         | `/clients`                                                    |
| `admin/client?form=black_list`                                                                                                                      | list         | `/clients/blocked`                                            |
| `admin/network?form=wan_ipv4` / `internet` / `performance` / `mac_clone` / `wan_mode` / `dhcp_dial` / `igmp_setting` / `fast_xmit_setting` / `vlan` | read         | `/network/*`                                                  |
| `admin/network?form=lan_ip` / `ipv6` (`params: {"device_mac": "default"}`)                                                                          | read         | `/network/lan`, `/network/ipv6`                               |
| `admin/cloud?form=ddns`                                                                                                                             | get          | `/network/ddns`                                               |
| `admin/wireless?form=wlan`                                                                                                                          | read         | `GET /wireless` (writes go over TMP — see below)              |
| `admin/wireless?form=power` / `beamforming` / `operation_mode` / `bridge` / `ieee80211r` / `bandwidth_enhance`                                      | read         | `/wireless/*`                                                 |
| `admin/device?form=mode` / `timesetting` / `speedtest`                                                                                              | read         | `/device/*`                                                   |
| `admin/cloud_account?form=get_deviceInfo` / `check_login`                                                                                           | read         | `/cloud/device-info`, `/cloud/login-status`                   |
| `admin/web?form=extra_component_info`                                                                                                               | get          | `/system/component-info`                                      |
| `admin/component_control?form=switch_list`                                                                                                          | read         | `/system/switch-list`                                         |
| `admin/log_export?form=types`                                                                                                                       | read         | `/system/log-types`                                           |
| `admin/log_export?form=feedback_log`                                                                                                                | build → read | `/system/log` (`params: {"level"}` then `{"index", "limit"}`) |
| `admin/cloud?form=firmware_status`                                                                                                                  | check        | `/system/firmware`                                            |

---

## luci and Deco-app operations

One endpoint per catalogued operation, recovered from the FW 1.3.0 image
(154 luci + 384 TMP operations; exclusions below). Listed in `/docs` under tags
`luci: <module>` / `app: <controller>`.

| Endpoint                                        | Calls                                                                            |
| ----------------------------------------------- | -------------------------------------------------------------------------------- |
| `POST /api/luci/<module>/<form>/<operation>`    | luci `admin/<module>?form=<form>` (`locale` has no `admin/`) with that operation |
| `POST /api/app/<controller>/<form>/<operation>` | TMP opcode of that operation (same path the Deco app uses)                       |

`/api/app/...` also covers features luci lacks: port forwarding, DHCP leases,
HomeShield, QoS, Wi-Fi schedules, VPN, LEDs, …

Request body (optional for non-destructive operations):

| Field   | Type    | Required         | Description                                                     |
| ------- | ------- | ---------------- | --------------------------------------------------------------- |
| params  | object  | no               | Passed to the router as-is; omitted = no params sent            |
| confirm | boolean | destructive only | Must be JSON `true`; `false` → 400, missing / non-boolean → 422 |

Response: the success body (`result` / `data`) as-is; a router error is `502`.

Each operation's OpenAPI entry carries `x-deco-luci-path` or
`x-deco-tmp-opcode`, `x-deco-operation` and `x-deco-destructive`.
Destructive (`confirm` required, 68 operations): anything that cuts the Deco
or the whole network off (reboot, factory reset, firmware upgrade, WAN
disconnect, LAN / WAN / mesh / IPTV connection settings, port media,
operation mode, main node, mesh group) or can't be undone (unbinding nodes
or the cloud, admin account / TP-Link ID changes, clearing logs, history,
reports, messages). Other writes — Wi-Fi, VPN, LEDs, reservations, port
forwarding, blocking — run without `confirm`, so confirm with the user
yourself.

- `params` are not validated by this API; required fields differ per
  operation and firmware. The `read` / `get` response of the same form shows
  the shape to write back.
- Use `POST /wireless` / `POST /wireless/config` (or
  `/api/app/wireless/wlan/write`) for Wi-Fi writes: luci's
  `/api/luci/wireless/wlan/write` fails guest writes with HTTP 500.
- OpenVPN profile insert/update (`/api/app/vpn_client/server/{insert,update}`)
  needs a config file already uploaded to the router; this API can't upload
  files, so set OpenVPN up in the Deco app.
- Responses return what the router stores, including Wi-Fi / PPPoE / VPN
  passwords and WireGuard keys — don't print them unless asked.
- Not exposed: pre-login steps, mesh node-to-node calls, debug opcodes,
  multipart / file transfer forms (config backup / restore, firmware
  upload), and reads that return the admin password or cloud tokens.

Operations used for common tasks:

| Task                     | Steps                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Run a speed test         | `POST /api/luci/device/speedtest/write` `{}`, then poll `GET /device/speedtest` every few seconds until `status` is `idle`, `ever_tested` is true and `last_speed_test_time` is a new number (`fail` = failed; about 1 min; fields can be `null` mid-test). Speeds are kbps                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| Firmware upgrade         | `GET /system/firmware` (the router only reports download progress after a check in the same session; stop unless a node has `need_to_upgrade`) → `POST /api/luci/cloud/firmware/download` `{}` → poll `POST /api/luci/cloud/firmware_status/read` until `download_progress` is 100 (check `status` first: 5 consecutive polls with `status` `fail`, `preparing` or missing = failed, and their `download_progress` doesn't count) → `POST /api/luci/cloud/firmware_status/upgrade` `{"confirm": true}`; the response's `upgrade_time` + `reboot_time` (s) is the expected downtime. If the upgrade call loses its response (timeout / 5xx) it may have started — wait, then check `software_ver` before retrying |
| LEDs                     | `POST /api/app/device/led/read` `{}` → `{enable, enable_night_mode, time_begin, time_end, …}`; `POST /api/app/device/led/write` `{"params": {"enable": <bool>}}`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Guest-only Wi-Fi details | `POST /api/app/wireless/wlan/read` `{}` (per band: `guest.is_separate`, `host_isolation`, `access_duration`, `bandwidth_limit`; also passwords)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| DHCP reservations        | `POST /api/luci/client/addr_reservation/getlist` `{}` (`add` / `modify` / `remove` to change)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Port forwarding          | `POST /api/app/nat/vs/getlist` `{}` (`add` / `modify` / `remove` to change)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| Block / unblock a client | `POST /api/luci/client/black_list/{block,unblock}` (list: `GET /clients/blocked`)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
