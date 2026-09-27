# Deco BE85 API Reference

Base URL: `https://deco-api.msageha.net/api`
FastAPI wrapper (deco-be85-api v0.1.0) around the TP-Link Deco BE85 local web
API. `https://deco.msageha.net` is the router's own web UI (proxied to the
Deco at `172.16.1.1`), not this API. Requests to this instance don't need any
authentication header/cookie; the server performs the router login itself
(lazy on first call, with up to 1 automatic retry on session expiry). The
reverse proxy admits only allowlisted LAN client IPs (`403` otherwise).
Interactive docs: `https://deco-api.msageha.net/docs`.

Most read endpoints return the decrypted router response as-is; field sets
can vary by firmware. Model-backed endpoints (`/dashboard`, `/devices`,
`/clients`, `/network/performance`, `/network/mac-clone`, `/wireless/power`,
`/device/*`, `/cloud/device-info`, `/system/firmware`) have the documented
fields but also keep unknown router fields (`extra=allow`).

## Errors

| Status | Meaning                                                                                          |
| ------ | ------------------------------------------------------------------------------------------------ |
| 400    | `POST /reboot` with `confirm: false`                                                             |
| 401    | Router authentication failed (`DecoAuthError`)                                                   |
| 403    | Reverse proxy rejected the caller's IP (nginx HTML page, not JSON)                               |
| 404    | `POST /reboot` without `macs` found no Deco units                                                |
| 422    | Request validation error (missing `confirm`, unknown `settings` field, invalid enum / `path`, …) |
| 502    | Router returned an error — body has `detail` and router `error_code`                             |
| 504    | Router unreachable on the LAN (`DecoConnectionError`)                                            |

Requests are serialized behind a server-side lock; concurrent calls queue up.

---

## System

### GET /health

Server status without touching the router.

```json
{ "status": "ok", "host": "http://172.16.1.1", "logged_in": true }
```

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
seconds; nothing is downloaded or applied). Response: array of

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

| Field                 | Type       | Description                 |
| --------------------- | ---------- | --------------------------- |
| internet_online       | boolean    | WAN IPv4 address present    |
| connection_type       | string     | WAN dial type (e.g. `dhcp`) |
| wan_ipv4              | string     | Current WAN IPv4 address    |
| cpu_usage / mem_usage | number     | Usage of the main Deco unit |
| deco_count            | integer    | Number of mesh nodes        |
| online_clients        | integer    | Currently online clients    |
| decos                 | DecoNode[] | See `GET /devices`          |

---

## Devices

### GET /devices

Deco units (mesh nodes). Response: `DecoNode[]`.

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

Connected client devices. Response: `ClientDevice[]`.

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
| down_speed / up_speed       | integer | Current transfer speeds                         |
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

Toggle one band's Wi-Fi ON/OFF. **Briefly disconnects clients — confirm first.**

| Field   | Type    | Required | Description                     |
| ------- | ------- | -------- | ------------------------------- |
| band    | enum    | yes      | `band2_4` / `band5_1` / `band6` |
| network | enum    | no       | `host` (default) / `guest`      |
| enable  | boolean | yes      | Target state                    |

Response: `{ "updated": { "<band>": { "<network>": { "enable": ... } } } }`

### POST /wireless/config

Change Wi-Fi settings for one band+network. Only provided fields are written.
**Briefly disconnects clients on that band — confirm first.**

| Field    | Type   | Required | Description                               |
| -------- | ------ | -------- | ----------------------------------------- |
| band     | enum   | yes      | `band2_4` / `band5_1` / `band6`           |
| network  | enum   | no       | `host` (default) / `guest`                |
| settings | object | yes      | At least 1 field; unknown fields rejected |

`settings` fields (all optional): `enable` (bool), `ssid` (string, plain text —
server base64-encodes), `password` (string, plain text — server base64-encodes),
`enable_hide_ssid` (bool), `channel` (int), `channel_width` (string),
`mode` (string). Current values (and valid channel/width/mode options) come
from `GET /wireless`.

Response: `{ "updated": { "<band>": { "<network>": { ...settings, "password": "***" } } }, "result": <router result> }`

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

