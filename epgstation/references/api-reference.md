# EPGStation API Reference

Base URL: `https://epgstation.msageha.net/api`
OpenAPI Version: 3.0.1 / EPGStation v2.10.0

---

## Endpoints used by this skill

### GET /channels

放送局情報取得。パラメータなし。

**Response:** `ChannelItem[]`

```json
[
  {
    "id": 3239123608,
    "serviceId": 23608,
    "networkId": 32391,
    "name": "NHK総合1・東京",
    "halfWidthName": "NHK総合1・東京",
    "hasLogoData": true,
    "channelType": "GR",
    "channel": "..."
  }
]
```

---

### GET /schedules/broadcasting

放映中の番組情報取得。

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| isHalfWidth | boolean | yes | 半角文字で取得するか (常に `true` 推奨) |
| time | integer | no | 追加時間 (UnixtimeMS) |

**Response:** `Schedule[]` — 各チャンネルの放送中番組一覧

---

### GET /schedules

番組表情報取得。

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| startAt | integer | yes | 開始時刻 (UnixtimeMS) |
| endAt | integer | yes | 終了時刻 (UnixtimeMS) |
| isHalfWidth | boolean | yes | 半角文字で取得 |
| GR | boolean | yes | 地上波を含む |
| BS | boolean | yes | BSを含む |
| CS | boolean | yes | CSを含む |
| SKY | boolean | yes | スカパーを含む |
| needsRawExtended | boolean | no | rawExtended を含む |
| isFree | boolean | no | 無料放送のみ (true=無料, false=有料, 未指定=全て) |

**Response:** `Schedule[]`

---

### GET /schedules/{channelId}

指定された放送局の番組表情報取得。

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| channelId | integer | yes | 放送局 ID (path) |
| days | integer | yes | 取得日数 |
| isHalfWidth | boolean | yes | 半角文字で取得 |
| startAt | integer | no | 開始時刻 (UnixtimeMS) |
| needsRawExtended | boolean | no | rawExtended を含む |
| isFree | boolean | no | 無料放送のみ |

**Response:** `Schedule[]`

---

### GET /schedules/detail/{programId}

指定された番組の詳細情報取得。

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| programId | integer | yes | プログラム ID (path) |
| isHalfWidth | boolean | yes | 半角文字で取得 |

**Response:** `ScheduleProgramItem`

---

### POST /schedules/search

番組検索。`option` は `RuleSearchOption`(下記スキーマ参照)。

**Request Body:** `ScheduleSearchOption`

```json
{
  "isHalfWidth": true,
  "limit": 20,
  "option": {
    "keyword": "検索文字列",
    "name": true,
    "description": true,
    "extended": false,
    "GR": true,
    "BS": true,
    "CS": false,
    "SKY": false,
    "genres": [{ "genre": 7 }],
    "channelIds": [3239123608]
  }
}
```

**Response:** `Schedule[]`

---

### GET /reserves

予約情報取得。

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| offset | integer | no | オフセット (default: 0) |
| limit | integer | no | 取得件数 (default: 24) |
| type | string | no | `all` / `normal` / `conflict` / `skip` / `overlap` |
| isHalfWidth | boolean | yes | 半角文字で取得 |
| ruleId | integer | no | ルールIDでフィルタ |

**Response:** `Reserves` — `{ "reserves": [...], "total": 42 }`

---

### POST /reserves

予約追加。`programId` 指定 または `timeSpecifiedOption` 指定。

**Request Body:** `ManualReserveOption` = `EditManualReserveOption` (下記) を継承し、
`programId` または `timeSpecifiedOption` を追加したもの。**`allowEndLack` は必須**。

```json
// programId で予約
{ "programId": 123456789, "allowEndLack": true }

// 時刻指定で予約
{
  "allowEndLack": true,
  "timeSpecifiedOption": {
    "channelId": 3239123608,
    "startAt": 1709370000000,
    "endAt": 1709373600000,
    "name": "手動予約"
  }
}
```

**Response:** `AddedReserve` `{ "reserveId": 123 }`

---

### GET /reserves/{reserveId}

指定された予約の詳細取得。

---

### PUT /reserves/{reserveId}

手動予約更新。

**Request Body:** `EditManualReserveOption`

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| allowEndLack | boolean | yes | 末尾切れ許可 |
| tags | integer[] | no | タグID一覧 |
| saveOption | ReserveSaveOption | no | 保存先ディレクトリ/フォーマット指定 |
| encodeOption | ReserveEncodedOption | no | エンコード設定 (下記) |

```json
{
  "allowEndLack": true,
  "tags": []
}
```

---

### DELETE /reserves/{reserveId}

予約削除。

---

