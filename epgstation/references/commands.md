# EPGStation Command Recipes

Ready-to-run `curl` examples for common tasks. For other endpoints and for
request/response schemas, see [api-reference.md](api-reference.md): how to look
them up in the server's OpenAPI document, and what the document leaves out. Base URL: `https://epgstation.msageha.net/api`.

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

## Currently Broadcasting

```bash
curl -s "https://epgstation.msageha.net/api/schedules/broadcasting?isHalfWidth=true" | jq '.[] | {channel: .channel.name, programs: [.programs[] | {name, description, startAt: (.startAt / 1000 + 32400 | strftime("%H:%M")), endAt: (.endAt / 1000 + 32400 | strftime("%H:%M"))}]}'
```

## Channel List

```bash
curl -s "https://epgstation.msageha.net/api/channels" | jq '.[] | {id, name: .halfWidthName, type: .channelType}'
```

## Channel Schedule

```bash
# Today's schedule: startAt (required, Unix ms) = today's 00:00 JST, days=1 covers 24 h from it.
# The response is an array of {channel, programs}; it also includes programs starting at the
# next 00:00, so keep those airing before it
start=$(( ($(date +%s) + 32400) / 86400 * 86400 - 32400 ))000
end=$((start + 86400000))
curl -s "https://epgstation.msageha.net/api/schedules/<channel-id>?startAt=$start&days=1&isHalfWidth=true" | jq --argjson start "$start" --argjson end "$end" '[.[].programs[] | select(.startAt < $end and .endAt > $start) | {id, name, description, start: (.startAt / 1000 + 32400 | strftime("%H:%M")), end: (.endAt / 1000 + 32400 | strftime("%H:%M"))}]'
```

## Search Programs

```bash
curl -s -X POST "https://epgstation.msageha.net/api/schedules/search" \
  -H "Content-Type: application/json" \
  -d '{
    "isHalfWidth": true,
    "limit": 20,
    "option": {
      "keyword": "<keyword>",
      "name": true,
      "description": true,
      "GR": true,
      "BS": true,
      "CS": true,
      "SKY": true
    }
  }' | jq '[.[] | {id, name, channelId, start: (.startAt / 1000 + 32400 | strftime("%Y-%m-%d %H:%M")), end: (.endAt / 1000 + 32400 | strftime("%H:%M")), description}]'
```

## Reserve (by Program ID)

Find the program with Search Programs (above) and take `<program-id>` from it;
when more than one program fits the request, show the candidates and let the
user choose.

```bash
curl -s -X POST "https://epgstation.msageha.net/api/reserves" \
  -H "Content-Type: application/json" \
  -d '{"programId": <program-id>, "allowEndLack": true}'
```

## Reserve (by Time)

No program search is needed. When the request doesn't settle the channel or
the time range, confirm them with the user first.

```bash
curl -s -X POST "https://epgstation.msageha.net/api/reserves" \
  -H "Content-Type: application/json" \
  -d '{
    "allowEndLack": true,
    "timeSpecifiedOption": {
      "channelId": <channel-id>,
      "startAt": <start-unix-ms>,
      "endAt": <end-unix-ms>,
      "name": "<name>"
    }
  }'
```

## List Reservations

```bash
curl -s "https://epgstation.msageha.net/api/reserves?isHalfWidth=true&limit=50" | jq '[.reserves[] | {id, name, channelId, start: (.startAt / 1000 + 32400 | strftime("%Y-%m-%d %H:%M")), end: (.endAt / 1000 + 32400 | strftime("%H:%M")), isSkip, isConflict}]'
```

## Delete Reservation

```bash
# Unless the user asked to delete this reservation, confirm first
curl -s -X DELETE "https://epgstation.msageha.net/api/reserves/<reserve-id>"
```

## Reservation Counts

```bash
curl -s "https://epgstation.msageha.net/api/reserves/cnts" | jq .
```

## Currently Recording

```bash
curl -s "https://epgstation.msageha.net/api/recording?isHalfWidth=true" | jq '[.records[] | {id, name, channelId, start: (.startAt / 1000 + 32400 | strftime("%H:%M")), end: (.endAt / 1000 + 32400 | strftime("%H:%M"))}]'
```

## List / Search Recorded Programs

```bash
curl -s "https://epgstation.msageha.net/api/recorded?isHalfWidth=true&limit=20" | jq '[.records[] | {id, name, channelId, start: (.startAt / 1000 + 32400 | strftime("%Y-%m-%d %H:%M")), isRecording, isProtected}]'

# filtered by keyword
curl -s -G "https://epgstation.msageha.net/api/recorded" -d isHalfWidth=true -d limit=20 --data-urlencode 'keyword=<keyword>' | jq '[.records[] | {id, name, start: (.startAt / 1000 + 32400 | strftime("%Y-%m-%d %H:%M"))}]'
```

## Delete / Protect / Unprotect Recorded Program

```bash
# Deleting a recording is irreversible — unless the user asked to delete this recording, confirm first
curl -s -X DELETE "https://epgstation.msageha.net/api/recorded/<recorded-id>"
curl -s -X PUT "https://epgstation.msageha.net/api/recorded/<recorded-id>/protect"
curl -s -X PUT "https://epgstation.msageha.net/api/recorded/<recorded-id>/unprotect"
```

## Add Auto-Recording Rule

Confirm with the user before adding, editing, enabling, disabling or deleting a
rule, saying which programs it affects: rules create and remove reservations.

```bash
curl -s -X POST "https://epgstation.msageha.net/api/rules" \
  -H "Content-Type: application/json" \
  -d '{
    "isTimeSpecification": false,
    "searchOption": {
      "keyword": "<keyword>",
      "name": true,
      "description": false,
      "extended": false,
      "GR": true,
      "BS": true,
      "CS": false,
      "SKY": false
    },
    "reserveOption": {
      "enable": true,
      "allowEndLack": true,
      "avoidDuplicate": true
    }
  }'
```

## List / Delete / Disable / Enable Rule

```bash
curl -s "https://epgstation.msageha.net/api/rules?offset=0&limit=20" | jq '[.rules[] | {id, keyword: .searchOption.keyword, enable: .reserveOption.enable, reservesCnt}]'

# Deleting, disabling or enabling a rule — confirm with the user first
curl -s -X DELETE "https://epgstation.msageha.net/api/rules/<rule-id>"
curl -s -X PUT "https://epgstation.msageha.net/api/rules/<rule-id>/disable"
curl -s -X PUT "https://epgstation.msageha.net/api/rules/<rule-id>/enable"
```

## UnixtimeMS Conversion

```bash
# JST date and time to UnixtimeMS (fromdateiso8601 takes UTC, so subtract 9 h)
jq -n '(("<yyyy-mm-dd>T<hh:mm>:00Z" | fromdateiso8601) - 32400) * 1000'

# jq: UnixtimeMS to readable JST (strftime formats UTC, so add 9 h)
jq '.startAt / 1000 + 32400 | strftime("%Y-%m-%d %H:%M")'
```
