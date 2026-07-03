# Pi-hole API Reference

Base URL: `http://172.16.1.101:8100/api`
Pi-hole REST API v6 (FTL v6.6.2 / core v6.4.2 / web v6.5.1). No authentication
required on this instance (no password set).

Every response body includes a `took` field (request processing time in
seconds, float) not shown in the examples below.

---

## Authentication

Currently no password is set. All endpoints return data without a session.

If a password is configured in the future:

```bash
# Login
curl -s -X POST "http://172.16.1.101:8100/api/auth" \
  -H "Content-Type: application/json" \
  -d '{"password": "your-password"}' | jq '.session.sid'

# Use SID in subsequent requests via header, cookie, or query parameter
curl -s -H "sid: YOUR_SID" "http://172.16.1.101:8100/api/stats/summary"
curl -s "http://172.16.1.101:8100/api/stats/summary?sid=YOUR_SID"

# Logout
curl -s -X DELETE "http://172.16.1.101:8100/api/auth" -H "sid: YOUR_SID"
```

Session validity: 5 minutes by default, extended by each authenticated request.
`GET /auth/app` generates a long-lived "application password" (closest thing to
a persistent API key) instead of the interactive admin password. `GET /auth/totp`
issues a new 2FA secret. `GET /auth/sessions` / `DELETE /auth/session/{id}`
manage active sessions.

---

## Endpoints

### GET /auth

Check authentication status. No auth required.

**Response:**

```json
{
  "session": {
    "valid": true,
    "totp": false,
    "sid": null,
    "validity": -1,
    "message": "no password set"
  }
}
```

---

### GET /stats/summary

Overview of Pi-hole activity.

**Response:**

```json
{
  "queries": {
    "total": 65409,
    "blocked": 9037,
    "percent_blocked": 13.8,
    "unique_domains": 445,
    "forwarded": 4574,
    "cached": 9765,
    "frequency": 1.1,
    "types": { "A": 3643, "AAAA": 123, "...": "..." },
    "status": { "GRAVITY": 72, "FORWARDED": 533, "CACHE": 32, "...": "..." },
    "replies": { "IP": 84, "CNAME": 32, "NXDOMAIN": 533, "...": "..." }
  },
  "clients": { "active": 10, "total": 22 },
  "gravity": { "domains_being_blocked": 77527, "last_update": 1725194639 }
}
```

---

### GET /dns/blocking

Get current blocking status.

| Field | Type | Description |
|-------|------|-------------|
| blocking | string | `enabled` / `disabled` / `failed` / `unknown` |
| timer | number\|null | Remaining seconds until auto-change (null = permanent) |

### POST /dns/blocking

Change blocking status.

| Field | Type | Description |
|-------|------|-------------|
| blocking | boolean | `true` = enable (default), `false` = disable |
| timer | number\|null | Seconds until auto-reverse (null = permanent, or clears an active timer) |

---

### GET /stats/top_domains

| Parameter | Type | Description |
|-----------|------|-------------|
| blocked | boolean | `true` = blocked domains, `false` = permitted (default: false) |
| count | integer | Number of results (default: 10) |

**Response:** `{ "domains": [{ "domain": "example.com", "count": 8516 }], "total_queries": 29160, "blocked_queries": 6379 }`

---

### GET /stats/top_clients

| Parameter | Type | Description |
|-----------|------|-------------|
| blocked | boolean | `true` = by blocked queries, `false` = by total (default: false) |
| count | integer | Number of results (default: 10) |

**Response:** `{ "clients": [{ "ip": "192.168.0.44", "name": "raspberrypi.lan", "count": 5896 }], "total_queries": 29160, "blocked_queries": 6379 }`

---

### GET /stats/recent_blocked

| Parameter | Type | Description |
|-----------|------|-------------|
| count | integer | Number of results (default: 1) |

**Response:** `{ "blocked": ["doubleclick.net", "..."] }`

---

### GET /stats/upstreams / GET /stats/query_types

Upstream DNS destination metrics / DNS query type distribution. No required params.

---

### GET /queries

Recent DNS query log. All parameters optional.

