# Daikin MCK706A API Reference

Base URL: `https://daikin.msageha.net/api`
FastAPI wrapper (daikin-mck706a-api v0.1.0) around the Daikin MCK706A-W air
purifier's local `dsiot` API (`POST /dsiot/multireq` on the unit). No
authentication toward this instance. Interactive docs:
`https://daikin.msageha.net/docs`.

Field semantics are reverse-engineered from the actual unit (FW `3_15_0`,
`api_ver 2_2`); Daikin does not document this protocol. Confidence levels:

| Confidence | Fields |
|---|---|
| Verified | `power`, `temperature_c`, `humidity_pct` |
| Range known, labels unconfirmed | `mode` (0..5), `fan_rate` (0..7) — exposed as raw integers |
| Unmapped units | `monitors.*` (PM2.5/dust/odor-like sensors) — decoded values only |

## Errors

| Status | Meaning |
|---|---|
| 400 / 422 | Request validation error (e.g. missing `confirm`, invalid dsiot address/hex) |
| 502 | Unit returned an error — body has `detail` and dsiot `rsc` code (`2000` = OK) |
| 504 | Unit unreachable on the LAN (`DaikinConnectionError`) |

Requests are serialized behind a server-side lock; concurrent calls queue up.

---

## GET /health

Server status without touching the unit.

```json
{ "status": "ok", "host": "http://192.168.1.100" }
```

---

## GET /info

Device information (reads `edge.adp_i` + `edge.adp_d`). All fields nullable.

| Field | Type | Description |
|-------|------|-------------|
| name | string | User-assigned device name |
| mac | string | Wi-Fi adapter MAC address |
| firmware | string | Adapter firmware version, e.g. `3_15_0` |
| revision | string | Firmware revision |
| region | string | Region / locale code |
| ssid | string | Connected Wi-Fi SSID |
| api_ver | string | dsiot API version, e.g. `2_2` |
| led | boolean | Status LED enabled |
| timezone_offset_min | integer | Timezone offset from UTC in minutes, e.g. `540` (JST) |

---

## GET /status

Air and operation state (reads `adr_0100.dgc_status`).

```json
{
  "power": true,
  "temperature_c": 24.0,
  "humidity_pct": 65,
  "mode": 2,
  "fan_rate": 2,
  "monitors": { "monitor_a": 252, "monitor_b": 130, "pm_a": 660, "pm_b": 660 }
}
```

| Field | Type | Description |
|-------|------|-------------|
| power | boolean | Purifier on/off |
| temperature_c | number | Room temperature in °C (int16 LE, half-degree units) |
| humidity_pct | integer | Relative humidity % (0–100) |
| mode | integer | Operation mode, raw 0..5 (labels unconfirmed) |
| fan_rate | integer | Airflow level, raw 0..7 (labels unconfirmed) |
| monitors | object | Air-quality sensor readings; keys `monitor_a`, `monitor_b`, `pm_a`, `pm_b`; units not yet mapped — treat as relative values |

Underlying dsiot properties (usable with `/write` at your own risk):

| Field | Property path (under `adr_0100.dgc_status`) |
|---|---|
| power | `e_1002/e_A002/p_01` |
| temperature_c | `e_1002/e_A00B/p_01` |
| humidity_pct | `e_1002/e_A00B/p_02` |
| mode | `e_1002/e_3001/p_3F` |
| fan_rate | `e_1002/e_3007/p_32` |
| monitor_a / monitor_b | `e_1002/e_3007/p_3A` / `p_3B` |
| pm_a / pm_b | `e_1002/e_205E/p_01` / `p_02` |

---

## POST /power

Turn the purifier on or off (writes `01`/`00` to the power property).

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| on | boolean | yes | `true` = on, `false` = off |

Response: `{ "power": true }`

---

## GET /tree

Every decoded leaf of `adr_0100.dgc_status`, keyed by property path. Useful
for exploring/identifying unmapped sensors (poll repeatedly and watch which
fields change).

Each value is a `LeafValue`:

| Field | Type | Description |
|-------|------|-------------|
| pv | any | Raw dsiot value (LE hex string, int, or string) |
| value | any | Best-effort decoded value (hex → int when type is `b`) |
| type | string | `b` (hex binary) / `i` (int) / `s` (string) |
| min / max | string | Bounds advertised by the device (hex), when present |
| ascii | string | ASCII rendering of a hex `pv` that looks like text |

```json
{
  "e_1002/e_A002/p_01": { "pv": "01", "value": 1, "type": "b", "min": "00", "max": "01" },
  "...": {}
}
```

---

## POST /read

Raw read of arbitrary dsiot addresses. Read-only, safe.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| targets | string[] | yes | Non-empty; each must start with `/dsiot/` (no `..`, no scheme) |

Response: raw dsiot responses keyed by address (`fr`). Each has `rsc`
(2000 = OK) and a property-node tree `pc` — nodes carry `pn` (name),
`pt` (`1` = container with `pch` children, else leaf), `pv` (leaf value),
`md` (encoding meta: `pt` = `b`/`i`/`s`, `mi`/`mx` = hex bounds).

Known addresses:

| Address | Contents |
|---|---|
| `/dsiot/edge/adr_0100.dgc_status` | Control + sensors (backs `/status`, `/tree`, `/power`) |
| `/dsiot/edge/adr_0200.dgc_status` | Secondary status tree |
| `/dsiot/edge.adp_i` | Adapter info: firmware/MAC/SSID (backs `/info`) |
| `/dsiot/edge.adp_d` | Device settings: name/LED/timezone (backs `/info`) |

---

## POST /write

Raw write to one dsiot property. **Destructive — can change arbitrary unit
settings; property semantics are reverse-engineered. Confirm with the user
first and prefer `POST /power` when it covers the need.**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| to | string | yes | dsiot container address, e.g. `/dsiot/edge/adr_0100.dgc_status` |
| entity_path | string[] | yes | Property name chain under the root, e.g. `["e_1002", "e_A002", "p_01"]` |
| pv | string | yes | Little-endian hex value, even length, e.g. `"01"` |
| confirm | boolean | yes | Must be `true`, otherwise 400 |

Unknown body fields are rejected (`extra=forbid`). Respect the `min`/`max`
bounds shown by `GET /tree` for the target property.

Response: `{ "written": { "to": ..., "entity_path": [...], "pv": ... }, "result": <dsiot response> }`
