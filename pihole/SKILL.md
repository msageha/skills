---
name: pihole
description: "Pi-hole DNS sinkhole management. Use when: user asks about ad blocking status, DNS queries, blocked domains, allowlists/denylists, network devices, or DHCP leases. Controls the local Pi-hole v6 instance via REST API."
metadata:
  openclaw:
    emoji: "🛡️"
    requires:
      bins:
        - curl
        - jq
---

# Pi-hole

Base URL: `https://pihole.msageha.net/api` (Pi-hole v6 REST API). Requests to
this instance don't need any authentication header/cookie. The reverse proxy
only admits allowlisted LAN client IPs — a `403` with an nginx HTML page means
the caller isn't on that list, not an API error. Pi-hole itself answers `401`
`unauthorized` to requests it judges cross-site (`Sec-Fetch-Site` / `Origin`).

## Key facts

- Session-based SID auth exists for password-protected instances (`POST /auth`,
  header/query/cookie `sid`) but isn't needed for this instance.
- Toggle blocking only when the user asks, and confirm it with current → new
  first: it changes DNS for the whole network, and a new request replaces any
  running timer (read `GET /dns/blocking` for the current `{blocking, timer}`).
  When disabling it, always pass a
  positive `timer` (seconds) unless the user explicitly wants it disabled
  indefinitely — warn them either way. `0`,
  a negative value, `null` or no `timer` means no timer (indefinite); check
  the `timer` in the response. The timer doesn't survive a Pi-hole restart
  (blocking then stays off), so re-check the state if one happened.
- Changes to DNS filtering and configuration (allow/deny lists, adlists,
  groups, clients, `PATCH /config`, `POST /teleporter`) change name
  resolution for the whole network: read the current entries first and
  confirm with current → new, even when the request is specific.
  `POST /teleporter` overwrites the configuration and `PATCH /config` changes
  settings in it: ask the user to take a backup with `GET /teleporter` first.
  The backup can hold password hashes and 2FA secrets, so the user downloads
  and keeps it; don't download or open it yourself. When reading `/config`,
  select only the settings involved.
- Confirm these even when the user asked for them, naming the effect: a
  gravity update (it can take a while) and `POST /action/restartdns` (it
  interrupts resolution and drops a pending blocking timer).
- Any other request that changes state (any method but `GET`) runs without
  asking again when the user asked for it with the target settled, including
  deletions (`POST /action/flush/*` deletes the logs or the network table
  irreversibly; deleting devices, leases or messages). Confirm once when you
  chose the request yourself or when the request doesn't settle the target.
- `GET /auth/app` and `GET /auth/totp` create credentials (an application
  password, a 2FA secret): don't call them; the user sets them up.
- The set of block adlists and exact / regex allow rules is synced from files
  in the local-home-services repository (`dns-server/config/adlists.list`,
  `whitelist.txt`, `whitelist-regex.txt`) at startup and monthly: after the
  next successful sync, block adlists and allow rules added through the API
  are gone and listed ones deleted through it are back. Changes to `enabled`
  or groups of a listed entry stay, except on lists whose URL in
  `adlists.list` has a `{YYYYMM}` placeholder (re-added as a new list every
  month). For these synced entries, API changes are temporary — tell the
  user; lasting ones need the files changed. Deny rules and allow adlists
  aren't synced, so API changes to them last.
- Send requests as commands.md does, with `curl -sSf` under
  `set -o pipefail`. A failed connection or an HTTP status of 400 or above
  then exits non-zero and prints the error to stderr instead of the body, so
  an error body never reaches a jq filter, which would print it or turn its
  missing fields into `null` that reads like a result. Treat a write
  as done only when curl exited 0. A 4xx means the request was rejected and
  nothing changed: check it against the operation's schema
  (api-reference) rather than resending it to read the error. After
  a 5xx, a timeout or a dropped connection the write may have taken effect:
  read the state before resending.
- Report a write as done only after reading it back: `GET /dns/blocking`,
  `GET /domains/{type}/{kind}/{domain}`, `GET /lists`, and the matching `GET`
  for other changes.
  Adding several domains in one `POST /domains/…` returns
  `201` even if some fail — check `processed.errors`. A gravity
  update reports failure as `Gravity failed` at the end of a 200 body
  (`409` = another run in progress).
- List URLs (`address` in `/lists`, `/search`, `POST /lists` responses, and the
  gravity log) can carry credentials or tokens in any part: don't print them;
  refer to a list by its `id`, and don't print the gravity log itself. To add
  a URL that carries credentials, the user writes it to a file and jq builds
  the body from it straight into curl's stdin (the second Add example in
  commands.md), so the URL reaches neither the command nor your output.
- `GET /search/{domain}` shows which lists contain a domain; it doesn't apply
  group assignments or allow rules, so it doesn't prove a given client is
  blocked — use the query log (`GET /queries?domain=…&client_ip=…`) for that.

## Core operations

| Task                         | Endpoint                                                 |
| ---------------------------- | -------------------------------------------------------- |
| Status summary               | `GET /stats/summary`                                     |
| Blocking on/off              | `GET`/`POST /dns/blocking`                               |
| Recent / top blocked domains | `GET /stats/recent_blocked`, `GET /stats/top_domains`    |
| Query log                    | `GET /queries`                                           |
| Search a domain              | `GET /search/{domain}`                                   |
| Allow / deny a domain        | `POST /domains/{type}/{kind}`                            |
| List / remove domains        | `GET /domains`, `DELETE /domains/{type}/{kind}/{domain}` |
| Network devices              | `GET /network/devices`                                   |
| DHCP leases                  | `GET /dhcp/leases`                                       |
| Adlists                      | `GET`/`POST /lists`                                      |
| Update gravity / restart DNS | `POST /action/gravity`, `POST /action/restartdns`        |
| Version / system info        | `GET /info/version`, `GET /info/system`                  |

Authentication, and each endpoint's parameters, request/response schemas and behaviour: see
[references/api-reference.md](references/api-reference.md). Ready-to-run curl
examples: [references/commands.md](references/commands.md).
