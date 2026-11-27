# Deco BE85 API Reference

Base URL: `https://deco-api.msageha.net/api`
FastAPI wrapper (deco-be85-api) around the TP-Link Deco BE85 (FW 1.3.0) local
APIs. `https://deco.msageha.net` is the router's own web UI (proxied to the
Deco at `172.16.1.1`), not this API. Requests to this instance don't need any
authentication header/cookie; the server logs into the router itself. The
reverse proxy admits only allowlisted LAN client IPs and rejects requests whose
`Origin` header names another site (`403` otherwise). Interactive docs:
`https://deco-api.msageha.net/docs`.

This file holds what the OpenAPI document doesn't say: how the server reaches
the router, errors, units and meanings the schemas leave out, the shape of raw
router responses, and the multi-step procedures. Read field-level schemas from
the OpenAPI document.

## Request / response schemas

`https://deco-api.msageha.net/openapi.json` (generated from the server code,
same access rules as the API; about 500 KB) has every endpoint's parameters,
request fields, enums and response models, with descriptions in Japanese. Look
up one operation instead of reading the whole document:

```bash
# List operations (the luci / app ones are in commands.md). Paths in the document
# start with /api, the Base URL's path
curl -sf "https://deco-api.msageha.net/openapi.json" | jq -er '.paths | to_entries[]
  | select(.key | test("^/api/(luci|app)/") | not)
  | .key as $p | .value | to_entries[] | "\(.key | ascii_upcase) \($p)  \(.value.summary // "")"'

# One operation with its $refs inlined (<skill-dir>: the directory of this skill's SKILL.md)
curl -sf "https://deco-api.msageha.net/openapi.json" | jq -e -f "<skill-dir>/scripts/openapi-operation.jq" --arg method post --arg path /api/wireless/config
```

Most `GET` endpoints return the decrypted router response as-is (untyped in
the OpenAPI document; fields can vary by firmware). Model-backed responses
(`/devices`, `/clients`, `/network/performance`, `/network/mac-clone`,
`/wireless/power`, `/device/*`, `/cloud/device-info`, `/system/firmware`, and
the `decos` items of `/dashboard`) have the documented fields, all nullable,
and keep unknown router fields. `/dashboard` itself is an aggregate with
exactly its documented fields (`internet_online`, `deco_count`,
`online_clients` and `decos` always set): a field missing there may still be
in the full router response (`/network/wan`, `/devices`, …).

Responses the document leaves untyped (besides the raw router ones):
`POST /reboot` → `{"rebooting": [<MAC>, ...]}`; `POST /wireless` →
`{"updated": {"<band>": {"<network>": {"enable": ...}}}}`; `POST /login` /
`POST /logout` → `{"logged_in": <bool>}`; `GET /system/log` →
`{"totalNum": <pages at this limit>, "currentIndex": <index>, "logList": [{"content": "..."}]}`.

Units and meanings the schemas don't state:

- `/clients` `down_speed` / `up_speed`: current traffic in kbps, not the link
  speed. `/device/speedtest` speeds are kbps too; `last_speed_test_time` is
  Unix seconds.
- `cpu_usage` / `mem_usage`: 0..1 ratio.
- `/system/firmware`: a node whose `need_to_upgrade` or `software_ver` is
  `null` is unknown, not up to date.
- `/devices` `nickname` / `custom_nickname` and `/clients` `name` are decoded
  to plain text by the server; `/raw` returns them base64-encoded.
- `GET /network/wan`: `wan.dial_type` (connection type), `wan.ip_info.ip`
  (public IPv4), plus gateway / DNS fields.

## How the server reaches the router

Two paths, each with its own session and its own server-side lock (requests on
one path queue up):

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

`GET /health` reports both without touching the router: `logged_in` (luci) and
`tmp_connected`; `false` just means the next call logs in.

## Errors

| Status | Meaning                                                                                                                                                                  |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 400    | `confirm: false` on `POST /reboot` or a destructive `/api/luci/...` / `/api/app/...` operation                                                                           |
| 401    | Router authentication failed (`DecoAuthError`). Once TMP rejects the email / password, every later TMP call returns 401 until the server restarts with fixed credentials |
| 403    | Reverse proxy rejected the caller's IP or a cross-site `Origin` (nginx HTML page, not JSON)                                                                              |
| 404    | `POST /reboot` without `macs` found no Deco units; guest toggle without `band` found no band                                                                             |
| 413    | `params` (or Wi-Fi settings) don't fit in one TMP packet (about 64 KiB)                                                                                                  |
| 422    | Request validation error (missing `confirm`, unknown `settings` field, invalid enum / `path`, …); `detail` says which field and why, without echoing the values sent     |
| 502    | Router returned an error or an invalid response — body has `detail` and router `error_code`                                                                              |
| 504    | Router unreachable on the LAN (`DecoConnectionError`), or the TMP port is closed after a write                                                                           |

## Wi-Fi

- `GET /wireless` returns `ssid` and `password` base64-encoded — decode `ssid`
  with `@base64d` (jq) when showing it. `password` is a secret: leave it
  encoded and out of the output unless the user explicitly asks for it. With
  an automatic channel it reports the channel in use, which may differ from
  what was written.
- Writes (`POST /wireless`, `POST /wireless/config`) go over TMP and briefly
  disconnect clients on that band — confirm first. `ssid` / `password` are
  sent in plain text (the server encodes them).
