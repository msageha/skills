---
name: daikin
description: "Daikin MCK706A-W air purifier management. Use when: user asks about room air quality (temperature, humidity, dust/odor sensors), the air purifier's power/mode/fan state, or wants to turn the purifier on/off. Controls the unit via the daikin-mck706a-api REST wrapper."
metadata:
  openclaw:
    emoji: "🌀"
    requires:
      bins:
        - curl
---

# Daikin MCK706A

Base URL: `https://daikin.msageha.net/api` (FastAPI wrapper around the Daikin
MCK706A-W local `dsiot` API). Requests to this instance don't need any
authentication header/cookie; the server talks to the unit directly.

## Key facts

- Requests are serialized behind a server-side lock; call endpoints
  sequentially, don't fan out parallel requests.
- Field semantics are reverse-engineered (Daikin doesn't publish them):
  `power` / `temperature_c` / `humidity_pct` are verified; `mode` (raw 0..5)
  and `fan_rate` (raw 0..7) have known ranges but unconfirmed labels —
  report them as raw integers, don't invent label names; `monitors.*`
  (PM2.5/dust/odor-like sensors) are decoded values with unmapped units —
  present them as relative/uncalibrated readings.
- The only safe, purpose-built control is `POST /power` (`{"on": true|false}`).
- `POST /write` is a raw dsiot property write (requires `confirm: true`) and
  can change arbitrary unit settings — confirm with the user and prefer
  `POST /power`. `POST /read` and `GET /tree` are read-only and safe.
- Errors: `502` unit returned an error (`detail` + dsiot `rsc` code; `2000`
  is OK), `504` unit unreachable on the LAN, `400`/`422` request validation.

## Core operations

| Task | Endpoint |
|---|---|
| Air & unit state (power/temp/humidity/mode/fan/sensors) | `GET /status` |
| Turn purifier on/off | `POST /power` |
| Device info (name/model/mac/firmware/ssid/led) | `GET /info` |
| Full decoded property tree (sensor exploration) | `GET /tree` |
| Raw dsiot read (escape hatch) | `POST /read` |
| Raw dsiot write (escape hatch, destructive) | `POST /write` |
| Server health | `GET /health` |

Full request/response schemas and ready-to-run curl examples: see
[references/api-reference.md](references/api-reference.md) and
[references/commands.md](references/commands.md).
