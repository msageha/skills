# Daikin MCK706A API Reference

Base URL: `https://daikin.msageha.net/api`
FastAPI wrapper (daikin-mck706a-api v0.1.0) around the Daikin MCK706A-W air
purifier's local `dsiot` API (`POST /dsiot/multireq` on the unit). Requests to
this instance don't need any authentication header/cookie; the reverse proxy
admits only allowlisted LAN client IPs (`403` otherwise). Interactive docs:
`https://daikin.msageha.net/docs`.

Property semantics come from the official DAIKIN Smart App's air-purifier
definitions (`GPFCjConvertValue` / `strings.xml`) and were checked on the real
unit (FW `3_15_0`, `api_ver 2_2`):

| Confidence                         | Fields                                                                                                                                                   |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Verified by writing to the unit    | `power`, `humidify`, `course`, `fan_speed`, `humidity_setting`                                                                                           |
| Verified by reading                | `temperature_c`, `humidity_pct`                                                                                                                          |
| Official app definition, read-only | `pm25_level`, `dust_level`, `odor_level`, `water_supply_sign`, `filter_drying`, `deodorizing_filter_off_sign`, `streamer_maintenance_sign`, `error_code` |
| Unit unknown                       | `pm25_raw`, `dust_raw`, `odor_raw` (assumed source of the app's history graph)                                                                           |

## Errors

| Status | Meaning                                                                                                                                                                                     |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 403    | Reverse proxy rejected the caller's IP (nginx HTML page, not JSON)                                                                                                                          |
| 409    | Value not supported by the unit, or not selectable in the current state (`DaikinUnsupportedError`); nothing is written                                                                      |
| 422    | Request validation error (missing or `false` `confirm`, invalid dsiot address/hex, unknown enum value)                                                                                      |
| 502    | Unit returned an error or a value the server can't decode — body has `detail` and dsiot `rsc` (`200x` = success, `2004` on successful writes; `4000` bad parameter, `4041` no such address) |
| 504    | Unit unreachable on the LAN (`DaikinConnectionError`)                                                                                                                                       |

Requests are serialized behind a server-side lock; concurrent calls queue up.

---

## GET /health

Server status without touching the unit.

```json
{ "status": "ok", "host": "http://172.16.1.161" }
```

---

## GET /info

Device and adapter information (reads `edge.adp_i`, `edge.adp_d`, `edge.adp_r`,
`edge.dev_i`). All fields nullable.

| Field               | Type    | Description                                                                              |
| ------------------- | ------- | ---------------------------------------------------------------------------------------- |
| name                | string  | User-assigned device name                                                                |
| device_type         | string  | dsiot device type code (`1D` = air purifier, `RA` = room air conditioner)                |
| mac                 | string  | Wi-Fi adapter MAC address                                                                |
| firmware            | string  | Adapter firmware version, e.g. `3_15_0`                                                  |
| revision            | string  | Firmware revision                                                                        |
| region              | string  | Region code, e.g. `jp`                                                                   |
| ssid                | string  | SSID of the adapter's own setup access point (e.g. `DaikinAP12345`) — not the home Wi-Fi |
| wlan_ssid           | string  | SSID of the Wi-Fi network the adapter is connected to                                    |
| wlan_rssi_dbm       | integer | Signal strength of that connection in dBm, e.g. `-46`                                    |
| api_ver             | string  | dsiot API version, e.g. `2_2`                                                            |
| led                 | boolean | Status LED enabled                                                                       |
| timezone_offset_min | integer | Timezone offset from UTC in minutes, e.g. `540` (JST)                                    |

---

## GET /status

Operation state and sensors (reads `adr_0100.dgc_status`). All fields nullable.

```json
{
  "power": true,
  "humidify": false,
  "course": "smart",
  "fan_speed": "quiet",
  "humidity_setting": null,
  "temperature_c": 23.0,
  "humidity_pct": 73,
  "pm25_level": 0,
  "dust_level": 0,
  "odor_level": 0,
  "pm25_raw": 659,
  "dust_raw": 624,
  "odor_raw": 1018,
  "water_supply_sign": false,
  "filter_drying": false,
  "deodorizing_filter_off_sign": false,
  "streamer_maintenance_sign": false,
  "error_code": "00-00"
}
```

| Field                                | Type    | Description                                                                                                                                      |
| ------------------------------------ | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| power                                | boolean | Purifier running                                                                                                                                 |
| humidify                             | boolean | Operation changeover: `true` = humidify + purify, `false` = purify only                                                                          |
| course                               | enum    | Course selected on the current changeover side (values below)                                                                                    |
| fan_speed                            | enum    | Manual-course fan speed on the current changeover side; other courses ignore it                                                                  |
| humidity_setting                     | enum    | Humidity target of the humidify-side course; `null` when that course is `smart` / `moist` (automatic). Returned even while `humidify` is `false` |
| temperature_c                        | number  | Room temperature in °C (0.5 °C steps)                                                                                                            |
| humidity_pct                         | integer | Relative humidity in %                                                                                                                           |
| pm25_level / dust_level / odor_level | integer | `0` (clean / no odor) .. `5`                                                                                                                     |
| pm25_raw / dust_raw / odor_raw       | integer | Raw sensor values, unit unknown — relative readings only                                                                                         |
| water_supply_sign                    | boolean | Humidifier tank is empty                                                                                                                         |
| filter_drying                        | boolean | Humidifier filter drying run in progress                                                                                                         |
| deodorizing_filter_off_sign          | boolean | Deodorizing filter is detached                                                                                                                   |
| streamer_maintenance_sign            | boolean | Streamer unit needs cleaning                                                                                                                     |
| error_code                           | string  | Unit error code; `00-00` = normal                                                                                                                |

The unit keeps separate course / fan-speed settings for the purify side and the
humidify side; on the MCK706A a change on one side is mirrored to the other a
few seconds later. Right after `POST /course`, re-read `GET /status` before
relying on `humidity_setting`.

### Values

| Field            | Values (wire order)                                                                                                                  | MCK706A                                                                                                    |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| course           | `smart` `manual` `auto_fan` `econo` `pollen` `moist` `circulator` `laundry_dry` `night_laundry_dry` `water_deodorize` `internal_dry` | `smart` .. `circulator`; `moist` only while humidifying                                                    |
| fan_speed        | `quiet` `low` `standard` `high` `turbo`                                                                                              | all but `high`; only takes effect while `course` is `manual`                                               |
| humidity_setting | `off` `low` `standard` `high` `continuous`                                                                                           | `low` / `standard` / `high`; automatic (not settable) while the humidify-side course is `smart` or `moist` |

Before writing, the server checks the value against the bitmask the unit
advertises for the property (`md.mx`) and returns `409` when it isn't
supported.

### Underlying dsiot properties (under `adr_0100.dgc_status`)

| Field                                                           | Property path                                                                     | Encoding                                                                       |
| --------------------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| power                                                           | `e_1002/e_A002/p_01`                                                              | `00` / `01`                                                                    |
| humidify                                                        | `e_1002/e_3001/p_3F`                                                              | `00` purify, `01` dehumidify + purify (not on MCK706A), `02` humidify + purify |
| course                                                          | `e_1002/e_3007/p_01` (purify side) / `p_03` (humidify side)                       | 2 bytes LE; low byte = index into the value list, high byte `00`               |
| fan_speed                                                       | `e_1002/e_3007/p_04` (purify side) / `p_06` (humidify side)                       | 1 byte, index into the value list                                              |
| humidity_setting                                                | `e_1002/e_3007/p_12` .. `p_1C` (humidify side, one property per course, in order) | 1 byte, index into the value list                                              |
| temperature_c                                                   | `e_1002/e_A00B/p_01`                                                              | int16 LE, 0.5 °C units                                                         |
| humidity_pct                                                    | `e_1002/e_A00B/p_02`                                                              | %                                                                              |
| pm25_level / dust_level / odor_level                            | `e_1002/e_3007/p_1D` / `p_1E` / `p_1F`                                            | 0..5                                                                           |
| pm25_raw / dust_raw / odor_raw                                  | `e_1002/e_3007/p_26` / `p_27` / `p_28`                                            | 24 bit                                                                         |
| water_supply_sign / filter_drying / deodorizing_filter_off_sign | `e_1002/e_3007/p_20` / `p_29` / `p_3E`                                            | flag                                                                           |
| streamer_maintenance_sign                                       | `e_1002/e_3001/p_40`                                                              | flag                                                                           |
| error_code                                                      | `e_1002/e_A004/p_09`                                                              | ASCII                                                                          |

Properties without an official definition (parts of `e_3007/p_2B`..`p_3D`,
`e_205E`, `e_205F_*`) are not in `/status`; inspect them with `GET /tree`.

---

## POST /power

Turn the purifier on or off. No `confirm` needed.

| Field | Type    | Required | Description                |
| ----- | ------- | -------- | -------------------------- |
| on    | boolean | yes      | `true` = on, `false` = off |

Response: `{ "power": true }`

---

## POST /humidify

Operation changeover. No `confirm` needed.

| Field | Type    | Required | Description                                       |
| ----- | ------- | -------- | ------------------------------------------------- |
| on    | boolean | yes      | `true` = humidify + purify, `false` = purify only |

Response: `{ "humidify": true }`. `409` if the unit doesn't support humidifying.

---

## POST /course

Set the course on the current changeover side (`humidify` decides which side
is written). No `confirm` needed.

| Field  | Type | Required | Description                      |
| ------ | ---- | -------- | -------------------------------- |
| course | enum | yes      | One of the `course` values above |

Response: `{ "course": "pollen" }`. `409` when the course can't be selected
right now (e.g. `moist` while `humidify` is `false`, or a course the unit
doesn't have).

---

## POST /fan-speed

Set the manual fan speed on the current changeover side. It only affects the
airflow while `course` is `manual`. No `confirm` needed.

| Field     | Type | Required | Description                         |
| --------- | ---- | -------- | ----------------------------------- |
| fan_speed | enum | yes      | One of the `fan_speed` values above |

Response: `{ "fan_speed": "turbo" }`. `409` for an unsupported speed (`high`
on the MCK706A).

---

## POST /humidity-setting

Set the humidity target of the humidify-side course. Works even while
`humidify` is `false` (the value applies once humidifying starts). No
`confirm` needed.

| Field            | Type | Required | Description                                |
| ---------------- | ---- | -------- | ------------------------------------------ |
| humidity_setting | enum | yes      | One of the `humidity_setting` values above |

Response: `{ "humidity_setting": "standard" }`. `409` when the humidify-side
course is `smart` / `moist` (automatic) or the value isn't supported.

---

## GET /tree

Every decoded leaf of `adr_0100.dgc_status`, keyed by property path. Useful
for exploring/identifying unmapped sensors (poll repeatedly and watch which
fields change).

Each value is a `DecodedLeaf`:

| Field     | Type   | Description                                                                                                                                  |
| --------- | ------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| pv        | any    | Raw dsiot value (LE hex string, int, or string)                                                                                              |
| value     | any    | Best-effort decoded value (hex → int when type is `b`)                                                                                       |
| type      | string | `b` (hex binary) / `i` (int) / `s` (string)                                                                                                  |
| min / max | string | Bounds advertised by the device (hex). For enum-like properties `max` is a bitmask of supported values (bit n = value n), not an upper bound |
| ascii     | string | ASCII rendering of a hex `pv` that looks like text                                                                                           |

```json
{
  "e_1002/e_A002/p_01": {
    "pv": "01",
    "value": 1,
    "type": "b",
    "min": "00",
    "max": "01"
  },
  "...": {}
}
```

---

## POST /read

Raw read of arbitrary dsiot addresses. Read-only, safe.

| Field   | Type     | Required | Description                                                    |
| ------- | -------- | -------- | -------------------------------------------------------------- |
| targets | string[] | yes      | Non-empty; each must start with `/dsiot/` (no `..`, no scheme) |

Response: raw dsiot responses keyed by address (`fr`). Each has `rsc`
(`200x` = OK) and a property-node tree `pc` — nodes carry `pn` (name),
`pt` (`1` = container with `pch` children, else leaf), `pv` (leaf value),
`md` (encoding meta: `pt` = `b`/`i`/`s`, `mi`/`mx` = hex bounds or bitmask).

Known addresses (`/dsiot/edge` lists all of them in one read):

| Address                                             | Contents                                                               |
| --------------------------------------------------- | ---------------------------------------------------------------------- |
| `/dsiot/edge/adr_0100.dgc_status`                   | Control + sensors (backs `/status`, `/tree`, all setters)              |
| `/dsiot/edge.adp_i`                                 | Adapter info: firmware / MAC / setup-AP SSID / api_ver (backs `/info`) |
| `/dsiot/edge.adp_d`                                 | User settings: name / LED / timezone (backs `/info`)                   |
| `/dsiot/edge.adp_r`                                 | Wi-Fi connection state: connected SSID / RSSI (backs `/info`)          |
| `/dsiot/edge.dev_i`                                 | Device type (`1D` = air purifier) (backs `/info`)                      |
| `/dsiot/edge.adp_f`                                 | Firmware kind and auto-update flag                                     |
| `/dsiot/edge/adr_0100.scdl_t.info` / `.scdl_t.body` | Weekly schedule timer (JSON values)                                    |
| `/dsiot/edge/adr_0200.dgc_status`                   | Empty on this unit (outdoor-unit slot)                                 |

`adr_0100.history` and `adr_0100.i_power.*` answer `4041` on this unit.

---

## POST /write

Raw write to one dsiot property. **Destructive — can change arbitrary unit
settings. Confirm with the user first and prefer the purpose-built endpoints
(`/power`, `/humidify`, `/course`, `/fan-speed`, `/humidity-setting`) when
they cover the need.**

| Field       | Type     | Required | Description                                                             |
| ----------- | -------- | -------- | ----------------------------------------------------------------------- |
| to          | string   | yes      | dsiot container address, e.g. `/dsiot/edge/adr_0100.dgc_status`         |
| entity_path | string[] | yes      | Property name chain under the root, e.g. `["e_1002", "e_A002", "p_01"]` |
| pv          | string   | yes      | Little-endian hex value, even length, e.g. `"01"`                       |
| confirm     | `true`   | yes      | Must be literally `true`; missing or `false` is rejected with 422       |

Unknown body fields are rejected (`extra=forbid`). The unit itself accepts
values outside its supported set, so check `GET /tree` first: for enum-like
properties `max` is the bitmask of supported values. Writing an unsupported
value (e.g. `01` to the changeover property, or a course index ≥ 11) leaves
`GET /status` returning 502 until you restore a supported value with the
matching setter or another `/write`.

Response: `{ "written": { "to": ..., "entity_path": [...], "pv": ... }, "result": <dsiot response> }`
