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
---

# EPGStation

Base URL: `https://epgstation.msageha.net/api` (EPGStation v2.10.0)。

## Key facts

- All timestamps are Unix time in **milliseconds**, not seconds.
- Always pass `isHalfWidth=true` for readable Japanese text.
- Default `limit` is 24; paginate with `limit`/`offset`.
- Genre IDs follow ARIB STD-B10 (see references/api-reference.md for the table).
- Confirm with the user before creating or deleting a reservation/rule.
- Search for a program first and show results before reserving it.

## Core operations

| Task | Endpoint |
|---|---|
| Currently broadcasting | `GET /schedules/broadcasting` |
| Channel list | `GET /channels` |
| Channel schedule | `GET /schedules/{channelId}?days=N` |
| Program detail | `GET /schedules/detail/{programId}` |
| Search programs | `POST /schedules/search` |
| Reserve (by program or time range) | `POST /reserves` |
| List / delete reservation | `GET`, `DELETE /reserves/{reserveId}` |
| Reservation counts (conflicts/skips) | `GET /reserves/cnts` |
| Currently recording | `GET /recording` |
| List / search recorded | `GET /recorded` |
| Protect / delete recorded | `PUT /recorded/{id}/protect`, `DELETE /recorded/{id}` |
| Auto-recording rules | `POST /rules`, `GET /rules`, `PUT /rules/{id}/enable\|disable` |

Full request/response schemas and ready-to-run curl examples: see
[references/api-reference.md](references/api-reference.md) and
[references/commands.md](references/commands.md).
