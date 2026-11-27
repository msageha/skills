# Pi-hole Command Recipes

Ready-to-run `curl` examples for the endpoints listed in
[api-reference.md](api-reference.md). Base URL: `https://pihole.msageha.net/api`.

The examples pipe to `jq` for brevity, which hides failures: an error body run
through a field filter just shows `null`s, and the pipe exits 0. Before
trusting a filtered result, check the request: run with `set -o pipefail` and
`curl -sf`, or save the body with `-o <file>` and read the status from
`-w '%{http_code}'`.

## Status Summary

```bash
curl -s "https://pihole.msageha.net/api/stats/summary" | jq '{
  queries_total: .queries.total,
  queries_blocked: .queries.blocked,
  percent_blocked: .queries.percent_blocked,
  clients_active: .clients.active,
  gravity_domains: .gravity.domains_being_blocked
}'
```

## Blocking Status

```bash
curl -s "https://pihole.msageha.net/api/dns/blocking" | jq '{blocking, timer}'
```

## Disable Blocking (temporarily)

```bash
# Disable for 60 seconds (re-enables when the timer runs out — unless Pi-hole
# restarts meanwhile: the timer is lost and blocking stays off, so re-check later)
curl -s -X POST "https://pihole.msageha.net/api/dns/blocking" \
  -H "Content-Type: application/json" \
  -d '{"blocking": false, "timer": 60}' | jq .
```

Only when the user explicitly wants it off indefinitely (this also clears a
running timer):

```bash
curl -s -X POST "https://pihole.msageha.net/api/dns/blocking" \
  -H "Content-Type: application/json" \
  -d '{"blocking": false, "timer": null}' | jq .
```

## Enable Blocking

```bash
curl -s -X POST "https://pihole.msageha.net/api/dns/blocking" \
  -H "Content-Type: application/json" \
  -d '{"blocking": true, "timer": null}' | jq .
```

## Recent Blocked Domains

```bash
curl -s "https://pihole.msageha.net/api/stats/recent_blocked?count=10" | jq '.blocked'
```

## Top Blocked / Permitted Domains

```bash
curl -s "https://pihole.msageha.net/api/stats/top_domains?blocked=true&count=10" | jq '.domains'
curl -s "https://pihole.msageha.net/api/stats/top_domains?blocked=false&count=10" | jq '.domains'
```

## Top Clients

```bash
curl -s "https://pihole.msageha.net/api/stats/top_clients?count=10" | jq '.clients[] | {ip, name, count}'
```

## Query Log

```bash
# Recent queries
curl -s "https://pihole.msageha.net/api/queries?length=20" | jq '.queries[] | {domain, type, status, client: .client.ip, time}'

# Filtered by domain
curl -s "https://pihole.msageha.net/api/queries?domain=example.com&length=10" | jq '.queries[] | {domain, status, client: .client.ip}'

# Filtered by client
curl -s "https://pihole.msageha.net/api/queries?client_ip=192.168.1.100&length=20" | jq '.queries[] | {domain, status, type}'

# Query the long-term on-disk DB instead of the in-memory buffer
curl -s "https://pihole.msageha.net/api/queries?disk=true&length=20" | jq '.queries'
```

## Search Domain (which lists contain it)

```bash
curl -s "https://pihole.msageha.net/api/search/example.com" | jq '{
  results: .search.results,
  domains: [.search.domains[] | {domain, type, kind, enabled}],
  gravity: [.search.gravity[] | {domain, address, type}]
}'
```

## Allow / Deny a Domain

```bash
# Allow (whitelist)
curl -s -X POST "https://pihole.msageha.net/api/domains/allow/exact" \
  -H "Content-Type: application/json" \
  -d '{"domain": "example.com", "comment": "Allowed via Discord"}' | jq .

# Deny (blacklist)
curl -s -X POST "https://pihole.msageha.net/api/domains/deny/exact" \
  -H "Content-Type: application/json" \
  -d '{"domain": "example.com", "comment": "Blocked via Discord"}' | jq .

# Deny with regex
curl -s -X POST "https://pihole.msageha.net/api/domains/deny/regex" \
  -H "Content-Type: application/json" \
  -d '{"domain": "(.*)ads\\.example\\.com$", "comment": "Regex block via Discord"}' | jq .
```

