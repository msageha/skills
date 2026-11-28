# EPGStation Command Recipes

Ready-to-run `curl` examples for common tasks. For other endpoints and for
request/response schemas, see [api-reference.md](api-reference.md): how to look
them up in the server's OpenAPI document, and what the document leaves out. Base URL: `https://epgstation.msageha.net/api`.

The examples use `curl -s` for brevity, which exits 0 on an HTTP error, and pipe
to `jq`, which turns an error body into `null`s. Before reporting a write as
done or trusting a filtered result, check that curl exited 0 (with
`set -o pipefail` when piping) and that the status from `-w '%{http_code}'`
(body saved with `-o <file>`) is the one the operation returns on success.

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
curl -s "https://epgstation.msageha.net/api/schedules/{channelId}?startAt=$start&days=1&isHalfWidth=true" | jq --argjson start "$start" --argjson end "$end" '[.[].programs[] | select(.startAt < $end and .endAt > $start) | {id, name, description, start: (.startAt / 1000 + 32400 | strftime("%H:%M")), end: (.endAt / 1000 + 32400 | strftime("%H:%M"))}]'
```

## Search Programs

```bash
curl -s -X POST "https://epgstation.msageha.net/api/schedules/search" \
  -H "Content-Type: application/json" \
  -d '{
    "isHalfWidth": true,
    "limit": 20,
    "option": {
      "keyword": "検索キーワード",
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

Find the program with Search Programs (above) and show the candidates to the
user first; take `PROGRAM_ID` from the one they choose. Confirm with the user
before creating a reservation (also by time, below).

```bash
curl -s -X POST "https://epgstation.msageha.net/api/reserves" \
  -H "Content-Type: application/json" \
  -d '{"programId": PROGRAM_ID, "allowEndLack": true}'
```

## Reserve (by Time)

```bash
curl -s -X POST "https://epgstation.msageha.net/api/reserves" \
  -H "Content-Type: application/json" \
  -d '{
    "allowEndLack": true,
    "timeSpecifiedOption": {
      "channelId": CHANNEL_ID,
      "startAt": START_UNIX_MS,
      "endAt": END_UNIX_MS,
      "name": "番組名"
    }
  }'
```

## List Reservations

```bash
curl -s "https://epgstation.msageha.net/api/reserves?isHalfWidth=true&limit=50" | jq '[.reserves[] | {id, name, channelId, start: (.startAt / 1000 + 32400 | strftime("%Y-%m-%d %H:%M")), end: (.endAt / 1000 + 32400 | strftime("%H:%M")), isSkip, isConflict}]'
```

## Delete Reservation

```bash
# Confirm with the user first
curl -s -X DELETE "https://epgstation.msageha.net/api/reserves/{reserveId}"
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
# Deleting a recording is irreversible — confirm with the user first
curl -s -X DELETE "https://epgstation.msageha.net/api/recorded/{recordedId}"
curl -s -X PUT "https://epgstation.msageha.net/api/recorded/{recordedId}/protect"
curl -s -X PUT "https://epgstation.msageha.net/api/recorded/{recordedId}/unprotect"
```

## Add Auto-Recording Rule

Confirm with the user before adding, editing, enabling, disabling or deleting a rule.

```bash
curl -s -X POST "https://epgstation.msageha.net/api/rules" \
  -H "Content-Type: application/json" \
  -d '{
    "isTimeSpecification": false,
    "searchOption": {
      "keyword": "キーワード",
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
curl -s -X DELETE "https://epgstation.msageha.net/api/rules/{ruleId}"
curl -s -X PUT "https://epgstation.msageha.net/api/rules/{ruleId}/disable"
curl -s -X PUT "https://epgstation.msageha.net/api/rules/{ruleId}/enable"
```

## UnixtimeMS Conversion

```bash
# JS: Date to UnixtimeMS
node -e "console.log(new Date('2024-03-02T21:00:00+09:00').getTime())"

# jq: UnixtimeMS to readable JST (strftime formats UTC, so add 9 h)
jq '.startAt / 1000 + 32400 | strftime("%Y-%m-%d %H:%M")'
```
