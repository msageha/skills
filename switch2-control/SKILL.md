---
name: switch2-control
description: "Nintendo Switch 2 を LAN 上の HTTP API 経由で Pro Controller として操作する。ボタン入力・スティック・マクロ実行・接続管理。Switch 2 / ゲーム機の操作依頼で使用。"
metadata:
  openclaw:
    emoji: "🎮"
    requires:
      bins:
        - curl
---

# switch2-control

LAN 内の Raspberry Pi 上で稼働する nsbt HTTP API を通じて、Nintendo Switch 2 に Pro Controller の入力を送る。

Base URL: `http://172.16.1.108:8765` (認証ヘッダーは不要)。

## 要点

- 接続状態を聞かれただけなら、`GET /status` で観測した状態を答え、再接続はしない。
- 入力を送る前に `GET /status` で接続を確かめる。入力系は未接続でも `202` を返し、入力は黙って捨てられる (`/status` の `detail` に `not connected` が残る) ため。
- 接続状態は `connected` で判定する。`detail` には直近の操作の説明が残るだけで、今の状態を表さない。
- 接続の復旧を頼まれたときか、頼まれた入力を送るのに要るときに `connected: false` なら、`POST /reconnect` し、15〜60 秒おいて `/status` を確かめる (サーバー側も 60 秒間隔で自動再接続する)。再接続できるのは、Switch 2 が起動中 (スリープでない) で、「持ちかた/順番を変える」画面を開いていないときだけ (ホーム画面なら可)。
- 復旧しなければ api-reference のトラブルシューティングに従う。再ペアリングが要る場合は人間に依頼する。
- 入力系の `202 {"queued": ...}` はキューに入れたことだけを示し、実行の完了も Switch への到達も保証しない。この API には入力の効果を観測する手段が無いので、報告では「`202` で受け付けられた」と送信前の `connected` を伝え、「効いた」とは言わない。
- `home` (マクロ内では `HOME`) はゲームを中断してホーム画面に戻すので、ユーザーが指示したときだけ送る。
- `POST /connect` (新規ペアリング) は Switch 2 本体の画面操作が要り、エージェントだけでは完了できない。要るときは人間に依頼する。
- 0.3 秒より長くスティックを倒すときと、複数の入力を続けて送るときはマクロ (`POST /macro`) を使う。

## 主要操作

| 操作                                                    | Endpoint                            |
| ------------------------------------------------------- | ----------------------------------- |
| 接続状態                                                | `GET /status`                       |
| ボタンを 0.1 秒押す (`+` で同時押し、3 つ以上も可)      | `GET /press/<btns>`                 |
| ボタンを指定秒数押し続ける                              | `GET /hold/<btns>/<secs>`           |
| 十字キー                                                | `GET /dpad/<up\|down\|left\|right>` |
| スティックを 0.3 秒倒す (x, y は -100〜100、右・上が正) | `GET /stick/<l\|r>/<x>/<y>`         |
| マクロ (複数入力のシーケンス)                           | `POST /macro`                       |
| 登録済みの Switch へ再接続                              | `POST /reconnect`                   |

## ボタン名一覧

URL の `<btns>` で使う名前。マクロ内では大文字の別表記を使う (api-reference の「マクロ構文」)。

| 入力名                                    | 意味               |
| ----------------------------------------- | ------------------ |
| `a` `b` `x` `y`                           | A / B / X / Y      |
| `l` `r` `zl` `zr`                         | L / R / ZL / ZR    |
| `plus` (= `start`) / `minus` (= `select`) | + / −              |
| `home` / `capture`                        | HOME / キャプチャ  |
| `l3` / `r3`                               | スティック押し込み |
| `up` `down` `left` `right`                | 十字キー           |

エンドポイントの完全な仕様・マクロ構文 (LOOP / HOLD / スティック表記)・トラブルシューティングは [references/api-reference.md](references/api-reference.md)、そのまま実行できる curl の例は [references/commands.md](references/commands.md) にある。
