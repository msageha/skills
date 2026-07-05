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

# Air-quality sensors (units unmapped — relative values)
curl -s "https://daikin.msageha.net/api/status" | jq '.monitors'
```

## Power ON/OFF (confirm with the user first)

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

## Device Info

```bash
curl -s "https://daikin.msageha.net/api/info" | jq .
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
```

## Raw dsiot Write (destructive — confirm with the user first)

Prefer `POST /power` when it covers the need. `pv` is a little-endian
even-length hex string; check `min`/`max` from `GET /tree` first.

```bash
# Equivalent of power off via raw write
curl -s -X POST "https://daikin.msageha.net/api/write" \
  -H "Content-Type: application/json" \
  -d '{"to": "/dsiot/edge/adr_0100.dgc_status",
       "entity_path": ["e_1002", "e_A002", "p_01"],
       "pv": "00", "confirm": true}' | jq .
```
