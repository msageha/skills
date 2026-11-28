# Daikin MCK706A API Reference

Base URL: `https://daikin.msageha.net/api`
FastAPI wrapper (daikin-mck706a-api) around the Daikin MCK706A-W air purifier's
local `dsiot` API (`POST /dsiot/multireq` on the unit). Requests to this
instance don't need any authentication header/cookie; the reverse proxy admits
only allowlisted LAN client IPs and rejects requests whose `Origin` header
names another site (`403` otherwise). Interactive docs:
`https://daikin.msageha.net/docs`.

This file holds what the OpenAPI document doesn't say: errors, the values the
MCK706A actually accepts, how the two operation sides interact, and the raw
dsiot layer. Read field-level schemas from the OpenAPI document.

## Request / response schemas

`https://daikin.msageha.net/openapi.json` (generated from the server code, same
access rules as the API) has every endpoint's fields, types, required flags,
enums and response models, with field descriptions in Japanese. Look up one
operation instead of reading the whole document:

```bash
# List operations. Paths in the document start with /api, the Base URL's path
curl -sf "https://daikin.msageha.net/openapi.json" | jq -er '.paths | to_entries[]
  | .key as $p | .value | to_entries[] | select(.value | type == "object") | "\(.key | ascii_upcase) \($p)  \(.value.summary // "")"'

# One operation with its $refs inlined (<skill-dir>: the directory of this skill's SKILL.md)
curl -sf "https://daikin.msageha.net/openapi.json" | jq -e -f "<skill-dir>/scripts/openapi-operation.jq" --arg method get --arg path /api/status
```

Every `/status` and `/info` field is nullable: a value the unit didn't return
is `null`.

## Errors

The OpenAPI document lists only `200` / `422`; the server also returns:

| Status | Meaning                                                                                                                                                                                     |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 403    | Reverse proxy rejected the caller's IP or a cross-site `Origin` (nginx HTML page, not JSON)                                                                                                 |
| 409    | Value not supported by the unit, or not selectable in the current state (`DaikinUnsupportedError`); nothing is written                                                                      |
| 422    | Request validation error (missing or `false` `confirm`, invalid dsiot address/hex, unknown enum value)                                                                                      |
| 502    | Unit returned an error or a value the server can't decode — body has `detail` and dsiot `rsc` (`200x` = success, `2004` on successful writes; `4000` bad parameter, `4041` no such address) |
| 504    | Unit unreachable on the LAN (`DaikinConnectionError`)                                                                                                                                       |

Requests are serialized behind a server-side lock; concurrent calls queue up.

The control endpoints echo the value set (`{"power": true}`,
`{"humidify": false}`, `{"course": "pollen"}`, `{"fan_speed": "turbo"}`,
`{"humidity_setting": "standard"}`); a 200 means the unit accepted the write.
`GET /health` returns `{"status": "ok", "host": <unit URL>}` without touching
the unit.

## Values the MCK706A accepts

The OpenAPI enums list every value the dsiot protocol defines (in wire order,
0-based); the MCK706A supports only part of them:

| Field            | MCK706A                                                                                                                    |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------- |
| course           | `smart` `manual` `auto_fan` `econo` `pollen` `moist` `circulator`; `moist` only while humidifying                          |
| fan_speed        | `quiet` `low` `standard` `turbo` (no `high`); only takes effect while `course` is `manual`                                 |
| humidity_setting | `low` `standard` `high`; automatic (not settable, `null` in `/status`) while the humidify-side course is `smart` / `moist` |

Before writing, the server checks the value against the bitmask the unit
advertises for the property (`md.mx`) and returns `409` when it isn't
supported. `POST /humidify` returns `409` if the unit can't humidify.

Semantics come from the official DAIKIN Smart App's air-purifier definitions
and were checked on the real unit (FW `3_15_0`, `api_ver 2_2`): `power`,
`humidify`, `course`, `fan_speed`, `humidity_setting` by writing,
`temperature_c` / `humidity_pct` by reading. The air-quality levels and
maintenance signs follow the app's definitions only; the `*_raw` sensor values
have no known unit.

## Purify side and humidify side

The unit keeps separate course / fan-speed settings for the purify side and the
humidify side; `humidify` decides which side `POST /course` and
`POST /fan-speed` write, and `/status` reports. On the MCK706A a change on one
side is mirrored to the other a few seconds later.

`POST /humidity-setting` writes to the humidify-side course, even while
`humidify` is `false` (it applies once humidifying starts). After changing the
course while purifying only, wait until the humidify side has synced before
setting the humidity — otherwise it goes to the previous course or `409`.
`/status` can't show this while purifying only (`course` is then the purify
side); read `e_1002/e_3007/p_03` in `GET /tree` (its `value` is the course
index in wire order).

## Raw dsiot layer (`/tree`, `/read`, `/write`)

### Properties under `adr_0100.dgc_status`

`GET /tree` returns every decoded leaf of this container, keyed by these paths.
For enum-like properties `max` is a bitmask of supported values (bit n =
value n), not an upper bound.

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
`e_205E`, `e_205F_*`) are not in `/status`; inspect them with `GET /tree`
(poll it repeatedly and watch which values change).

### POST /read

Read-only. Each target must start with `/dsiot/` and contain no `..` or
`://`. The response (untyped in the OpenAPI document) is the raw dsiot
responses keyed by address (`fr`). Each has `rsc` (`200x` = OK; errors such as
`4041` come back inside the HTTP 200, so check each) and a property-node tree
`pc` — nodes carry `pn` (name), `pt` (`1` = container with `pch` children,
else leaf), `pv` (leaf value), `md` (encoding meta: `pt` = `b`/`i`/`s`,
`mi`/`mx` = hex bounds or bitmask).

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

### POST /write

Raw write to one dsiot property; `to` is a container address: same rules as
`/read`, and its last segment must contain a `.` (e.g.
`/dsiot/edge/adr_0100.dgc_status`; `/dsiot/edge` → 422). The response is `{"written": {to, entity_path, pv}, "result": <dsiot
response>}` — `written` echoes the request, `result` is the unit's answer.
Destructive — can change arbitrary unit
settings. Confirm with the user first and prefer the purpose-built endpoints
(`/power`, `/humidify`, `/course`, `/fan-speed`, `/humidity-setting`) when
they cover the need. `confirm` must be the JSON `true` (`1` or `"true"` →
422).

The unit stores values outside its supported set as-is. Before writing, read
the property — `GET /tree` for `dgc_status` (`min` / `max`),
`POST /read` for other containers (`md.mi` / `md.mx`) — note its current
value, and write only a supported value: within the bounds for a numeric
property; for an enum-like one, a value n whose bit is set in `max` /
`md.mx` (a bitmask, not an upper bound).
Read back afterwards. To find out what a property does, read it (`/tree`, `/read`) instead of writing to it. A value
`/status` can't decode (e.g. `01` to the changeover property, or a course
index ≥ 11) leaves `GET /status` returning 502 until a supported value is
restored — with the setter that writes that property where one does
(`/humidify` for the changeover; `/course` / `/fan-speed` for the current
side), otherwise with another `/write` (e.g. the side not currently active).
