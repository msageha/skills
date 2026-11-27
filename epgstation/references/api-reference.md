# EPGStation API Reference

Base URL: `https://epgstation.msageha.net/api` (EPGStation v2.10.0).

This file holds what the OpenAPI document doesn't say or gets wrong. Read
endpoint lists, parameters and request/response schemas from the OpenAPI
document.

## Endpoints and schemas

`https://epgstation.msageha.net/api/docs` is the server's own OpenAPI document
(about 80 KB): parameters (with which are required), request bodies and
response schemas, with Japanese descriptions. Its paths omit the `/api`
prefix. Look up one operation instead of reading the whole document:

```bash
set -o pipefail  # a failed download must fail the command
# List operations
curl -sf "https://epgstation.msageha.net/api/docs" | jq -er '.paths | to_entries[]
  | .key as $p | .value | to_entries[] | select(.value | type == "object")
  | "\(.key | ascii_upcase) \($p)  \(.value.summary // .value.description // "")"'

# One operation with its parameters and schemas inlined — set --arg path / --arg method
curl -sf "https://epgstation.msageha.net/api/docs" | jq -e --arg path /schedules/search --arg method post '
  . as $root
  | def deref($seen):
      if type == "object" then
        if has("$ref") then (."$ref" | split("/")) as $r | ($r | last) as $n
          | (if ($seen | index($n)) then {"$ref": $n} else ($root.components[$r[2]][$n] | deref($seen + [$n])) end)
            + (del(."$ref") | deref($seen))
        else map_values(deref($seen)) end
      elif type == "array" then map(deref($seen)) else . end;
    .paths[$path] as $item
    | $item[$method]
    | {summary, description, parameters: (($item.parameters // []) + (.parameters // [])),
       request: .requestBody, responses: (.responses | map_values(.content // .description))}
    | deref([])'
```

## Behaviour the OpenAPI document doesn't show or gets wrong

- All timestamps (`startAt`, `endAt`, `searchPeriods`) are Unix time in
  milliseconds. Conversion recipes: [commands.md](commands.md#unixtimems-conversion).
- `RuleSearchOption.durationMin` / `durationMax` are seconds (the document
  says minutes; the server compares them ×1000 with the program length in
  ms). Omit them unless you mean a length filter: `0` is a real bound, so
  `durationMax: 0` matches nothing.
- The `channel` inside `/schedules*` responses has no `halfWidthName` or
  `channel` (channel number), unlike `GET /channels`; its `name` follows
  `isHalfWidth`, while `GET /channels` `name` is always full-width (use
  `halfWidthName` there).
- `GET /schedules/{channelId}?days=N` returns one `{channel, programs}` per
  24 h from `startAt`, each including programs that touch its edges: a program
  across midnight appears in both days, so de-duplicate by `id` when
  flattening several days.
- `SearchTime.week` is a bitmask, Sunday `0x01` … Saturday `0x40`; combine days
  with bitwise OR (Mon + Wed = `0x02 | 0x08` = `10`; the document says "and").
  `0` is rejected.
- Rules (`POST /rules`, `PUT /rules/{ruleId}`): with `channelIds`, the
  broadcast flags `GR` / `BS` / `CS` / `SKY` must all be false. With
  `isTimeSpecification: true`, `keyword`, `channelIds` and `times` are
  required, and each `times` entry needs `start` (seconds from 00:00) and
  `range` (seconds); otherwise `start` is an hour (0-23) and `range` hours
  (1-23).
- `RuleReserveOption.periodToAvoidDuplicate` is in days (the document only
  says "period").
- `RuleSearchOption.isFree: true` limits to free broadcasts; `false` or
  omitted means all programs (not paid-only, unlike the `isFree` query
  parameter of the schedule endpoints).
- `/schedules/broadcasting` and search results include `rawExtended` (the
  extended text split by heading) whenever the program has it, without
  `needsRawExtended`.
- `GET /rules`: each rule is the `AddRuleOption` body (as sent to
  `POST /rules`) plus `id` and `reservesCnt` (reservations it currently
  produces).
- `POST /reserves` needs `allowEndLack` and either `programId` (from a
  schedule or search result) or `timeSpecifiedOption`
  (`{channelId, startAt, endAt, name}`).

## Genre IDs (ARIB STD-B10)

`genre1..3` in programs and `genres[].genre` in search options are untyped
integers in the document:

| ID | ジャンル              |
| -- | --------------------- |
| 0  | ニュース/報道         |
| 1  | スポーツ              |
| 2  | 情報/ワイドショー     |
| 3  | ドラマ                |
| 4  | 音楽                  |
| 5  | バラエティ            |
| 6  | 映画                  |
| 7  | アニメ/特撮           |
| 8  | ドキュメンタリー/教養 |
| 9  | 劇場/公演             |
| 10 | 趣味/教育             |
| 11 | 福祉                  |
| 12 | 予備 (未使用)         |
| 13 | 予備 (未使用)         |
| 14 | 拡張                  |
| 15 | その他                |