### DELETE /reserves/{reserveId}/skip

予約の除外状態を解除。

---

### DELETE /reserves/{reserveId}/overlap

予約の重複状態を解除。

---

### GET /reserves/cnts

予約数取得。

**Response:** `ReserveCnts`

```json
{
  "normal": 10,
  "conflicts": 1,
  "skips": 2,
  "overlaps": 0
}
```

---

### GET /recording

録画中情報取得。

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| offset | integer | no | オフセット (default: 0) |
| limit | integer | no | 取得件数 (default: 24) |
| isHalfWidth | boolean | yes | 半角文字で取得 |

**Response:** `Records`

---

### PUT /recording/resettimer

録画中番組のタイマーをリセット (エンコーダのタイムアウト対策)。

---

### GET /recorded

録画済み番組取得。

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| isHalfWidth | boolean | yes | 半角文字で取得 |
| offset | integer | no | オフセット (default: 0) |
| limit | integer | no | 取得件数 (default: 24) |
| isReverse | boolean | no | 逆順 |
| ruleId | integer | no | ルールIDフィルタ |
| channelId | integer | no | チャンネルIDフィルタ |
| genre | integer | no | ジャンルフィルタ (ARIB) |
| keyword | string | no | キーワード検索 |
| hasOriginalFile | boolean | no | オリジナルファイルを含む |

**Response:** `Records` — `{ "records": [...], "total": 150 }`

---

### DELETE /recorded/{recordedId}

録画削除。

---

### PUT /recorded/{recordedId}/protect

録画を自動削除対象から除外。

---

### PUT /recorded/{recordedId}/unprotect

録画を自動削除対象に戻す。

---

### GET /rules

ルール情報取得。

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| offset | integer | no | オフセット (default: 0) |
| limit | integer | no | 取得件数 (default: 24) |
| type | string | no | `all` / `normal` / `conflict` / `skip` / `overlap` |
| keyword | string | no | キーワード検索 |

**Response:** `Rules` — `{ "rules": [...], "total": 5 }`

---

### GET /rules/keyword

登録済みルールのキーワード一覧のみ取得 (サジェスト用の軽量エンドポイント)。

---

### POST /rules

自動録画ルール追加。

**Request Body:** `AddRuleOption`

| Field | Required | Description |
|-------|----------|--------------|
| isTimeSpecification | yes | 時刻指定ルールか |
| searchOption | yes | `RuleSearchOption` (下記) |
| reserveOption | yes | `RuleReserveOption` (下記) |
| saveOption | no | `ReserveSaveOption` — 保存先ディレクトリ/ファイル名フォーマット |
| encodeOption | no | `ReserveEncodedOption` (下記) |

```json
{
  "isTimeSpecification": false,
  "searchOption": {
    "keyword": "キーワード",
    "ignoreKeyword": "除外キーワード",
    "keyCS": false,
    "keyRegExp": false,
    "name": true,
    "description": false,
    "extended": false,
    "GR": true,
    "BS": true,
    "CS": false,
    "SKY": false,
    "channelIds": [],
    "genres": [],
    "isFree": true,
    "durationMin": 0,
    "durationMax": 0
  },
  "reserveOption": {
    "enable": true,
    "allowEndLack": true,
    "avoidDuplicate": true,
    "periodToAvoidDuplicate": 0,
    "tags": []
  },
  "saveOption": {
    "parentDirectoryName": "",
    "directory": "",
    "recordedFormat": ""
  }
}
```

**Response:** `AddedRule` `{ "ruleId": 1 }`

---

### PUT /rules/{ruleId}

ルール更新。Body は `AddRuleOption` と同じ。

---

### DELETE /rules/{ruleId}

ルール削除。

---

### PUT /rules/{ruleId}/disable

ルール無効化。

---

### PUT /rules/{ruleId}/enable

ルール有効化。

---

## Endpoints not covered by this skill (for reference)

EPGStation v2.10.0 exposes many more endpoints than the TV/recording basics above.
Not documented in detail here to keep this skill lean, but worth knowing they exist:

- `GET /config`, `GET /version`, `GET /storages` — server/config info
- `GET/POST /encode`, `GET/DELETE /encode/{encodeId}` — encode queue management
- `GET /streams`, `GET/DELETE /streams/{streamId}`, `PUT /streams/{streamId}/keep`,
  and live/recorded streaming sub-routes (`/streams/live/{channelId}/{hls,m2ts,mp4,webm}`,
  `/streams/recorded/{videoFileId}/{hls,mp4,webm}`) — live/VOD streaming
