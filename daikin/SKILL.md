---
name: daikin
description: "Daikin MCK706A-W humidifying air purifier management. Use when: user asks about room air quality (temperature, humidity, PM2.5 / dust / odor levels), the purifier's power / humidify / course / fan speed / humidity setting, maintenance signs (water supply, filters), or wants to turn the purifier on/off or change its course. Controls the unit via the daikin-mck706a-api REST wrapper."
metadata:
  openclaw:
    emoji: "🌀"
    requires:
      bins:
        - curl
        - jq
---

# Daikin MCK706A

Base URL: `https://daikin.msageha.net/api` (FastAPI wrapper around the Daikin
MCK706A-W local `dsiot` API). Requests to this instance don't need any
authentication header/cookie; the server talks to the unit directly. The
reverse proxy only admits allowlisted LAN client IPs — a `403` with an nginx
HTML page means the caller isn't on that list, not an API error.

## Key facts

- Requests are serialized behind a server-side lock; call endpoints
  sequentially, don't fan out parallel requests.
- `course` / `fan_speed` / `humidity_setting` are named values taken from the
  official DAIKIN Smart App definitions and verified by writing to the real
  unit — report them by name. `pm25_level` / `dust_level` / `odor_level` are
  `0` (clean) .. `5`; the `*_raw` sensor values have no known unit — present
  them as relative readings.
- Purpose-built controls that don't need user confirmation: `POST /power`
  (`{"on": bool}`), `POST /humidify` (`{"on": bool}` — `true` humidify +
  purify, `false` purify only), `POST /course` (`{"course": "<name>"}`),
  `POST /fan-speed` (`{"fan_speed": "<name>"}`, only takes effect while
  `course` is `manual`) and `POST /humidity-setting`
  (`{"humidity_setting": "<name>"}`, applies to the humidify-side course).
- A value the unit can't take right now returns `409` and nothing is written.
  MCK706A: courses `smart` `manual` `auto_fan` `econo` `pollen` `circulator`
  (`moist` only while humidifying); fan speeds `quiet` `low` `standard`
  `turbo` (no `high`); humidity settings `low` `standard` `high`, automatic
  (409) while the humidify-side course is `smart` or `moist`. When unsure,
  read `GET /status` first.
- `POST /write` is a raw dsiot property write (`confirm: true` required,
  otherwise 422) and can change arbitrary unit settings — confirm with the
  user and prefer the purpose-built endpoints. An out-of-range value written
  this way makes `GET /status` return 502 until the property is restored.
  `POST /read` and `GET /tree` are read-only and safe.
- Errors: `409` unsupported value / not selectable in the current state,
  `422` request validation (including a missing `confirm`), `502` unit
  returned an error or an undecodable value (`detail` + dsiot `rsc`; `200x`
  is success), `504` unit unreachable on the LAN.

## Core operations

| Task                                                                | Endpoint                 |
| ------------------------------------------------------------------- | ------------------------ |
| Air & unit state (power/humidify/course/fan/humidity/sensors/signs) | `GET /status`            |
| Turn purifier on/off                                                | `POST /power`            |
| Humidify + purify / purify only                                     | `POST /humidify`         |
| Change course (smart / manual / pollen / …)                         | `POST /course`           |
| Set manual fan speed (quiet … turbo)                                | `POST /fan-speed`        |
| Set humidity target (low / standard / high …)                       | `POST /humidity-setting` |
| Device info (name/device_type/mac/firmware/Wi-Fi SSID & RSSI/led)   | `GET /info`              |
| Full decoded property tree (sensor exploration)                     | `GET /tree`              |
| Raw dsiot read (escape hatch)                                       | `POST /read`             |
| Raw dsiot write (escape hatch, destructive)                         | `POST /write`            |
| Server health                                                       | `GET /health`            |

Full request/response schemas and ready-to-run curl examples: see
[references/api-reference.md](references/api-reference.md) and
[references/commands.md](references/commands.md).