| Parameter | Type | Description |
|-----------|------|-------------|
| length | integer | Number of results (default: 100) |
| start | integer | Pagination offset |
| from / until | number | Unix timestamp range |
| domain | string | Filter by domain (wildcards `*` supported) |
| client_ip | string | Filter by client IP (wildcards supported) |
| client_name | string | Filter by client hostname (wildcards supported) |
| upstream | string | Filter by upstream |
| type | string | Filter by query type (A, AAAA, etc.) |
| status | string | Filter by status (GRAVITY, FORWARDED, CACHE, etc.) |
| reply | string | Filter by reply type (NODATA, NXDOMAIN, etc.) |
| dnssec | string | Filter by DNSSEC status |
| disk | boolean | `true` = query the on-disk long-term DB instead of the in-memory buffer (default: false) |
| cursor | integer | Database ID for pagination |

**Response:**

```json
{
  "queries": [
    {
      "id": 12345,
      "time": 1709370000.0,
      "type": "A",
      "domain": "example.com",
      "status": "FORWARDED",
      "dnssec": "UNKNOWN",
      "client": { "ip": "192.168.1.100", "name": "my-pc" },
      "upstream": "1.1.1.1#53",
      "reply": { "type": "IP", "time": 0.025 },
      "list_id": -6,
      "ede": { "code": -1, "text": null },
      "cname": null
    }
  ],
  "cursor": 12300,
  "recordsTotal": 65409,
  "recordsFiltered": 65409,
  "draw": 0,
  "earliest_timestamp": 1709283800
}
```

- `list_id`: which adlist/gravity list caused a block (negative for special
  categories like gravity, positive for a specific list ID)
- `ede`: Extended DNS Error info (`code: -1` = none)
- `cname`: the CNAME record that led to this query being blocked, if any

Related: `GET /queries/suggestions` (autocomplete values for the filters above).

---

### GET /search/{domain}

Search domain in Pi-hole's lists and gravity.

| Parameter | Type | Description |
|-----------|------|-------------|
| domain | string | Domain to search (path, required) |
| partial | boolean | Partial matching (default: false) |
| N | integer | Max results per type (default: 20) |
| debug | boolean | Include debug info (default: false) |

**Response:**

```json
{
  "search": {
    "domains": [{ "domain": "ads.example.com", "type": "deny", "kind": "exact", "enabled": true, "groups": [0] }],
    "gravity": [{ "domain": "ads.example.com", "address": "https://blocklist-url...", "type": "block", "enabled": true }],
    "results": { "domains": { "exact": 1, "regex": 0 }, "gravity": { "allow": 0, "block": 1 }, "total": 2 }
  }
}
```

---

### Domain Management

#### GET /domains

List all domains. Optional path segments for filtering: `/domains`,
`/domains/allow`, `/domains/deny`, `/domains/allow/exact`, `/domains/deny/regex`.

**Response item:**

| Field | Type | Description |
|-------|------|-------------|
| domain | string | Domain or regex pattern |
| unicode | string | Unicode-decoded form of `domain` (relevant for punycode/IDN domains) |
| type | string | `allow` / `deny` |
| kind | string | `exact` / `regex` |
| enabled | boolean | Whether entry is active |
| comment | string | Optional comment |
| groups | integer[] | Associated group IDs |
| id | integer | Entry ID |
| date_added | integer | Unix timestamp |
| date_modified | integer | Unix timestamp |

#### POST /domains/{type}/{kind}

Add a domain. Both `{type}` (`allow`/`deny`) and `{kind}` (`exact`/`regex`) required.

| Field | Type | Required | Description |
|-------|------|----------|--------------|
| domain | string \| string[] | yes | One or more domains/patterns |
| comment | string\|null | no | Optional comment |
| groups | integer[] | no | Group IDs (default: `[0]`) |
| enabled | boolean | no | Whether the entry is active (default: `true`) |

#### PUT /domains/{type}/{kind}/{domain}

Full update of a domain entry; can move it between type/kind.

#### DELETE /domains/{type}/{kind}/{domain}

Remove a domain. Returns `204 No Content` on success.
Batch variant: `POST /domains:batchDelete` with body `[{item, type, kind}, ...]`.

---

### GET /network/devices

| Parameter | Type | Description |
|-----------|------|-------------|
| max_devices | integer | Max devices to return (default: 10) |
| max_addresses | integer | Max addresses per device (default: 3) |

