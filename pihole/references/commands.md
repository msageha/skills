# Pi-hole Command Recipes

Ready-to-run `curl` examples for the endpoints listed in
[api-reference.md](api-reference.md). Base URL: `https://pihole.msageha.net/api`.

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
# Disable for 60 seconds (auto re-enables)
curl -s -X POST "https://pihole.msageha.net/api/dns/blocking" \
  -H "Content-Type: application/json" \
  -d '{"blocking": false, "timer": 60}' | jq .

# Disable indefinitely
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

## Search Domain (check if blocked)

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
# Remove from exact allowlist / denylist
curl -s -X DELETE "https://pihole.msageha.net/api/domains/allow/exact/example.com"
curl -s -X DELETE "https://pihole.msageha.net/api/domains/deny/exact/example.com"

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
  cpu: .system.cpu,
  dns_port: .system.dns.port
}'

curl -s "https://pihole.msageha.net/api/info/version" | jq .
```

## Gravity / DNS Actions

```bash
# Update Gravity (blocklists) — streams output, may take a while
curl -s -X POST "https://pihole.msageha.net/api/action/gravity"

# Restart DNS
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
