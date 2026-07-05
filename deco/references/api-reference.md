# Deco BE85 API Reference

Base URL: `https://deco.msageha.net/api`
FastAPI wrapper (deco-be85-api v0.1.0) around the TP-Link Deco BE85 local web
API. Requests to this instance don't need any authentication header/cookie;
the server performs the router login itself (lazy on first call; auto re-login
+ 1 retry on session expiry). Interactive docs: `https://deco.msageha.net/docs`.

Router-shaped endpoints (`/network/*`, `/wireless` GET, `/system/*`, `/raw`)
return the decrypted router response as-is; field sets can vary by firmware.
Model-backed endpoints (`/dashboard`, `/devices`, `/clients`, …) have the
documented fields but also keep unknown router fields (`extra=allow`).

## Errors

| Status | Meaning |
|---|---|
| 400 / 422 | Request validation error (e.g. missing `confirm`, unknown `settings` field, invalid enum) |
| 401 | Router authentication failed (`DecoAuthError`) |
| 502 | Router returned an error — body has `detail` and router `error_code` |
| 504 | Router unreachable on the LAN (`DecoConnectionError`) |

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
`POST /login` → `{ "logged_in": true, "stok": "***" }`,
`POST /logout` → `{ "logged_in": false }`.

---

## Status

### GET /dashboard

Aggregated overview (device list + client list + performance + WAN).

| Field | Type | Description |
|-------|------|-------------|
| internet_online | boolean | WAN IPv4 address present |
| connection_type | string | WAN dial type (e.g. `dhcp`) |
| wan_ipv4 | string | Current WAN IPv4 address |
| cpu_usage / mem_usage | number | Usage of the main Deco unit |
| deco_count | integer | Number of mesh nodes |
| online_clients | integer | Currently online clients |
| decos | DecoNode[] | See `GET /devices` |

---

## Devices

### GET /devices

Deco units (mesh nodes). Response: `DecoNode[]`.

| Field | Type | Description |
|-------|------|-------------|
| mac | string | Node MAC address (used by `POST /reboot`) |
| role | string | `master` / `slave` |
| device_model | string | e.g. `BE85` |
| device_type / hardware_ver / software_ver | string | Model/firmware info |
| device_ip | string | Node LAN IP |
| nickname | string | Location name (server-side decoded to plain text) |
| online | boolean | Node online state |
| inet_status | string | Internet reachability of the node |

---

## Clients

### GET /clients

Connected client devices. Response: `ClientDevice[]`.

| Parameter | Type | Description |
|-----------|------|-------------|
| online_only | boolean | `true` = only currently online clients (default: false) |

| Field | Type | Description |
|-------|------|-------------|
| mac / ip | string | Client addresses |
| name | string | Client name (server-side decoded to plain text) |
| online | boolean | Online state |
| interface | string | Which Wi-Fi/LAN interface |
| connection_type / wire_type | string | e.g. `band5`, wired vs wireless |
| client_type | string | Device category reported by the router |
| down_speed / up_speed | integer | Current transfer speeds |
| access_host | boolean | Whether the client may access the router |

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

---

## Wireless

`band`: `band2_4` / `band5_1` / `band6`. `network`: `host` / `guest`.

### GET /wireless

Full Wi-Fi config, keyed by band with `host` / `guest` sub-objects
(enable, ssid, password, channel, channel_width, mode, …).
**`ssid` and `password` are base64-encoded** in this response — decode with
`@base64d` (jq) when showing them to the user.

### POST /wireless

Toggle one band's Wi-Fi ON/OFF. **Briefly disconnects clients — confirm first.**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| band | enum | yes | `band2_4` / `band5_1` / `band6` |
| network | enum | no | `host` (default) / `guest` |
| enable | boolean | yes | Target state |

Response: `{ "updated": { "<band>": { "<network>": { "enable": ... } } } }`

### POST /wireless/config

Change Wi-Fi settings for one band+network. Only provided fields are written.
**Briefly disconnects clients on that band — confirm first.**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| band | enum | yes | `band2_4` / `band5_1` / `band6` |
| network | enum | no | `host` (default) / `guest` |
| settings | object | yes | At least 1 field; unknown fields rejected |

`settings` fields (all optional): `enable` (bool), `ssid` (string, plain text —
server base64-encodes), `password` (string, plain text — server base64-encodes),
`enable_hide_ssid` (bool), `channel` (int), `channel_width` (string),
`mode` (string). Current values (and valid channel/width/mode options) come
from `GET /wireless`.

Response: `{ "updated": <echo with password masked>, "result": <router result> }`

### GET /wireless/power

Radio capabilities, e.g. `{ "support_dfs": true, ... }`.

---

## Device / Cloud / System info

| Endpoint | Response |
|---|---|
| `GET /device/mode` | `{ region, workmode, sysmode }` (region may be a dict like `{"device": "JP"}`) |
| `GET /device/time` | `{ time, date, timezone, tz_region, continent, dst_status }` |
| `GET /cloud/device-info` | `{ cloudUserName, role, model }` (TP-Link cloud binding) |
| `GET /system/component-info` | ERP / power-saving component info (raw) |
| `GET /system/switch-list` | UI feature switches (raw) |
| `GET /system/log-types` | Exportable log categories (raw) |

---

## POST /reboot

Reboot Deco units. **Destructive — the whole network goes down for a few
minutes. Always confirm with the user first.**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| confirm | boolean | yes | Must be `true`, otherwise 400 |
| macs | string[] | no | Specific node MACs (from `GET /devices`); omit = all units |

Response: `{ "rebooting": ["AA-BB-CC-DD-EE-FF", ...] }`

---

## POST /raw

Generic passthrough to any Deco endpoint. Returns the full decrypted envelope
(`result`/`error_code` or `success`/`data`) unmodified.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| path | string | yes | Relative path like `admin/<module>?form=<form>` (letters/digits/underscore, single `?form=`; no scheme, no `..`) |
| operation | enum | no | `read` (default) / `write` / `load` / `list` / `get` / `set` / `add` / `edit` / `remove` / `operate` |
| params | object | no | Extra params passed through to the router |

**Non-`read` operations can change arbitrary router settings — confirm with
the user and prefer the typed endpoints above when one exists.**

Paths used internally by the typed endpoints (useful starting points):

| Path | Operation | Backs |
|---|---|---|
| `admin/device?form=device_list` | read | `/devices` |
| `admin/client?form=client_list` (`params: {"device_mac": "default"}`) | read | `/clients` |
| `admin/client?form=black_list` | list | `/clients/blocked` |
| `admin/network?form=wan_ipv4` / `internet` / `lan_ip` / `ipv6` / `performance` / `mac_clone` | read | `/network/*` |
| `admin/wireless?form=wlan` | read / write | `/wireless` |
| `admin/wireless?form=power` | read | `/wireless/power` |
| `admin/device?form=mode` / `timesetting` | read | `/device/*` |
| `admin/cloud_account?form=get_deviceInfo` | read | `/cloud/device-info` |
| `admin/web?form=extra_component_info` | get | `/system/component-info` |
| `admin/component_control?form=switch_list` | read | `/system/switch-list` |
| `admin/log_export?form=types` | read | `/system/log-types` |
| `admin/device?form=system` | operate | `/reboot` |
