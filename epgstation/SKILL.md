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
- `allowEndLack: true` (used in the examples) lets a reservation lose its
  last minutes when it overlaps another recording; set it as the user wants.
- Genre IDs follow ARIB STD-B10 (see references/api-reference.md for the table).
- A reservation, a deletion of a reservation or recording, or a protect /
  unprotect the user asked for, with its target settled, runs without asking
  again. Confirm once when you chose it yourself or when the request doesn't
  settle the target. Adding, editing, enabling, disabling or deleting a rule
  can create and remove many reservations, which the request doesn't show:
  confirm it, saying which programs it affects. Deleting a recording is
  irreversible, so name the recording when you confirm. Deleting a recording
  that is still recording stops the recording first, and a protected one
  can't be deleted until it is unprotected.
- Before reporting a write as done or acting on a result, check that curl
  exited 0 and that the HTTP status is the one the operation returns on
  success. The output of `curl … | jq` doesn't show it: `jq .` prints a JSON
  error body like any other, a filter turns its missing fields into `null`, and a
  failed connection prints nothing. For a write, save the body with
  `-o <file>`, read the status with `-w '%{http_code}'`, and use the body only
  after both checks pass. For a read a later step depends on,
  `set -o pipefail` with `curl -sf` and a `jq -e` expression that holds
  only for the expected answer (an error body must fail it) also works: an error body, empty body or HTML page then fails `jq -e`, but a
  `3xx` whose body has that field passes, so check the status where a
  redirect is possible.
- To reserve a program, search for it first to get its `programId`; when
  more than one program fits the request, show the candidates and let the
  user choose. A time-range reservation needs no search.
- Report a write as done only after reading it back: `GET /reserves/{reserveId}`
  or `GET /reserves` for a reservation, `GET /rules/{ruleId}` for a rule, and
  `isProtected` in `GET /recorded/{recordedId}` after protect / unprotect.
  Deleting a manual reservation makes `GET /reserves/{reserveId}` return
  `404`; deleting one a rule made (other than an event relay) keeps it with
  `isSkip: true` (or `isOverlap: true`). After deleting a recording, a `404` from
  `GET /recorded/{recordedId}` shows the record is gone, not that the file
  was removed (the server deletes the record even when removing the file
  fails), so report the file's removal as unconfirmed.

## Core operations

| Task                                 | Endpoint                                                              |
| ------------------------------------ | --------------------------------------------------------------------- |
| Currently broadcasting               | `GET /schedules/broadcasting`                                         |
| Channel list                         | `GET /channels`                                                       |
| Channel schedule                     | `GET /schedules/{channelId}?startAt=<ms>&days=<n>&isHalfWidth=true`   |
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
