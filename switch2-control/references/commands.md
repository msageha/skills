# switch2-control コマンド例

そのまま実行できる `curl` の例。エンドポイントの仕様とマクロ構文は [api-reference.md](api-reference.md) にある。Base URL: `http://172.16.1.108:8765`。入力系の例は、`/status` で `connected: true` を確かめてから送る前提で書いている。例は `curl -sSf` で送るので、接続できないときと HTTP status が 400 以上のときは非ゼロで終わる (入力系は成功すると `202` で `{"queued": ...}` を返す)。

## 接続状態の確認

```bash
curl -sSf http://172.16.1.108:8765/status
# => {"controller": "connected", "connected": true, ...}
```

## 再接続

接続の復旧を頼まれたときか、頼まれた入力を送るのに要るときに、`connected: false` なら送る。

```bash
curl -sSf -X POST http://172.16.1.108:8765/reconnect
```

再接続には数秒〜60 秒かかる。15 秒ほどおいてから `/status` を確かめ、まだ `false` なら間隔をおいて再確認する。

```bash
curl -sSf http://172.16.1.108:8765/status
```

## ボタンを押す (0.1 秒押下)

```bash
curl -sSf http://172.16.1.108:8765/press/a        # A ボタン
curl -sSf http://172.16.1.108:8765/press/l+r      # L+R 同時押し (+ で連結)
curl -sSf http://172.16.1.108:8765/press/zl+zr+a  # 3 つ以上の同時押しも可
```

## ボタン長押し

```bash
curl -sSf http://172.16.1.108:8765/hold/b/2       # B を 2 秒長押し
curl -sSf http://172.16.1.108:8765/hold/l+r/1.5   # 同時長押し
```

## 十字キー

```bash
curl -sSf http://172.16.1.108:8765/dpad/up        # up / down / left / right
```

## スティック (0.3 秒倒す)

```bash
# /stick/<l|r>/<x>/<y>  x, y は -100〜100 (右・上が正)
curl -sSf http://172.16.1.108:8765/stick/l/100/0   # 左スティックを右に
curl -sSf http://172.16.1.108:8765/stick/r/0/-100  # 右スティックを下に
```

## マクロ (複数入力のシーケンス)

```bash
# 単純なシーケンスは ; 区切りで送る (; は改行に変換される)。行 = 「入力 時間」、数値だけの行はウェイト
curl -sSf -X POST http://172.16.1.108:8765/macro \
  -d 'L_STICK@+100+000 1.0s;A B 0.1s;0.5s;ZL ZR 0.3s'

# LOOP / HOLD はインデントが要るので改行入りの body で送る
curl -sSf -X POST http://172.16.1.108:8765/macro \
  --data-binary $'LOOP 3\n\tA 0.1s\n\t0.3s'

# JSON 形式でも送れる
curl -sSf -X POST http://172.16.1.108:8765/macro \
  -H 'Content-Type: application/json' \
  -d '{"macro": "HOLD ZL\n\tA 0.1s\n\t0.3s"}'
```
