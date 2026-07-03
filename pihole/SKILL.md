---
name: pihole
description: "Pi-hole DNS sinkhole management. Use when: user asks about ad blocking status, DNS queries, blocked domains, allowlists/denylists, network devices, or DHCP leases. Controls the local Pi-hole v6 instance via REST API."
metadata:
  openclaw:
    emoji: "🛡️"
    requires:
      bins:
        - curl
---

# Pi-hole

Base URL: `https://pihole.msageha.net/api` (Pi-hole v6 REST API). Requests to
this instance don't need any authentication header/cookie.

## Key facts

- Session-based SID auth exists for password-protected instances (`POST /auth`,
  header/query/cookie `sid`) but isn't needed for this instance.
- When disabling blocking, always pass a `timer` (seconds) unless the user
  explicitly wants it disabled indefinitely — warn them either way.
- Confirm with the user before modifying allow/deny lists, adding adlists, or
  running a gravity update (gravity update can take a while).

## Core operations

| Task | Endpoint |
|---|---|
| Status summary | `GET /stats/summary` |
| Blocking on/off | `GET`/`POST /dns/blocking` |
| Recent / top blocked domains | `GET /stats/recent_blocked`, `GET /stats/top_domains` |
| Query log | `GET /queries` |
| Search a domain | `GET /search/{domain}` |
| Allow / deny a domain | `POST /domains/{type}/{kind}` |
| List / remove domains | `GET /domains`, `DELETE /domains/{type}/{kind}/{domain}` |
| Network devices | `GET /network/devices` |
| DHCP leases | `GET /dhcp/leases` |
| Adlists | `GET`/`POST /lists` |
| Update gravity / restart DNS | `POST /action/gravity`, `POST /action/restartdns` |
| Version / system info | `GET /info/version`, `GET /info/system` |

Full request/response schemas and ready-to-run curl examples: see
[references/api-reference.md](references/api-reference.md) and
[references/commands.md](references/commands.md).
