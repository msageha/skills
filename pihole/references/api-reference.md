# Pi-hole API Reference

Base URL: `https://pihole.msageha.net/api`
Pi-hole REST API v6 (docker image `pihole/pihole:2026.11.0`: core v6.6 /
web v6.6.1 / FTL v6.9). Requests to this instance don't need any
authentication header/cookie; the reverse proxy admits only allowlisted LAN
client IPs (`403` with an nginx HTML page otherwise). Requests Pi-hole judges
cross-site (from `Sec-Fetch-Site` or `Origin`) get `401` `unauthorized` from
Pi-hole itself.

Every response body includes a `took` field (request processing time in
seconds, float) not shown in the examples below.

---

## Authentication

All endpoints on this instance return data without needing a session.

If a password is ever configured, `POST /auth` returns a session id that the
API takes as the `sid` header, cookie or query parameter (valid 5 minutes by
default, extended by each authenticated request); the password and session id
are secrets, so the user logs in, not the agent. `GET /auth/app` generates a
long-lived application password and `GET /auth/totp` a new 2FA secret: don't
call them; the user sets them up. `GET /auth/sessions` /
`DELETE /auth/session/{id}` manage active sessions.

---

## Endpoints

### GET /auth

Check authentication status.

Response:

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

Response:

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

| Field    | Type         | Description                                            |
| -------- | ------------ | ------------------------------------------------------ |
| blocking | string       | `enabled` / `disabled` / `failed` / `unknown`          |
| timer    | number\|null | Remaining seconds until auto-change (null = permanent) |

### POST /dns/blocking

Change blocking status. It applies to every client and replaces any running
timer: read `GET /dns/blocking` and confirm with current → new first.

| Field    | Type         | Description                                                                                                                           |
| -------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| blocking | boolean      | Required (omitted → 400). `true` = enable, `false` = disable                                                                          |
| timer    | number\|null | Seconds until auto-reverse; only a positive number sets a timer (`0`, negative, `null` or omitted = none, and clears an active timer) |

---

### GET /stats/top_domains

| Parameter | Type    | Description                                                    |
| --------- | ------- | -------------------------------------------------------------- |
| blocked   | boolean | `true` = blocked domains, `false` = permitted (default: false) |
| count     | integer | Number of results (default: 10)                                |

Response: `{ "domains": [{ "domain": "example.com", "count": 8516 }], "total_queries": 29160, "blocked_queries": 6379 }`

---

### GET /stats/top_clients

| Parameter | Type    | Description                                                      |
| --------- | ------- | ---------------------------------------------------------------- |
| blocked   | boolean | `true` = by blocked queries, `false` = by total (default: false) |
| count     | integer | Number of results (default: 10)                                  |

Response: `{ "clients": [{ "ip": "192.168.0.44", "name": "raspberrypi.lan", "count": 5896 }], "total_queries": 29160, "blocked_queries": 6379 }`

---

### GET /stats/recent_blocked

| Parameter | Type    | Description                    |
| --------- | ------- | ------------------------------ |
| count     | integer | Number of results (default: 1) |

Response: `{ "blocked": ["doubleclick.net", "..."] }`

---

### GET /stats/upstreams / GET /stats/query_types

Upstream DNS destination metrics / DNS query type distribution. No required params.

---

### GET /queries

Recent DNS query log. All parameters optional.

| Parameter    | Type    | Description                                                                                                                                                                                                                |
| ------------ | ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| length       | integer | Number of results (default: 100; at most 10000 per response — page with `cursor` / `start` for more)                                                                                                                       |
| start        | integer | Offset for paging: send the same `length` (1-10000) each time and advance `start` by it, keeping the same filters. New queries keep arriving, so bound the set with `until` (and keep the first `cursor`) for stable pages |
| from / until | number  | Unix timestamp range                                                                                                                                                                                                       |
| domain       | string  | Filter by domain (wildcards `*` supported)                                                                                                                                                                                 |
| client_ip    | string  | Filter by client IP (wildcards supported)                                                                                                                                                                                  |
| client_name  | string  | Filter by client hostname (wildcards supported)                                                                                                                                                                            |
| upstream     | string  | Filter by upstream                                                                                                                                                                                                         |
| type         | string  | Filter by query type (A, AAAA, etc.)                                                                                                                                                                                       |
| status       | string  | Filter by status (GRAVITY, FORWARDED, CACHE, etc.)                                                                                                                                                                         |
| reply        | string  | Filter by reply type (NODATA, NXDOMAIN, etc.)                                                                                                                                                                              |
| dnssec       | string  | Filter by DNSSEC status                                                                                                                                                                                                    |
| disk         | boolean | `true` = query the on-disk long-term DB instead of the in-memory buffer (default: false)                                                                                                                                   |
| cursor       | integer | Upper bound of query IDs while paging (send back the first response's value; it doesn't advance). Rows can still age out of the in-memory log meanwhile                                                                    |

