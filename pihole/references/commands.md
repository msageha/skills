# Pi-hole Command Recipes

Ready-to-run `curl` examples for the endpoints listed in
[api-reference.md](api-reference.md). Base URL: `https://pihole.msageha.net/api`.

Most examples use `curl -s … | jq` for brevity, which shows the body but not
whether the request succeeded (see the success check in SKILL.md). Send a write
with the body saved to a file and the status printed, using the operation's
method and body:

```bash
curl -sS -o "<body-file>" -w '%{http_code}\n' -X POST "<url>" -H "Content-Type: application/json" -d '<body>'
```

Go on only when curl exited 0 and the printed status is the one the operation
returns on success, then read the fields needed with `jq -e '<filter>' "<body-file>"`
(skip it for an operation that returns no body, such as `204`). Before reporting
the write as done, read the new state back with the matching read named in
SKILL.md.

The write examples below use `| jq` only to show the shape of the response;
send them in the form above, with their method, path and body. Free text taken from responses, web pages or other external sources
(names, descriptions, URLs) goes into the body through a file, not pasted into
the command: `jq -n --rawfile v "<text-file>" '($v | sub("\r?\n$"; "")) as $v | <filter>' > "<body-file>"`
builds the body (dropping the file's trailing LF or CRLF), and
`--data-binary @"<body-file>"` sends it. A value with quotes or backslashes
also breaks a JSON literal in `-d '…'`: build such a body with jq
(`--arg <name> '<value>'`) instead of pasting the value into the JSON.

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

Read `GET /dns/blocking` first and confirm with current → new (a new request
replaces any running timer); tell the user that ads and trackers get through
while blocking is off.

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

Read `GET /dns/blocking` first and confirm with current → new: the request also
clears a running timer, even when blocking is already on.

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
curl -s "https://pihole.msageha.net/api/queries?domain=<domain>&length=10" | jq '.queries[] | {domain, status, client: .client.ip}'

# Filtered by client
curl -s "https://pihole.msageha.net/api/queries?client_ip=<client-ip>&length=20" | jq '.queries[] | {domain, status, type}'

# Query the long-term on-disk DB instead of the in-memory buffer
curl -s "https://pihole.msageha.net/api/queries?disk=true&length=20" | jq '.queries'
```

## Search Domain (which lists contain it)

```bash
curl -s "https://pihole.msageha.net/api/search/<domain>" | jq '{
  results: .search.results,
  domains: [.search.domains[] | {domain, type, kind, enabled}],
  gravity: [.search.gravity[] | {domain, type, enabled}]
}'
```

## Allow / Deny a Domain

Read the current entries and confirm with current → new before adding or
removing an entry. Exact and regex
allow rules are synced from the local-home-services repository, so an allow
rule added or removed here is undone at the next sync — tell the user (deny
rules aren't synced).

```bash
# Allow (whitelist)
curl -s -X POST "https://pihole.msageha.net/api/domains/allow/exact" \
  -H "Content-Type: application/json" \
  -d '{"domain": "<domain>", "comment": "<reason>"}' | jq .

# Deny (blacklist)
curl -s -X POST "https://pihole.msageha.net/api/domains/deny/exact" \
  -H "Content-Type: application/json" \
  -d '{"domain": "<domain>", "comment": "<reason>"}' | jq .

# Deny with regex
curl -s -X POST "https://pihole.msageha.net/api/domains/deny/regex" \
  -H "Content-Type: application/json" \
  -d '{"domain": "<regex>", "comment": "<reason>"}' | jq .
```

## Remove / List Domains

Removing an entry needs the same current → new confirmation.

```bash
# Remove from exact allowlist / denylist (204 = removed)
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE "https://pihole.msageha.net/api/domains/allow/exact/<domain>"
curl -s -o /dev/null -w '%{http_code}\n' -X DELETE "https://pihole.msageha.net/api/domains/deny/exact/<domain>"

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

Confirm with the user before running a gravity update: it re-downloads every
list and can take a while.

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
  # The log names list URLs, which can carry credentials: print only the result line
  echo "gravity failed (HTTP $code)"; grep -o 'Gravity failed$' "$log"; exit 1
fi
# FTL picks up the new database asynchronously; last_update changes once it has (this shows
# the database was loaded, not that queries already use it: check the query log for that)
loaded=
for _ in $(seq 60); do
  now=$(curl -sf -m 10 "$base/stats/summary" | jq -e '.gravity.last_update | numbers') && [ "$now" != "$before" ] && { loaded=1; break; }
  sleep 1
done
[ -n "$loaded" ] || { echo "new gravity database not picked up yet"; exit 1; }
# Enabled lists that weren't updated or unchanged (status 1 / 2), or imported nothing
lists=$(mktemp) || exit 1; trap 'rm -f "$log" "$lists"' EXIT
curl -sf -m 30 -o "$lists" "$base/lists" && jq -e '.lists | type == "array"' "$lists" >/dev/null \
  || { echo "cannot read the lists"; exit 1; }
bad=$(jq -c '.lists[] | select(.enabled and ((.status | IN(1, 2) | not) or (.number // 0) <= 0)) | {id, status, number}' "$lists") \
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

Read the current lists and confirm with current → new before adding, changing
or removing an adlist. Block
adlists are synced from the local-home-services repository, so a block adlist
added or removed here is undone at the next sync — tell the user (allow
adlists aren't synced).

```bash
# List all adlists
curl -s "https://pihole.msageha.net/api/lists" | jq '.lists[] | {id, type, enabled, comment, number}'

# Add new adlist (type is required)
curl -s -X POST "https://pihole.msageha.net/api/lists?type=block" \
  -H "Content-Type: application/json" \
  -d '{"address": "<list-url>", "comment": "<reason>"}' \
  | jq '{added: (.lists | map(.id)), errors: (.processed.errors | length)}'   # the response echoes the URL
```