**Response item:** the per-IP data lives under **`ips`**; there is no
per-device `name` field (only per-IP `name`, usually `null` unless reverse
DNS resolves it).

```json
{
  "devices": [
    {
      "id": 17,
      "hwaddr": "ip-172.16.1.111",
      "interface": "eth0",
      "firstSeen": 1783086336,
      "lastQuery": 1783116641,
      "numQueries": 5563,
      "macVendor": "",
      "ips": [
        { "ip": "172.16.1.111", "name": null, "lastSeen": 1783116660, "nameUpdated": 1783116660 }
      ]
    }
  ]
}
```

Related: `DELETE /network/devices/{device_id}`, `GET /network/gateway`,
`GET /network/routes`, `GET /network/interfaces` (all take an optional
`detailed` param).

---

### GET /dhcp/leases

Active DHCP leases.

**Response item:**

| Field | Type | Description |
|-------|------|--------------|
| name | string | Hostname |
| ip | string | IP address |
| hwaddr | string | MAC address |
| expires | integer | Expiry timestamp (0 = infinite) |
| clientid | string | Client ID |

`DELETE /dhcp/leases/{ip}` removes a lease.

---

### GET /lists

Adlists (blocklists/allowlists). `type` (`allow`/`block`) optional on GET
(omit for both).

**Response item:**

| Field | Type | Description |
|-------|------|--------------|
| address | string | List URL |
| enabled | boolean | Whether list is active |
| comment | string | Optional comment |
| type | string | `block` / `allow` |
| groups | integer[] | Associated group IDs (default: `[0]`) |
| number | integer | Number of entries |
| invalid_domains | integer | Count of malformed entries skipped on last update |
| abp_entries | integer | Count of Adblock Plus-style entries in the list |
| date_added / date_modified / date_updated | integer | Unix timestamps |
| status | integer | Download status (`1` = OK, `2` = OK with warnings, seen on this instance) |

#### POST /lists

**`type` (`allow`/`block`) is a required query parameter**, e.g.
`POST /lists?type=block`.

```json
{ "address": "https://example.com/blocklist.txt", "comment": "Added via API", "enabled": true }
```

#### PUT /lists/{list} / DELETE /lists/{list}

Update or remove an adlist. `type` is required on `DELETE` too.
`{list}` is the URL-encoded address. Batch variant: `POST /lists:batchDelete`.

---

### Actions

| Endpoint | Description |
|---|---|
| `POST /action/gravity` | Re-download all adlists. Response streamed as `text/plain`. |
| `POST /action/restartdns` | Restart the pihole-FTL DNS service. |
| `POST /action/flush/logs` | Flush DNS logs and purge last 24h from the DB. |
| `POST /action/flush/network` | Flush the network table (remove all known devices). Replaces the deprecated `flush/arp`. |

---

### System Information

`GET /info/system`, `/info/version`, `/info/host`, `/info/sensors`, `/info/ftl`,
`/info/client`, `/info/database`, `/info/metrics`, `/info/login`. Also
`/info/messages` (+ `/info/messages/{id}` DELETE, `/info/messages/count`) for
the alerts/diagnosis system, and `GET /padd` for a dashboard-style summary
(optional `full` param).

---

### Database History

`GET /stats/database/summary`, `/stats/database/top_domains`,
`/stats/database/top_clients`, `/stats/database/upstreams`,
`/stats/database/query_types` — all accept `from`/`until`.

`GET /history`, `GET /history/clients` (in-memory) and their long-term-DB
equivalents `GET /history/database`, `GET /history/database/clients`
(params `from`/`until`).

---

## Endpoints not covered by this skill (for reference)

Not documented in detail here to keep this skill lean, but worth knowing they exist:

- `GET/POST/DELETE /groups`, `/groups/{name}`, `/groups:batchDelete` — group management
- `GET/POST/DELETE /clients`, `/clients/{client}`, `/clients:batchDelete`, `/clients/_suggestions`
- `GET/PATCH /config`, `/config/_properties`, `/config/{element}(/{value})` — live FTL config
- `GET /teleporter` (export backup zip), `POST /teleporter` (multipart import/restore)
- `GET /logs/dnsmasq`, `/logs/ftl`, `/logs/webserver` — raw log tailing with `nextID` polling
- `GET /endpoints` — self-discovery of all registered routes
