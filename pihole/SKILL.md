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
- When disabling blocking, always pass a positive `timer` (seconds) unless the
  user explicitly wants it disabled indefinitely — warn them either way. `0`,
  a negative value, `null` or no `timer` means no timer (indefinite); check
  the `timer` in the response. The timer doesn't survive a Pi-hole restart
  (blocking then stays off), so re-check the state if one happened.
- Confirm with the user before modifying allow/deny lists, adding adlists,
  running a gravity update (it can take a while), or restarting DNS
  (`POST /action/restartdns` interrupts resolution and drops a pending
  blocking timer).
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
- Judge success by curl's exit code and the HTTP status (`curl -sf`, or
  `-o <file> -w '%{http_code}'`), not by `| jq` output: a failed request still exits 0
  through the pipe. Adding several domains in one `POST /domains/…` returns
  `201` even if some fail — check `processed.errors`. A gravity
  update reports failure as `Gravity failed` at the end of a 200 body
  (`409` = another run in progress).
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

Full request/response schemas and ready-to-run curl examples: see
[references/api-reference.md](references/api-reference.md) and
[references/commands.md](references/commands.md).