- `GET/DELETE /thumbnails`, `POST /thumbnails/videos/{videoFileId}`, `DELETE /thumbnails/cleanup`
- `GET/DELETE /videos/{videoFileId}`, `/videos/{videoFileId}/{duration,kodi,playlist}`, `POST /videos/upload`
- `GET/POST /tags`, `GET/PUT/DELETE /tags/{tagId}`, `PUT /tags/{tagId}/relate` — recorded-tag CRUD
- `GET /dropLogs/{dropLogFileId}` — per-recording drop/error/scrambling counters
- `POST /recorded`, `POST /recorded/{recordedId}/encode`, `DELETE /recorded/cleanup`, `GET /recorded/options`
- `GET /channels/{channelId}/logo`
- `GET /iptv/channel.m3u8`, `GET /iptv/epg.xml` — IPTV playlist/EPG export

---

## Schemas

### ChannelItem

| Field | Type | Description |
|-------|------|-------------|
| id | integer | チャンネルID |
| serviceId | integer | サービスID |
| networkId | integer | ネットワークID |
| name | string | 放送局名 |
| halfWidthName | string | 放送局名 (半角) |
| hasLogoData | boolean | ロゴデータの有無 |
| channelType | string | `GR` / `BS` / `CS` / `SKY` |
| channel | string | チャンネル番号 |
| type | integer | サービス種別 (ARIB) |
| remoteControlKeyId | integer | リモコン番号 |

### ScheduleChannelItem

`Schedule.channel` で使われる別スキーマ。`ChannelItem` とはフィールドが異なり、
**`halfWidthName` と `channel` (チャンネル番号) を含まない**。`name` は
`isHalfWidth` パラメータの値に応じて全角/半角が切り替わる (`ChannelItem.name` は
常に全角、`ScheduleChannelItem.name` は可変)。

| Field | Type | Description |
|-------|------|--------------|
| id | integer | チャンネルID |
| serviceId | integer | サービスID |
| networkId | integer | ネットワークID |
| name | string | 放送局名 (`isHalfWidth` に応じて全角/半角) |
| hasLogoData | boolean | ロゴデータの有無 |
| channelType | string | `GR` / `BS` / `CS` / `SKY` |
| type | integer | サービス種別 (ARIB) |
| remoteControlKeyId | integer | リモコン番号 |

### ScheduleProgramItem

`genre2`/`subGenre2`/`genre3`/`subGenre3` は番組によっては存在しない場合がある。
`rawExtended` は `needsRawExtended` パラメータの有無に関わらず `broadcasting`
エンドポイントでは常に含まれていた (このエンドポイントのパラメータ表に
`needsRawExtended` 自体が無いことと整合)。

| Field | Type | Description |
|-------|------|-------------|
| id | integer | プログラムID |
| channelId | integer | チャンネルID |
| startAt | integer | 開始時刻 (UnixtimeMS) |
| endAt | integer | 終了時刻 (UnixtimeMS) |
| isFree | boolean | 無料放送か |
| name | string | 番組名 |
| description | string | 番組詳細 |
| extended | string | 番組拡張情報 |
| rawExtended | object | 拡張情報を見出しごとに分解したオブジェクト (`{"番組内容": "...", "出演者": "..."}`) |
| genre1 / genre2 / genre3 | integer | ジャンル (ARIB, 複数付与されうる) |
| subGenre1 / subGenre2 / subGenre3 | integer | サブジャンル |
| videoType | string | 映像コーデック (例: `mpeg2`) |
| videoResolution | string | 解像度 (例: `1080i`) |
| videoStreamContent | integer | 映像コンポーネント種別 (ARIB) |
| videoComponentType | integer | 映像コンポーネントタイプ (ARIB) |
| audioSamplingRate | integer | 音声サンプリングレート (Hz) |
| audioComponentType | integer | 音声コンポーネントタイプ (ARIB, 例: 1=モノラル/ステレオ, 3=2/0モード等) |

### Schedule

| Field | Type | Description |
|-------|------|--------------|
| channel | ScheduleChannelItem | チャンネル情報 |
| programs | ScheduleProgramItem[] | 番組一覧 |

### ReserveItem

| Field | Type | Description |
|-------|------|--------------|
| id | integer | 予約ID |
| ruleId | integer | 対応ルールID |
| isSkip | boolean | スキップ状態 |
| isConflict | boolean | 競合状態 |
| isOverlap | boolean | 重複状態 |
| allowEndLack | boolean | 末尾切れ許可 |
| isTimeSpecified | boolean | 時刻指定予約か |
| programId | integer | プログラムID |
| channelId | integer | チャンネルID |
| startAt | integer | 開始時刻 (UnixtimeMS) |
| endAt | integer | 終了時刻 (UnixtimeMS) |
| name | string | 番組名 |
| description | string | 番組詳細 |

### RecordedItem