| Endpoint                  | Response                                                                                                           |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `GET /device/mode`        | `{ region, workmode, sysmode }` (region may be a dict like `{"device": "JP"}`)                                     |
| `GET /device/time`        | `{ time, date, timezone, tz_region, continent, dst_status }`                                                       |
| `GET /device/speedtest`   | Last speed test result `{ down_speed, up_speed, last_speed_test_time, ever_tested, status }` — does not run a test |
| `GET /cloud/device-info`  | `{ cloudUserName, role, model }` (TP-Link cloud binding)                                                           |
| `GET /cloud/login-status` | TP-Link ID login state (raw)                                                                                       |

---

## POST /reboot

Reboot Deco units. **Destructive — the whole network goes down for a few
minutes. Always confirm with the user first.**

| Field   | Type     | Required | Description                                                              |
| ------- | -------- | -------- | ------------------------------------------------------------------------ |
| confirm | boolean  | yes      | Must be `true`; `false` → 400, missing → 422                             |
| macs    | string[] | no       | Specific node MACs (from `GET /devices`); omit = all units (404 if none) |

Response: `{ "rebooting": ["AA-BB-CC-DD-EE-FF", ...] }`

---

## POST /raw

Generic passthrough to any Deco endpoint. Returns the full decrypted envelope
(`result`/`error_code` or `success`/`data`) unmodified.

| Field     | Type   | Required | Description                                                                                                              |
| --------- | ------ | -------- | ------------------------------------------------------------------------------------------------------------------------ |
| path      | string | yes      | Relative path like `admin/<module>?form=<form>` (letters/digits/underscore, single `?form=`; no scheme, no `..`)         |
| operation | enum   | no       | `read` (default) / `write` / `load` / `list` / `get` / `set` / `add` / `edit` / `remove` / `operate` / `check` / `build` |
| params    | object | no       | Extra params passed through to the router                                                                                |

**Non-`read` operations can change arbitrary router settings — confirm with
the user and prefer the typed endpoints above when one exists.** The
`reboot` operation used by `POST /reboot` is deliberately not in the enum.

Paths used internally by the typed endpoints (useful starting points):

| Path                                                                                                                                                | Operation    | Backs                                                         |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ------------------------------------------------------------- |
| `admin/device?form=device_list`                                                                                                                     | read         | `/devices`                                                    |
| `admin/client?form=client_list` (`params: {"device_mac": "default"}`)                                                                               | read         | `/clients`                                                    |
| `admin/client?form=black_list`                                                                                                                      | list         | `/clients/blocked`                                            |
| `admin/network?form=wan_ipv4` / `internet` / `performance` / `mac_clone` / `wan_mode` / `dhcp_dial` / `igmp_setting` / `fast_xmit_setting` / `vlan` | read         | `/network/*`                                                  |
| `admin/network?form=lan_ip` / `ipv6` (`params: {"device_mac": "default"}`)                                                                          | read         | `/network/lan`, `/network/ipv6`                               |
| `admin/cloud?form=ddns`                                                                                                                             | get          | `/network/ddns`                                               |
| `admin/wireless?form=wlan`                                                                                                                          | read / write | `/wireless`, `/wireless/config`                               |
| `admin/wireless?form=power` / `beamforming` / `operation_mode` / `bridge` / `ieee80211r` / `bandwidth_enhance`                                      | read         | `/wireless/*`                                                 |
| `admin/device?form=mode` / `timesetting` / `speedtest`                                                                                              | read         | `/device/*`                                                   |
| `admin/cloud_account?form=get_deviceInfo` / `check_login`                                                                                           | read         | `/cloud/device-info`, `/cloud/login-status`                   |
| `admin/web?form=extra_component_info`                                                                                                               | get          | `/system/component-info`                                      |
| `admin/component_control?form=switch_list`                                                                                                          | read         | `/system/switch-list`                                         |
| `admin/log_export?form=types`                                                                                                                       | read         | `/system/log-types`                                           |
| `admin/log_export?form=feedback_log`                                                                                                                | build → read | `/system/log` (`params: {"level"}` then `{"index", "limit"}`) |
| `admin/cloud?form=firmware_status`                                                                                                                  | check        | `/system/firmware`                                            |
