# switch2-control リファレンス

nsbt HTTP API(Raspberry Pi 上の `nsbt.service`)の完全な仕様。ベース URL: `http://172.16.1.108:8765`

## エンドポイント一覧

### GET /status — 接続状態の取得

```json
{"controller": "connected", "connected": true, "detail": "reconnecting to ...", "switch": "3C:A9:AB:23:1B:35"}
```

| フィールド | 意味 |
|---|---|
| `connected` | **接続状態の正**。`true` なら入力を送れる |
| `controller` | 内部状態 (`ready` / `connecting` / `reconnecting` / `connected` / `crashed`) |
| `detail` | 直近の操作やエラーの説明。**過去の情報が残るので状態判定に使わない** |
| `switch` | 再接続対象の Switch の Bluetooth MAC |

### 入力系(すべて非同期、202 = キュー投入)

| エンドポイント | 動作 |
|---|---|
| `GET /press/<btns>` | ボタンを 0.1 秒押す。`+` または `,` で同時押し(例 `/press/l+r`) |
| `GET /hold/<btns>/<secs>` | ボタンを指定秒数押し続ける(例 `/hold/a/2`) |
| `GET /dpad/<up\|down\|left\|right>` | 十字キーを 0.1 秒押す |
| `GET /stick/<l\|r>/<x>/<y>` | スティックを 0.3 秒倒す。x, y は -100〜100(右・上が正) |
| `GET /macro?m=<urlencoded>` | マクロ実行(URL エンコード必須) |
| `POST /macro` | マクロ実行。body は raw テキストまたは `{"macro": "..."}`。`;` は改行に変換 |
| `POST /press` | `{"buttons": ["a","b"], "secs": "0.5"}` 形式でも押せる |

**重要**: 202 レスポンスはキュー投入のみを意味する。未接続時は入力が捨てられ、`/status` の `detail` に `not connected` が記録される。確実を期すなら操作前後に `/status` を確認する。

### 接続管理系

| エンドポイント | 動作 |
|---|---|
| `POST /reconnect` | 登録済み Switch へ再接続(MAC 省略時はデフォルト)。`?mac=XX:..` で対象指定可 |
| `POST /connect` | **新規ペアリングモード**。Switch 2 側で「持ちかた/順番を変える」画面を開く必要がある(人間の操作が必要) |
| `POST /disconnect` | コントローラーを切断・破棄(自動再接続も停止する) |

## マクロ構文

1 行 = 1 ステップ。行は「入力 時間」の形式。

```
# コメント行(# 始まり)
A 0.1s              ← A を 0.1 秒押す
A B 0.1s            ← A と B を同時に 0.1 秒押す(スペース区切り = 同時押し)
0.5s                ← 何も押さずに 0.5 秒待つ(ウェイト)
L_STICK@+100+000 1.0s   ← 左スティックを右に 1 秒倒す
R_STICK@-050-050 0.3s   ← 右スティックを左下(半分の倒し)に 0.3 秒
```

- ボタン名はマクロ内では**大文字表記**: `A B X Y L R ZL ZR PLUS MINUS HOME CAPTURE L_STICK_PRESS R_STICK_PRESS DPAD_UP DPAD_DOWN DPAD_LEFT DPAD_RIGHT`
- スティック表記は `L_STICK@<±xxx><±yyy>`: 符号必須・3 桁ゼロ埋め(例 `+100`, `-071`, `+000`)。範囲 -100〜100
- スティックとボタンの同時入力も 1 行に併記できる: `L_STICK@+100+000 A 0.5s`

### LOOP(繰り返し)

`LOOP n` の次行以降、**インデント**(タブまたはスペース 2/4 個)した行が n 回繰り返される:

```
LOOP 5
	A 0.1s
	0.3s
B 0.1s          ← インデントなし = ループ外
```

### HOLD(押しっぱなし)

`HOLD <ボタン>` の次行以降、インデントした行の実行中ずっと指定ボタンが押される:

```
HOLD ZL
	L_STICK@+100+000 1.0s
	A 0.1s
```

### 送信方法の使い分け

```bash
# 単純なシーケンス: ; 区切りで OK(; → 改行に変換される)
curl -s -X POST http://172.16.1.108:8765/macro -d 'A 0.1s;0.5s;B 0.1s'

# LOOP / HOLD はインデントが必要なので改行入りの body で送る
curl -s -X POST http://172.16.1.108:8765/macro \
  --data-binary $'LOOP 3\n\tA 0.1s\n\t0.3s'

# JSON 形式でも可
curl -s -X POST http://172.16.1.108:8765/macro \
  -H 'Content-Type: application/json' \
  -d '{"macro": "HOLD ZL\n\tA 0.1s\n\t0.3s"}'
```

## トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `connected: false` | 一時的な切断 | `POST /reconnect` → 15〜60 秒待って `/status` 再確認。サーバー側でも 60 秒間隔で自動再接続している |
| `/reconnect` 後も `connecting`/`reconnecting` のまま | Switch 2 がスリープまたは電源オフ | Switch 2 本体の起動が必要(人間に依頼)。起動すれば自動で復帰する |
| 同上 | Switch 2 が「持ちかた/順番を変える」画面 | その画面では再接続不可。ホーム画面等に戻してもらう |
| 何度 `/reconnect` しても復帰しない(数分以上) | Switch 2 側のコントローラー登録消失、または Bluetooth リンクキー不整合 | **エージェントでは復旧不可。Pi の管理者(人間)にエスカレーション**。再ペアリングと Pi 側のリンクキー再登録が必要 |
| `controller: crashed` | nuxbt 内部エラー | 自動リトライで復帰を待つ。繰り返す場合は人間にエスカレーション(サービス再起動が必要) |
| 入力を送ったのに Switch が反応しない | 送信時点で未接続(202 は到達保証ではない) | `/status` で `connected: true` と `detail` を確認してから再送 |

## 制約・既知の仕様

- 同時に接続できる Switch は 1 台(コントローラー 1 個)
- ペアリング(`POST /connect`)は Switch 2 本体の画面操作を伴うため、エージェント単独では完了できない
- Switch 2 はコントローラー再接続時に Bluetooth リンクキー認証を要求する。リンクキーは Pi 側に登録済みだが、**Switch 2 と再ペアリングするとキーが変わり、管理者によるキー再登録が必要になる**
- API に認証は無い(LAN 内限定運用)。`NSBT_TOKEN` 環境変数を設定すれば Bearer トークン認証を有効化できる(サーバー側設定)