Response:

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
      "list_id": null,
      "ede": { "code": -1, "text": null },
      "cname": null
    }
  ],
  "cursor": 12345,
  "recordsTotal": 65409,
  "recordsFiltered": 65409,
  "draw": 0,
  "earliest_timestamp": 1709283800
}
```

- `list_id`: the entry that decided the query. A negative value is an adlist
  (gravity / antigravity match) encoded as `-(id + 2)` — `-6` is adlist `4` in
  `GET /lists`; a non-negative value is a `domainlist` ID (exact / regex
  rule); `null` if none
- `ede`: Extended DNS Error info (`code: -1` = none)
- `cname`: the CNAME record that led to this query being blocked, if any

Related: `GET /queries/suggestions` (autocomplete values for the filters above).

---

### GET /search/{domain}

Search domain in Pi-hole's lists and gravity.

| Parameter | Type    | Description                         |
| --------- | ------- | ----------------------------------- |
| domain    | string  | Domain to search (path, required)   |
| partial   | boolean | Partial matching (default: false)   |
| N         | integer | Max results per type (default: 20)  |
| debug     | boolean | Include debug info (default: false) |

Response:

```json
{
  "search": {
    "domains": [
      {
        "domain": "ads.example.com",
        "type": "deny",
        "kind": "exact",
        "enabled": true,
        "groups": [0]
      }
    ],
    "gravity": [
      {
        "domain": "ads.example.com",
        "address": "https://blocklist-url...",
        "type": "block",
        "enabled": true
      }
    ],
    "results": {
      "domains": { "exact": 1, "regex": 0 },
      "gravity": { "allow": 0, "block": 1 },
      "total": 2
    }
  }
}
```

---

### Domain Management

#### GET /domains

List all domains. Optional path segments for filtering: `/domains`,
`/domains/allow`, `/domains/deny`, `/domains/allow/exact`, `/domains/deny/regex`.

Response item:

| Field         | Type      | Description                                                          |
| ------------- | --------- | -------------------------------------------------------------------- |
| domain        | string    | Domain or regex pattern                                              |
| unicode       | string    | Unicode-decoded form of `domain` (relevant for punycode/IDN domains) |
| type          | string    | `allow` / `deny`                                                     |
| kind          | string    | `exact` / `regex`                                                    |
| enabled       | boolean   | Whether entry is active                                              |
| comment       | string    | Optional comment                                                     |
| groups        | integer[] | Associated group IDs                                                 |
| id            | integer   | Entry ID                                                             |
| date_added    | integer   | Unix timestamp                                                       |
| date_modified | integer   | Unix timestamp                                                       |

#### POST /domains/{type}/{kind}

Add a domain. Both `{type}` (`allow`/`deny`) and `{kind}` (`exact`/`regex`) required.
This and the `PUT` / `DELETE` below change DNS filtering for every client: read
the current entries and confirm with current → new first.

| Field   | Type               | Required | Description                                   |
| ------- | ------------------ | -------- | --------------------------------------------- |
| domain  | string \| string[] | yes      | One or more domains/patterns                  |
| comment | string\|null       | no       | Optional comment                              |
| groups  | integer[]          | no       | Group IDs (default: `[0]`)                    |
| enabled | boolean            | no       | Whether the entry is active (default: `true`) |

Returns `201` even when some domains fail; failed items are listed in
`processed.errors`.

#### PUT /domains/{type}/{kind}/{domain}

Full update of a domain entry; can move it between type/kind.

#### DELETE /domains/{type}/{kind}/{domain}

Remove a domain. Returns `204 No Content` on success.
Batch variant: `POST /domains:batchDelete` with body `[{item, type, kind}, ...]`.

---

### GET /network/devices

| Parameter     | Type    | Description                           |
| ------------- | ------- | ------------------------------------- |
| max_devices   | integer | Max devices to return (default: 10)   |
| max_addresses | integer | Max addresses per device (default: 3) |

Response item: the per-IP data lives under `ips`; there is no
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
        {
          "ip": "172.16.1.111",
          "name": null,
          "lastSeen": 1783116660,
          "nameUpdated": 1783116660
        }
      ]
    }
  ]
}
```

Related: `DELETE /network/devices/{device_id}` (unless the user asked for it, confirm first), `GET /network/gateway`,
`GET /network/routes`, `GET /network/interfaces` (all take an optional
`detailed` param).

---

### GET /dhcp/leases

Active DHCP leases.

Response item:

