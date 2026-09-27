# Daikin MCK706A Command Recipes

Ready-to-run `curl` examples for the endpoints listed in
[api-reference.md](api-reference.md). Base URL: `https://daikin.msageha.net/api`.
Run requests sequentially — the server serializes them behind one unit session.

## Health

```bash
curl -s "https://daikin.msageha.net/api/health" | jq .
```

## Air / Operation Status

```bash
curl -s "https://daikin.msageha.net/api/status" | jq .

# Just the room environment
curl -s "https://daikin.msageha.net/api/status" | jq '{
  power, temperature_c, humidity_pct
}'

# Air-quality levels (0 = clean .. 5) and raw sensor values (unit unknown — relative only)
curl -s "https://daikin.msageha.net/api/status" | jq '{
  pm25_level, dust_level, odor_level, pm25_raw, dust_raw, odor_raw
}'

# Current operation settings
curl -s "https://daikin.msageha.net/api/status" | jq '{
  power, humidify, course, fan_speed, humidity_setting
}'

# Maintenance signs
curl -s "https://daikin.msageha.net/api/status" | jq '{
  water_supply_sign, filter_drying, deodorizing_filter_off_sign,
  streamer_maintenance_sign, error_code
}'
```

## Power ON/OFF (purpose-built, no confirmation needed)

```bash
# Turn on
curl -s -X POST "https://daikin.msageha.net/api/power" \
  -H "Content-Type: application/json" \
  -d '{"on": true}' | jq .

# Turn off
curl -s -X POST "https://daikin.msageha.net/api/power" \
  -H "Content-Type: application/json" \
  -d '{"on": false}' | jq .
```

## Humidify + purify / purify only (purpose-built, no confirmation needed)

```bash
# Humidify + purify
curl -s -X POST "https://daikin.msageha.net/api/humidify" \
  -H "Content-Type: application/json" \
  -d '{"on": true}' | jq .

# Purify only
curl -s -X POST "https://daikin.msageha.net/api/humidify" \
  -H "Content-Type: application/json" \
  -d '{"on": false}' | jq .
```

## Course (purpose-built, no confirmation needed)

Values: `smart` `manual` `auto_fan` `econo` `pollen` `moist` `circulator`
(MCK706A; `moist` only while humidifying). A course the unit can't select
right now returns 409 without writing anything.

```bash
# Pollen course
curl -s -X POST "https://daikin.msageha.net/api/course" \
  -H "Content-Type: application/json" \
  -d '{"course": "pollen"}' | jq .

# Manual course (needed for /fan-speed to take effect)
curl -s -X POST "https://daikin.msageha.net/api/course" \
  -H "Content-Type: application/json" \
  -d '{"course": "manual"}' | jq .
```

## Fan Speed (purpose-built, no confirmation needed)

Values: `quiet` `low` `standard` `turbo` (MCK706A has no `high`). Only affects
the airflow while `course` is `manual`.

```bash
curl -s -X POST "https://daikin.msageha.net/api/fan-speed" \
  -H "Content-Type: application/json" \
  -d '{"fan_speed": "turbo"}' | jq .
```

## Humidity Setting (purpose-built, no confirmation needed)

Values: `low` `standard` `high` (MCK706A). Applies to the humidify-side
course; 409 while that course is `smart` / `moist` (automatic).

```bash
curl -s -X POST "https://daikin.msageha.net/api/humidity-setting" \
  -H "Content-Type: application/json" \
  -d '{"humidity_setting": "standard"}' | jq .

# The two sides sync a few seconds after a course change — re-read before trusting humidity_setting
curl -s "https://daikin.msageha.net/api/status" | jq '{humidify, course, humidity_setting}'
```

## Device Info

```bash
curl -s "https://daikin.msageha.net/api/info" | jq .

# Connected Wi-Fi (wlan_ssid, not ssid — that one is the adapter's setup AP)
curl -s "https://daikin.msageha.net/api/info" | jq '{name, firmware, wlan_ssid, wlan_rssi_dbm}'
```

## Full Property Tree (sensor exploration)

```bash
curl -s "https://daikin.msageha.net/api/tree" | jq .

# Watch which properties change over time (identify unmapped sensors)
curl -s "https://daikin.msageha.net/api/tree" | jq 'with_entries(.value = .value.value)' > /tmp/tree1.json
sleep 30
curl -s "https://daikin.msageha.net/api/tree" | jq 'with_entries(.value = .value.value)' > /tmp/tree2.json
diff <(jq -S . /tmp/tree1.json) <(jq -S . /tmp/tree2.json)
```

## Raw dsiot Read (safe)

```bash
curl -s -X POST "https://daikin.msageha.net/api/read" \
  -H "Content-Type: application/json" \
  -d '{"targets": ["/dsiot/edge/adr_0100.dgc_status", "/dsiot/edge.adp_i"]}' | jq .

# List every address the unit exposes
curl -s -X POST "https://daikin.msageha.net/api/read" \
  -H "Content-Type: application/json" \
  -d '{"targets": ["/dsiot/edge"]}' | jq .
```

## Raw dsiot Write (destructive — confirm with the user first)

Prefer `/power`, `/humidify`, `/course`, `/fan-speed`, `/humidity-setting`
when they cover the need. `pv` is a little-endian even-length hex string.
Check the property in `GET /tree` first — for enum-like properties `max` is a
bitmask of supported values, and an unsupported value breaks `/status` (502)
until restored.

```bash
# Equivalent of power off via raw write
curl -s -X POST "https://daikin.msageha.net/api/write" \
  -H "Content-Type: application/json" \
  -d '{"to": "/dsiot/edge/adr_0100.dgc_status",
       "entity_path": ["e_1002", "e_A002", "p_01"],
       "pv": "00", "confirm": true}' | jq .
```
