---
name: epgstation
description: "EPGStation TV recording service. Use when: user asks about TV programs, schedules, recordings, or reservations. Controls EPGStation via REST API for browsing what's on TV, searching programs, managing recordings and auto-recording rules."
homepage: https://epgstation.msageha.net
metadata:
  openclaw:
    emoji: "📺"
    requires:
      bins:
        - curl
        - jq
---

# EPGStation

Base URL: `https://epgstation.msageha.net/api` (EPGStation v2.10.0).

## Key facts

- All timestamps are Unix time in milliseconds, not seconds.
- Pass `isHalfWidth=true` (a query parameter, or a field in the
  `POST /schedules/search` body) on endpoints that take it, for readable
  Japanese text. `GET /channels` `name` is always full-width; use `halfWidthName` there.
- Default `limit` is 24; paginate with `limit`/`offset`.
- Genre IDs follow ARIB STD-B10 (see references/api-reference.md for the table).
- Confirm with the user before creating or deleting a reservation, before
  adding, editing, enabling, disabling or deleting a rule (rules create and
  remove reservations), and before deleting a recorded program (irreversible).
- Treat a request as successful only when curl exits 0 and the HTTP status
  is the one the operation returns on success; `| jq` output proves neither
  (without `set -o pipefail`, `curl … | jq` exits with jq's status, and
  `curl -f` lets a `3xx` through). Save the body with `-o <file>`, read the
  status with `-w '%{http_code}'`, and process the body only after both
  checks pass.
- Search for a program first and show results before reserving it.

## Core operations

| Task                                 | Endpoint                                                              |
| ------------------------------------ | --------------------------------------------------------------------- |
| Currently broadcasting               | `GET /schedules/broadcasting`                                         |
| Channel list                         | `GET /channels`                                                       |
| Channel schedule                     | `GET /schedules/{channelId}?startAt=<ms>&days=N&isHalfWidth=true`     |
| Program detail                       | `GET /schedules/detail/{programId}`                                   |
| Search programs                      | `POST /schedules/search`                                              |
| Reserve (by program or time range)   | `POST /reserves`                                                      |
| List reservations                    | `GET /reserves`                                                       |
| Reservation detail / delete          | `GET`, `DELETE /reserves/{reserveId}`                                 |
| Reservation counts (conflicts/skips) | `GET /reserves/cnts`                                                  |
| Currently recording                  | `GET /recording`                                                      |
| List / search recorded               | `GET /recorded`                                                       |
| Protect / delete recorded            | `PUT /recorded/{recordedId}/protect`, `DELETE /recorded/{recordedId}` |
| Auto-recording rules                 | `POST /rules`, `GET /rules`, `PUT /rules/{ruleId}/enable\|disable`    |

How to look up an endpoint's parameters and request/response schema in the
OpenAPI document, behaviour it doesn't show, and the genre table: see
[references/api-reference.md](references/api-reference.md). Ready-to-run curl
examples: [references/commands.md](references/commands.md).
