# Daikin MCK706A Command Recipes

Ready-to-run `curl` examples for common tasks. For other endpoints and for
request/response schemas, see [api-reference.md](api-reference.md): how to look
them up in the server's OpenAPI document, and what the document leaves out. Base URL: `https://daikin.msageha.net/api`.
Run requests sequentially — the server serializes them behind one unit session.

The examples call curl with `-sSf` under `set -o pipefail`: a request that
fails (no connection, or an HTTP status of 400 or above) makes the command exit
non-zero with the error on stderr and no body, as the success check in SKILL.md
expects. Free text taken from responses, web pages or other external sources
(names, descriptions, URLs) goes into the body through a file, not pasted into
the command: `jq -n --rawfile v "<text-file>" '($v | sub("\r?\n$"; "")) as $v | <filter>' > "<body-file>"`
builds the body (dropping the file's trailing LF or CRLF), and
`--data-binary @"<body-file>"` sends it. Build a body whose value holds a quote
or backslash with jq (`--arg <name> '<value>'`) too, since it breaks a JSON
literal in `-d '…'`.

## Health

```bash
set -o pipefail
curl -sSf "https://daikin.msageha.net/api/health" | jq .
```

## Air / Operation Status

```bash
set -o pipefail
curl -sSf "https://daikin.msageha.net/api/status" | jq .

# Just the room environment
curl -sSf "https://daikin.msageha.net/api/status" | jq '{
  power, temperature_c, humidity_pct
}'

# Air-quality levels (0 = clean .. 5) and raw sensor values (unit unknown — relative only)
curl -sSf "https://daikin.msageha.net/api/status" | jq '{
  pm25_level, dust_level, odor_level, pm25_raw, dust_raw, odor_raw
}'

# Current operation settings
curl -sSf "https://daikin.msageha.net/api/status" | jq '{
  power, humidify, course, fan_speed, humidity_setting
}'

# Maintenance signs
curl -sSf "https://daikin.msageha.net/api/status" | jq '{
  water_supply_sign, filter_drying, deodorizing_filter_off_sign,
  streamer_maintenance_sign, error_code
}'
```

## Power ON/OFF (purpose-built; when asked, no further confirmation)

```bash
set -o pipefail
# Turn on
curl -sSf -X POST "https://daikin.msageha.net/api/power" \
  -H "Content-Type: application/json" \
  -d '{"on": true}' | jq .

# Turn off
curl -sSf -X POST "https://daikin.msageha.net/api/power" \
  -H "Content-Type: application/json" \
  -d '{"on": false}' | jq .
```

## Humidify + purify / purify only (purpose-built; when asked, no further confirmation)

```bash
set -o pipefail
# Humidify + purify
curl -sSf -X POST "https://daikin.msageha.net/api/humidify" \
  -H "Content-Type: application/json" \
  -d '{"on": true}' | jq .

# Purify only
curl -sSf -X POST "https://daikin.msageha.net/api/humidify" \
  -H "Content-Type: application/json" \
  -d '{"on": false}' | jq .
```

## Course (purpose-built; when asked, no further confirmation)

Values: `smart` `manual` `auto_fan` `econo` `pollen` `moist` `circulator`
(MCK706A; `moist` only while humidifying). A course the unit can't select
right now returns 409 without writing anything.

```bash
set -o pipefail
# Pollen course
curl -sSf -X POST "https://daikin.msageha.net/api/course" \
  -H "Content-Type: application/json" \
  -d '{"course": "pollen"}' | jq .

# Manual course (needed for /fan-speed to take effect)
curl -sSf -X POST "https://daikin.msageha.net/api/course" \
  -H "Content-Type: application/json" \
  -d '{"course": "manual"}' | jq .
```

## Fan Speed (purpose-built; when asked, no further confirmation)

Values: `quiet` `low` `standard` `turbo` (MCK706A has no `high`). Only affects
the airflow while `course` is `manual`.

```bash
set -o pipefail
curl -sSf -X POST "https://daikin.msageha.net/api/fan-speed" \
  -H "Content-Type: application/json" \
  -d '{"fan_speed": "turbo"}' | jq .
```

## Humidity Setting (purpose-built; when asked, no further confirmation)

Values: `low` `standard` `high` (MCK706A). Applies to the humidify-side
course; 409 while that course is `smart` / `moist` (automatic).

Right after `POST /course` while purifying only (`humidify: false`), first
wait until the humidify-side course has synced — `/status.course` shows the
purify side then. Read `e_1002/e_3007/p_03`; its `value` is the course index
in wire order (`smart` 0, `manual` 1, `auto_fan` 2, `econo` 3, `pollen` 4,
`moist` 5, `circulator` 6). Set the humidity only once it matches the new
course; if it can't be read, don't set it.

```bash
set -o pipefail
# 2 = auto_fan here; use the index of the course just set
synced=
for _ in $(seq 10); do
  curl -sSf -m 10 "https://daikin.msageha.net/api/tree" | jq -e '."e_1002/e_3007/p_03".value == 2' >/dev/null \
    && { synced=1; break; }
  sleep 1
done
[ -n "$synced" ] || { echo "humidify-side course not synced after 10 tries"; exit 1; }
curl -sSf -X POST "https://daikin.msageha.net/api/humidity-setting" \
  -H "Content-Type: application/json" \
  -d '{"humidity_setting": "standard"}' | jq .
```

## Device Info

```bash
set -o pipefail
curl -sSf "https://daikin.msageha.net/api/info" | jq .

# Connected Wi-Fi (wlan_ssid, not ssid — that one is the adapter's setup AP)
curl -sSf "https://daikin.msageha.net/api/info" | jq '{name, firmware, wlan_ssid, wlan_rssi_dbm}'
```

## Full Property Tree (sensor exploration)

```bash
set -o pipefail
curl -sSf "https://daikin.msageha.net/api/tree" | jq .

# Watch which properties change over time (identify unmapped sensors)
d=$(mktemp -d) || exit 1; trap 'rm -f "$d"/tree1.json "$d"/tree2.json; rmdir "$d"' EXIT
curl -sSf "https://daikin.msageha.net/api/tree" | jq 'with_entries(.value = .value.value)' > "$d/tree1.json" || exit 1
sleep 30
curl -sSf "https://daikin.msageha.net/api/tree" | jq 'with_entries(.value = .value.value)' > "$d/tree2.json" || exit 1
diff <(jq -S . "$d/tree1.json") <(jq -S . "$d/tree2.json")
```

## Raw dsiot Read (safe)

```bash
set -o pipefail
curl -sSf -X POST "https://daikin.msageha.net/api/read" \
  -H "Content-Type: application/json" \
  -d '{"targets": ["/dsiot/edge/adr_0100.dgc_status", "/dsiot/edge.adp_i"]}' | jq .

# List every address the unit exposes
curl -sSf -X POST "https://daikin.msageha.net/api/read" \
  -H "Content-Type: application/json" \
  -d '{"targets": ["/dsiot/edge"]}' | jq .
```

## Raw dsiot Write (destructive — confirm with the user first)

Prefer `/power`, `/humidify`, `/course`, `/fan-speed`, `/humidity-setting`
when they cover the need. `pv` is a little-endian even-length hex string.
Read the property first (`GET /tree` for `dgc_status`, `POST /read` for other
containers — go on only if the target's `rsc` is `200x` and the property
exists) and note its `pv`; write only a supported value — within `min`..`max`
in `/tree` (`md.mi`..`md.mx` in `/read`) for a numeric property, and for an
enum-like one a value n whose bit is set in `max` / `md.mx`, which is then a
bitmask (bit n = value n), not an upper bound. An undecodable value breaks
`/status` with 502 until restored. Read back afterwards. Write only a change
the user asked for; explore unknown properties with reads.

```bash
set -o pipefail
# Before: note the current value; stop if the property can't be read
curl -sSf "https://daikin.msageha.net/api/tree" | jq -e '."e_1002/e_A002/p_01".pv | strings' \
  || { echo "property not found"; exit 1; }

# Equivalent of power off via raw write, then read back and compare with the value sent
code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST "https://daikin.msageha.net/api/write" \
  -H "Content-Type: application/json" \
  -d '{"to": "/dsiot/edge/adr_0100.dgc_status",
       "entity_path": ["e_1002", "e_A002", "p_01"],
       "pv": "00", "confirm": true}') && [ "$code" = 200 ] \
  || { echo "write failed (HTTP ${code:-none}) — re-read the property before retrying"; exit 1; }
curl -sSf "https://daikin.msageha.net/api/tree" | jq -e '."e_1002/e_A002/p_01".pv == "00"' >/dev/null \
  || { echo "read-back doesn't show the new value"; exit 1; }
```