- Guest Wi-Fi is per band. `POST /wireless` with `network: guest` and `band`
  omitted or `null` toggles the guest on every band whose guest isn't
  `is_separate` in `/api/app/wireless/wlan/read` (2.4 and 5 GHz on the BE85).
  The 6 GHz guest (`is_separate: true`) is untouched even by `enable: false` —
  pass `band6` to change it. It is configured separately in the Deco app, and
  on this unit is unconfigured with `encryption_mode: owe` (no password), so
  enabling it can broadcast a passwordless guest SSID.
- In `POST /wireless/config`, `channel` / `channel_width` / `mode` apply to the
  whole band whatever `network` is. Current guest-only values
  (`host_isolation`, `access_duration`, `bandwidth_limit`) come from
  `POST /api/app/wireless/wlan/read`. `null` values in `settings` are dropped
  (they don't clear anything), so `settings` needs at least one non-null
  field, and so does `bandwidth_limit` (`{}` → 422). Only
  `updated.<band>.<network>.password` is masked in
  the response; show `updated` rather than the whole body (`result` is the raw
  router answer).

## POST /reboot

Destructive — rebooting all units takes the whole network down for a few
minutes; rebooting one drops its clients and the mesh links behind it. Always
confirm with the user first, naming the nodes. `macs` omitted, `null` or `[]`
reboots every node — never send an empty list meaning "none".

## POST /raw

Generic passthrough to any Deco luci endpoint — not limited to the catalogue
of `/api/luci/...`, so it can reach forms that return credentials; print only
the fields needed. It returns the full decrypted envelope (`result` /
`error_code` or `success` / `data`) unmodified: a router-side error comes back
as HTTP `200` with `success: false` or a non-zero `error_code`; an HTTP error
or invalid response from the called endpoint is `502`. Non-`read` operations
can change arbitrary router settings — confirm with the user and prefer a
typed endpoint when one exists. The `reboot` operation is deliberately not in
the enum.

Paths used internally by the typed endpoints (useful starting points):

| Path                                                                                                                                                | Operation    | Backs                                                         |
| --------------------------------------------------------------------------------------------------------------------------------------------------- | ------------ | ------------------------------------------------------------- |
| `admin/device?form=device_list`                                                                                                                     | read         | `/devices`                                                    |
| `admin/client?form=client_list` (`params: {"device_mac": "default"}`)                                                                               | read         | `/clients`                                                    |
| `admin/client?form=black_list`                                                                                                                      | list         | `/clients/blocked`                                            |
| `admin/network?form=wan_ipv4` / `internet` / `performance` / `mac_clone` / `wan_mode` / `dhcp_dial` / `igmp_setting` / `fast_xmit_setting` / `vlan` | read         | `/network/*`                                                  |
| `admin/network?form=lan_ip` / `ipv6` (`params: {"device_mac": "default"}`)                                                                          | read         | `/network/lan`, `/network/ipv6`                               |
| `admin/cloud?form=ddns`                                                                                                                             | get          | `/network/ddns`                                               |
| `admin/wireless?form=wlan`                                                                                                                          | read         | `GET /wireless` (writes go over TMP)                          |
| `admin/wireless?form=power` / `beamforming` / `operation_mode` / `bridge` / `ieee80211r` / `bandwidth_enhance`                                      | read         | `/wireless/*`                                                 |
| `admin/device?form=mode` / `timesetting` / `speedtest`                                                                                              | read         | `/device/*`                                                   |
| `admin/cloud_account?form=get_deviceInfo` / `check_login`                                                                                           | read         | `/cloud/device-info`, `/cloud/login-status`                   |
| `admin/web?form=extra_component_info`                                                                                                               | get          | `/system/component-info`                                      |
| `admin/component_control?form=switch_list`                                                                                                          | read         | `/system/switch-list`                                         |
| `admin/log_export?form=types`                                                                                                                       | read         | `/system/log-types`                                           |
| `admin/log_export?form=feedback_log`                                                                                                                | build → read | `/system/log` (`params: {"level"}` then `{"index", "limit"}`) |
| `admin/cloud?form=firmware_status`                                                                                                                  | check        | `/system/firmware`                                            |

## luci and Deco-app operations

`POST /api/luci/<module>/<form>/<operation>` calls luci
`admin/<module>?form=<form>` (`locale` has no `admin/`); `POST
/api/app/<controller>/<form>/<operation>` calls the TMP opcode the Deco app
uses. They cover the operations catalogued from the FW 1.3.0 image (154 luci
and 384 TMP); `/api/app/...` also covers features luci lacks (port forwarding,
DHCP leases, HomeShield, QoS, Wi-Fi schedules, VPN, LEDs, …). Each entry in the
OpenAPI document carries `x-deco-luci-path` or `x-deco-tmp-opcode`,
`x-deco-operation` and `x-deco-destructive`.

- The body is `{"params": {...}}` (optional), sent to the router unvalidated:
  required fields differ per operation and firmware, and a rejected value is
  `502`. The `read` / `get` response of the same form shows the shape to write
  back. The response is the router's success body (`result` / `data`) as-is.
- Destructive operations (`x-deco-destructive: true`, 68 of them) also need
  `"confirm": true`: anything that cuts the Deco or the whole network off
  (reboot, factory reset, firmware upgrade, WAN disconnect, LAN / WAN / mesh /
  IPTV connection settings, port media, operation mode, main node, mesh
  group) or can't be undone (unbinding nodes or the cloud, admin account /
  TP-Link ID changes, clearing logs, history, reports, messages). Other writes
  — Wi-Fi, VPN, LEDs, reservations, port forwarding, blocking — run without
  `confirm`, so confirm with the user yourself.
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