| Field    | Type    | Description                     |
| -------- | ------- | ------------------------------- |
| name     | string  | Hostname                        |
| ip       | string  | IP address                      |
| hwaddr   | string  | MAC address                     |
| expires  | integer | Expiry timestamp (0 = infinite) |
| clientid | string  | Client ID                       |

`DELETE /dhcp/leases/{ip}` removes a lease (unless the user asked for it, confirm first).

---

### GET /lists

Adlists (blocklists/allowlists). `type` (`allow`/`block`) optional on GET
(omit for both).

Response item:

| Field                                     | Type      | Description                                                                                                                                  |
| ----------------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| address                                   | string    | List URL                                                                                                                                     |
| enabled                                   | boolean   | Whether list is active                                                                                                                       |
| comment                                   | string    | Optional comment                                                                                                                             |
| type                                      | string    | `allow` / `block`                                                                                                                            |
| groups                                    | integer[] | Associated group IDs (default: `[0]`)                                                                                                        |
| number                                    | integer   | Number of entries                                                                                                                            |
| invalid_domains                           | integer   | Count of malformed entries skipped on last update                                                                                            |
| abp_entries                               | integer   | Count of Adblock Plus-style entries in the list                                                                                              |
| date_added / date_modified / date_updated | integer   | Unix timestamps                                                                                                                              |
| status                                    | integer   | Last gravity result: `1` = updated, `2` = unchanged, `3` = download failed (previous copy used), `4` = download failed (no copy, list empty) |

#### POST /lists

`type` (`allow`/`block`) is a required query parameter, e.g.
`POST /lists?type=block`. Before adding, updating or removing an adlist, read
the current lists and confirm with current → new.

```json
{
  "address": "<list-url>",
  "comment": "<reason>",
  "enabled": true
}
```

#### PUT /lists/{list} / DELETE /lists/{list}

Update or remove an adlist. The `type` query parameter is required on `PUT` and `DELETE` too.
`PUT` replaces the entry: an omitted `enabled` becomes `true` (re-enabling a disabled list)
and an omitted `comment` becomes `null`, so send the current values of the fields you don't
change, and read the list back afterwards.
`{list}` is the URL-encoded address. Batch variant: `POST /lists:batchDelete`.

---

### Actions

| Endpoint                     | Description                                                                                                                                                                                                                                                                                                                                                                      |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `POST /action/gravity`       | Re-download all adlists. Response streamed as `text/plain`, always `200` once streaming starts: a failure shows as `Gravity failed` at the end of the body. `409` = another gravity run is in progress. Afterwards check each list's `status`; `gravity.last_update` in `/stats/summary` is the update time, not proof that DNS uses the new data (check the query log for that) |
| `POST /action/restartdns`    | Restart the pihole-FTL DNS service: resolution stops briefly and a pending blocking timer is lost, so its scheduled switch never happens                                                                                                                                                                                                                                         |
| `POST /action/flush/logs`    | Flush DNS logs and purge last 24h from the DB.                                                                                                                                                                                                                                                                                                                                   |
| `POST /action/flush/network` | Flush the network table (remove all known devices). Replaces the deprecated `flush/arp`.                                                                                                                                                                                                                                                                                         |

Confirm gravity (it can take a while) and `restartdns` (it interrupts resolution) with
the user even when asked. The flushes delete data irreversibly: run them only when the
user asked for them, and confirm otherwise.

---

### System Information

`GET /info/system`, `/info/version`, `/info/host`, `/info/sensors`, `/info/ftl`,
`/info/client`, `/info/database`, `/info/metrics`, `/info/login`. Also
`/info/messages` (+ `/info/messages/{id}` DELETE, which needs the user's confirmation unless they asked for it, and `/info/messages/count`) for
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

Not documented in detail here to keep this skill lean, but worth knowing they exist. Their
non-`GET` methods change DNS filtering or configuration: read the current entries and
confirm with current → new first. Before `POST /teleporter` (overwrites the configuration)
or `PATCH /config` (changes settings in it), ask the user to take a backup with
`GET /teleporter`; it can hold password hashes and 2FA secrets, so the user downloads and
keeps it, not the agent:

- `GET/POST/PUT/DELETE /groups`, `/groups/{name}`, `/groups:batchDelete` — group management
- `GET/POST/PUT/DELETE /clients`, `/clients/{client}`, `/clients:batchDelete`, `/clients/_suggestions`
- `GET/PATCH /config`, `/config/_properties`, `/config/{element}(/{value})` — live FTL config
- `GET /teleporter` (export backup zip), `POST /teleporter` (multipart import/restore)
- `GET /logs/dnsmasq`, `/logs/ftl`, `/logs/webserver` — raw log tailing with `nextID` polling
- `GET /endpoints` — self-discovery of all registered routes
