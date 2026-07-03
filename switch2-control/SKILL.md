---
name: switch2-control
description: "Nintendo Switch 2 を LAN 上の HTTP API 経由で Pro Controller として操作する。ボタン入力・スティック・マクロ実行・接続管理。Switch 2 / ゲーム機の操作依頼で使用。"
allowed-tools: Bash
---

# switch2-control

LAN 内の Raspberry Pi 上で稼働する nsbt HTTP API を通じて、Nintendo Switch 2 に Pro Controller の入力を送る。

```
ベース URL: http://172.16.1.108:8765
```

> 詳細な API 仕様・マクロ構文・トラブルシューティングは同ディレクトリの `reference.md` を参照。

## 必須フロー: 操作前の接続確認

入力を送る前に**必ず**接続状態を確認する:

```bash
curl -s http://172.16.1.108:8765/status
# => {"controller": "connected", "connected": true, ...}
```

- `connected: true` → 操作可能
- `connected: false` → 「接続管理」セクションの手順で復旧してから操作する
- 注意: `detail` フィールドは直近の操作説明が残るだけ。**接続状態の正は `connected` フィールド**

## 主要操作

### ボタンを押す(0.1 秒押下)

```bash
curl -s http://172.16.1.108:8765/press/a        # A ボタン
curl -s http://172.16.1.108:8765/press/l+r      # L+R 同時押し(+ で連結)
curl -s http://172.16.1.108:8765/press/zl+zr+a  # 3 つ以上の同時押しも可
```

### ボタン長押し

```bash
curl -s http://172.16.1.108:8765/hold/b/2       # B を 2 秒長押し
curl -s http://172.16.1.108:8765/hold/l+r/1.5   # 同時長押し
```

### 十字キー

```bash
curl -s http://172.16.1.108:8765/dpad/up        # up / down / left / right
```

### スティック(0.3 秒倒す)

```bash
# /stick/<l|r>/<x>/<y>  x, y は -100〜100(右・上が正)
curl -s http://172.16.1.108:8765/stick/l/100/0   # 左スティックを右に
curl -s http://172.16.1.108:8765/stick/r/0/-100  # 右スティックを下に
```

0.3 秒より長く倒す・連続操作する場合はマクロを使う。

### マクロ(複数入力のシーケンス)

```bash
# ; が改行に変換される。行 = 「入力 時間」、数値だけの行はウェイト
curl -s -X POST http://172.16.1.108:8765/macro \
  -d 'L_STICK@+100+000 1.0s;A B 0.1s;0.5s;ZL ZR 0.3s'

# LOOP / HOLD などインデントが必要な構文は改行入りで送る
curl -s -X POST http://172.16.1.108:8765/macro \
  --data-binary $'LOOP 3\n\tA 0.1s\n\t0.3s'
```

構文の詳細(LOOP / HOLD / スティック表記)は `reference.md` 参照。

## ボタン名一覧

| 入力名 | 意味 |
|---|---|
| `a` `b` `x` `y` | A / B / X / Y |
| `l` `r` `zl` `zr` | L / R / ZL / ZR |
| `plus` (= `start`) / `minus` (= `select`) | + / − |
| `home` / `capture` | HOME / キャプチャ |
| `l3` / `r3` | スティック押し込み |
| `up` `down` `left` `right` | 十字キー |

## 接続管理

`connected: false` のときの復旧手順:

```bash
# 1. 再接続を要求
curl -s -X POST http://172.16.1.108:8765/reconnect

# 2. 数秒〜60 秒待って確認(サーバー側にも 60 秒間隔の自動再接続あり)
sleep 15 && curl -s http://172.16.1.108:8765/status
```

- Switch 2 本体が**起動中(スリープでない)**ことが再接続の条件
- Switch 2 が「持ちかた/順番を変える」画面のままだと再接続できない(ホーム画面なら OK)
- 復旧しない場合は `reference.md` のトラブルシューティングを参照。再ペアリングが必要なケースは**人間にエスカレーション**する

## 注意事項

- 入力系 API のレスポンス `202 {"queued": ...}` は**キュー投入**を意味するだけで、実行完了・Switch への到達を保証しない。未接続時は入力が黙って捨てられる(`/status` の `detail` に `not connected` が記録される)
- `home` はゲームを中断してホーム画面に戻る副作用がある。ユーザーの指示なしに送らない
- `POST /connect`(新規ペアリング)は Switch 2 本体の画面操作が必要なため、エージェント単独では完了できない。必要時は人間に依頼する