## Remove / List Domains

```bash
# Remove from exact allowlist / denylist (204 = removed)
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE "https://pihole.msageha.net/api/domains/allow/exact/example.com"
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE "https://pihole.msageha.net/api/domains/deny/exact/example.com"

# List all domains (allow/deny)
curl -s "https://pihole.msageha.net/api/domains" | jq '.domains[] | {domain, type, kind, enabled, comment}'
```

## Network Devices / DHCP Leases

```bash
curl -s "https://pihole.msageha.net/api/network/devices?max_devices=20" | jq '.devices[] | {hwaddr, ip: .ips[0].ip, name: .ips[0].name, lastQuery}'

curl -s "https://pihole.msageha.net/api/dhcp/leases" | jq '.leases[] | {name, ip, hwaddr, expires}'
```

## System Info / Version

```bash
curl -s "https://pihole.msageha.net/api/info/system" | jq '{
  uptime: .system.uptime,
  memory: .system.memory,
  cpu: .system.cpu
}'

curl -s "https://pihole.msageha.net/api/info/version" | jq .
```

## Gravity / DNS Actions

```bash
# Update Gravity (blocklists) — streams output, may take a while
set -o pipefail
base=https://pihole.msageha.net/api
log=$(mktemp); trap 'rm -f "$log"' EXIT
before=$(curl -sf -m 10 "$base/stats/summary" | jq -e '.gravity.last_update | numbers') \
  || { echo "cannot read the current gravity state"; exit 1; }
# If the request itself fails (timeout, dropped connection), gravity may still be
# running on the server: the outcome is unknown, so check the lists later instead of rerunning
code=$(curl -sS -m 900 -o "$log" -w '%{http_code}' -X POST "$base/action/gravity") \
  || { echo "request failed; gravity result unknown"; exit 1; }
# 409 = another run in progress; a failure after streaming started still returns 200
if [ "$code" != 200 ] || tail -n 1 "$log" | grep -q 'Gravity failed$'; then
  echo "gravity failed (HTTP $code)"; tail -n 20 "$log"; exit 1
fi
# FTL picks up the new database asynchronously; last_update changes once it has
loaded=
for _ in $(seq 60); do
  now=$(curl -sf -m 10 "$base/stats/summary" | jq -e '.gravity.last_update | numbers') && [ "$now" != "$before" ] && { loaded=1; break; }
  sleep 1
done
[ -n "$loaded" ] || { echo "new gravity database not picked up yet"; exit 1; }
# Enabled lists that failed (status 3/4) or imported nothing
lists=$(curl -sf -m 30 "$base/lists") || { echo "cannot read the lists"; exit 1; }
bad=$(jq -c '.lists[] | select(.enabled and (.status >= 3 or .number == 0)) | {address, status, number}' <<<"$lists") \
  || { echo "unexpected /lists response"; exit 1; }
[ -z "$bad" ] || { echo "gravity ran, but these lists failed:"; echo "$bad"; exit 1; }
```

Restarting DNS interrupts name resolution for every client briefly and drops
a pending blocking timer (the scheduled switch then never happens) — confirm with the user
first, and re-check `GET /dns/blocking` afterwards.

```bash
curl -s -X POST "https://pihole.msageha.net/api/action/restartdns" | jq .
```

## Adlists

```bash
# List all adlists
curl -s "https://pihole.msageha.net/api/lists" | jq '.lists[] | {address, enabled, comment, number}'

# Add new adlist (type is required)
curl -s -X POST "https://pihole.msageha.net/api/lists?type=block" \
  -H "Content-Type: application/json" \
  -d '{"address": "https://example.com/blocklist.txt", "comment": "Added via Discord"}' | jq .
```
