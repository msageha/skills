# EPGStation Command Recipes

Ready-to-run `curl` examples for the endpoints listed in
[api-reference.md](api-reference.md). Base URL: `http://172.16.1.101:9999/api`.

## Currently Broadcasting

```bash
curl -s "http://172.16.1.101:9999/api/schedules/broadcasting?isHalfWidth=true" | jq '.[] | {channel: .channel.name, programs: [.programs[] | {name, description, startAt: (.startAt / 1000 | strftime("%H:%M")), endAt: (.endAt / 1000 | strftime("%H:%M"))}]}'
```

## Channel List

```bash
curl -s "http://172.16.1.101:9999/api/channels" | jq '.[] | {id, name: .halfWidthName, type: .channelType}'
```

## Channel Schedule

```bash
# days=1 for today
curl -s "http://172.16.1.101:9999/api/schedules/{channelId}?days=1&isHalfWidth=true" | jq '[.programs[] | {id, name, description, start: (.startAt / 1000 | strftime("%H:%M")), end: (.endAt / 1000 | strftime("%H:%M"))}]'
```

## Search Programs

```bash
curl -s -X POST "http://172.16.1.101:9999/api/schedules/search" \
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
  }' | jq '[.[] | .programs[] | {id, name, channelId, start: (.startAt / 1000 | strftime("%Y-%m-%d %H:%M")), end: (.endAt / 1000 | strftime("%H:%M")), description}]'
```

## Reserve (by Program ID)

```bash
curl -s -X POST "http://172.16.1.101:9999/api/reserves" \
  -H "Content-Type: application/json" \
  -d '{"programId": PROGRAM_ID, "allowEndLack": true}'
```

## Reserve (by Time)

```bash
curl -s -X POST "http://172.16.1.101:9999/api/reserves" \
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
curl -s "http://172.16.1.101:9999/api/reserves?isHalfWidth=true&limit=50" | jq '[.reserves[] | {id, name, channelId, start: (.startAt / 1000 | strftime("%Y-%m-%d %H:%M")), end: (.endAt / 1000 | strftime("%H:%M")), isSkip, isConflict}]'
```

## Delete Reservation

```bash
curl -s -X DELETE "http://172.16.1.101:9999/api/reserves/{reserveId}"
```

## Reservation Counts

```bash
curl -s "http://172.16.1.101:9999/api/reserves/cnts" | jq .
```

## Currently Recording

```bash
curl -s "http://172.16.1.101:9999/api/recording?isHalfWidth=true" | jq '[.records[] | {id, name, channelId, start: (.startAt / 1000 | strftime("%H:%M")), end: (.endAt / 1000 | strftime("%H:%M"))}]'
```

## List / Search Recorded Programs

```bash
curl -s "http://172.16.1.101:9999/api/recorded?isHalfWidth=true&limit=20" | jq '[.records[] | {id, name, channelId, start: (.startAt / 1000 | strftime("%Y-%m-%d %H:%M")), isRecording, isProtected}]'

# filtered by keyword
curl -s "http://172.16.1.101:9999/api/recorded?isHalfWidth=true&keyword=キーワード&limit=20" | jq '[.records[] | {id, name, start: (.startAt / 1000 | strftime("%Y-%m-%d %H:%M"))}]'
```

## Delete / Protect / Unprotect Recorded Program

```bash
curl -s -X DELETE "http://172.16.1.101:9999/api/recorded/{recordedId}"
curl -s -X PUT "http://172.16.1.101:9999/api/recorded/{recordedId}/protect"
curl -s -X PUT "http://172.16.1.101:9999/api/recorded/{recordedId}/unprotect"
```

## Add Auto-Recording Rule

```bash
curl -s -X POST "http://172.16.1.101:9999/api/rules" \
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
curl -s "http://172.16.1.101:9999/api/rules?offset=0&limit=20" | jq '[.rules[] | {id, keyword: .searchOption.keyword, enable: .reserveOption.enable, reservesCnt}]'

curl -s -X DELETE "http://172.16.1.101:9999/api/rules/{ruleId}"
curl -s -X PUT "http://172.16.1.101:9999/api/rules/{ruleId}/disable"
curl -s -X PUT "http://172.16.1.101:9999/api/rules/{ruleId}/enable"
```

## UnixtimeMS Conversion

```bash
# JS: Date to UnixtimeMS
node -e "console.log(new Date('2024-03-02T21:00:00+09:00').getTime())"

# jq: UnixtimeMS to readable (JST)
jq '.startAt / 1000 | strftime("%Y-%m-%d %H:%M")'
```