| Field | Type | Description |
|-------|------|--------------|
| id | integer | 録画ID |
| ruleId | integer | 対応ルールID |
| programId | integer | プログラムID |
| channelId | integer | チャンネルID |
| startAt | integer | 開始時刻 (UnixtimeMS) |
| endAt | integer | 終了時刻 (UnixtimeMS) |
| name | string | 番組名 |
| description | string | 番組詳細 |
| isRecording | boolean | 録画中か |
| isEncoding | boolean | エンコード中か |
| isProtected | boolean | 自動削除対象外か |
| thumbnails | integer[] | サムネイルID一覧 |
| videoFiles | object[] | 動画ファイル一覧 |

### RuleSearchOption

番組検索 (`POST /schedules/search` の `option`) とルール検索
(`AddRuleOption.searchOption`) の両方で使われる共通スキーマ。

| Field | Type | Description |
|-------|------|--------------|
| keyword | string | 検索キーワード |
| ignoreKeyword | string | 除外キーワード |
| keyCS | boolean | キーワードの大文字小文字区別 |
| keyRegExp | boolean | キーワードを正規表現として扱う |
| ignoreKeyCS | boolean | 除外キーワードの大文字小文字区別 |
| ignoreKeyRegExp | boolean | 除外キーワードを正規表現として扱う |
| name | boolean | 番組名を検索対象に |
| ignoreName | boolean | 番組名を除外検索対象に |
| description | boolean | 概要を検索対象に |
| ignoreDescription | boolean | 概要を除外検索対象に |
| extended | boolean | 詳細を検索対象に |
| ignoreExtended | boolean | 詳細を除外検索対象に |
| GR | boolean | 地上波 |
| BS | boolean | BS |
| CS | boolean | CS |
| SKY | boolean | スカパー |
| channelIds | integer[] | チャンネルIDフィルタ |
| genres | Genre[] | ジャンルフィルタ `[{"genre": 7}]` |
| times | SearchTime[] | 曜日・時間帯フィルタ |
| isFree | boolean | 無料放送のみ |
| durationMin | integer | 最小時間 (秒) |
| durationMax | integer | 最大時間 (秒) |
| searchPeriods | SearchPeriod[] | 検索対象期間 `[{"startAt": ms, "endAt": ms}]` |

### RuleReserveOption

| Field | Type | Description |
|-------|------|--------------|
| enable | boolean | ルール有効/無効 |
| allowEndLack | boolean | 末尾切れ許可 |
| avoidDuplicate | boolean | 重複排除 |
| periodToAvoidDuplicate | integer | 重複排除期間 (日) |
| tags | integer[] | 付与するタグID一覧 |

### ReserveSaveOption

| Field | Type | Description |
|-------|------|--------------|
| parentDirectoryName | string | 保存先の親ディレクトリ名 (config で定義したエイリアス) |
| directory | string | サブディレクトリ |
| recordedFormat | string | ファイル名フォーマット (`%YEAR%%MONTH%...` 等のプレースホルダ) |

### ReserveEncodedOption

`AddRuleOption.encodeOption` / `EditManualReserveOption.encodeOption` で使う、録画後の
自動エンコード設定。

| Field | Type | Required | Description |
|-------|------|----------|--------------|
| mode1 / mode2 / mode3 | string | no | config で定義したエンコードプリセット名 (最大3段) |
| encodeParentDirectoryName1/2/3 | string | no | エンコード後ファイルの保存先親ディレクトリ |
| directory1/2/3 | string | no | エンコード後ファイルのサブディレクトリ |
| isDeleteOriginalAfterEncode | boolean | yes | エンコード後に元ファイルを削除するか |

### Genre (ARIB STD-B10)

| ID | ジャンル |
|----|---------|
| 0 | ニュース/報道 |
| 1 | スポーツ |
| 2 | 情報/ワイドショー |
| 3 | ドラマ |
| 4 | 音楽 |
| 5 | バラエティ |
| 6 | 映画 |
| 7 | アニメ/特撮 |
| 8 | ドキュメンタリー/教養 |
| 9 | 劇場/公演 |
| 10 | 趣味/教育 |
| 11 | 福祉 |
| 12 | 予備 (未使用) |
| 13 | 予備 (未使用) |
| 14 | 拡張 |
| 15 | その他 |

### UnixtimeMS

All timestamps are **Unix time in milliseconds** throughout the entire v2 API.
To convert:

```bash
# JS: Date to UnixtimeMS
node -e "console.log(new Date('2024-03-02T21:00:00+09:00').getTime())"

# jq: UnixtimeMS to readable (JST)
jq '.startAt / 1000 | strftime("%Y-%m-%d %H:%M")'
```
