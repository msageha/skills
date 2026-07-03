---
name: codex-fugu-ultra
description: Claude Code から codex MCP 経由で Sakana の fugu-ultra モデルを呼び出す方法。セカンドオピニオン・難しい設計やデバッグの相談・長時間のエージェント作業を fugu-ultra に委譲したいとき、または「fugu / fugu-ultra / torafugu / sakana のモデルで考えさせて」と頼まれたときに使う。
---

# codex MCP で fugu-ultra を呼び出す

Claude Code から codex MCP サーバー（ツール `mcp__codex__codex`）を使い、Sakana の **fugu-ultra**（1M コンテキスト / high reasoning）に作業を委譲する手順。`gpt-5.5` などの既定モデルではなく fugu-ultra を確実に指定して呼ぶための設定をまとめる。

## いつ使うか

- 難しい設計判断・アーキテクチャ相談・込み入ったバグの根本原因分析を別モデルのセカンドオピニオンとして仰ぎたいとき。
- 多段のツール呼び出しを伴う長時間のエージェント作業（調査・実装・検証）を fugu-ultra に丸ごと任せたいとき。
- ユーザーが「fugu」「fugu-ultra」「torafugu」「sakana のモデル」で考えさせて、と明示したとき。

## 呼び出し方法

`mcp__codex__codex` を以下のパラメータで呼ぶ。`model` 単体では既定プロバイダに向くため、`config` でプロバイダ・カタログ・reasoning を併せて上書きするのが要点。

```jsonc
{
  "prompt": "<fugu-ultra に渡す最初の指示>",
  "model": "fugu-ultra",
  "cwd": "/path/to/trusted/project",   // 信頼済みプロジェクト（後述）を指定
  "config": {
    "model_provider": "sakana",
    "model_reasoning_effort": "high",
    "model_catalog_json": "~/.codex/fugu.json",
    "features": { "image_generation": false }
  }
}
```

会話を継続する場合は `mcp__codex__codex-reply` に、初回応答で返ってきた `threadId` と次の `prompt` を渡す。継続呼び出しでは `model` / `config` を再指定する必要はない（スレッドが設定を保持する）。

```jsonc
{ "threadId": "<初回応答の thread id>", "prompt": "<続きの指示>" }
```

## 各パラメータの意味

- `model: "fugu-ultra"` — カタログ `~/.codex/fugu.json` に定義された slug。軽量版が必要なら `fugu-mini` も同カタログにある。
- `model_provider: "sakana"` — `~/.codex/config.toml` の `[model_providers.sakana]`（`base_url = https://api.torafugu.app/v1`、`env_key = SAKANA_API_KEY`、`wire_api = responses`）を指す。これを指定しないと既定プロバイダに向いて fugu に届かない。
- `model_catalog_json: "~/.codex/fugu.json"` — fugu-ultra / fugu-mini の定義（context_window 1M、対応 reasoning effort など）を読ませる。
- `model_reasoning_effort: "high"` — fugu-ultra がサポートする reasoning レベル（カタログ上 high のみ）。
- `features.image_generation: false` — **必須**。省略すると API が tools 非対応で `Invalid value: 'image_generation'` の 400 を返す。

## 前提条件

- **`SAKANA_API_KEY`** が codex MCP サーバーの起動環境に設定されていること。`~/.codex/.env` 等で供給される。未設定だと認証エラーになる。
- `~/.codex/config.toml` に `[model_providers.sakana]` が定義済みであること（MCP がここを読む）。プロバイダ定義そのものは `config` オーバーライドではなく config.toml 側に必要。
- `~/.codex/fugu.json`（モデルカタログ）と、参照する場合は `~/.codex/fugu.config.toml`（fugu 用の config 全体差し替え版）が存在すること。
- `cwd` に渡すプロジェクトが codex 側で信頼済み（`trust_level = "trusted"`）だと、サンドボックス/承認まわりで引っかからずに動く。`approval_policy = "never"` / `sandbox_mode = "workspace-write"` が既定。

## 落とし穴・注意

- **`--profile fugu` は使えない**。MCP ツールに `profile` パラメータが無く、config.toml にも `[profiles.fugu]` 定義が無い。fugu 設定は独立ファイル `~/.codex/fugu.config.toml` にあるが MCP からは直接選べないため、上記の `config` オーバーライドで再現する。
- **`features.image_generation: false` を必ず入れる**。最も踏みやすい 400 エラー要因。
- **同期・長時間ブロッキング**。`mcp__codex__codex` は codex の1ターン全体（多段のツール呼び出し・reasoning を含む）が終わるまで返らない。fugu-ultra + high reasoning では数十分かかることがあり、その間 Claude 側は応答待ちで無音になる。固まって見えても、API への TLS 接続と `~/.codex/sessions/.../rollout-*.jsonl`・`state_5.sqlite-wal` の mtime が更新され続けていれば正常進行。
- **応答の自己申告モデル名に惑わされない**。fugu-ultra は自分を「Fugu orchestration system の worker agent」等と名乗ることがあるが、これは personality/システムプロンプト由来であり、モデル指定が効いていないわけではない。確証が要るなら rollout の `"model":"fugu-ultra"` を確認する。

## 生存確認（ハングか作業中かの切り分け）

長時間返ってこないとき、止まっているのか作業中なのかは以下で判定できる。

```bash
# 最新の codex セッションログの更新時刻（数秒〜数十秒前なら生きている）
find ~/.codex/sessions -name '*.jsonl' -exec stat -f '%Sm %N' -t '%H:%M:%S' {} \; | sort | tail -3
ls -lT ~/.codex/state_5.sqlite-wal ~/.codex/logs_2.sqlite-wal

# codex mcp-server プロセスが API へ接続を張っているか
CODEX_PID=$(pgrep -f 'codex mcp-server' | head -1)
lsof -nP -p "$CODEX_PID" -i 2>/dev/null | grep ESTABLISHED

# 使用モデルの確認（アクティブな rollout 内）
F=$(find ~/.codex/sessions -name '*.jsonl' -exec stat -f '%m %N' {} \; | sort -n | tail -1 | cut -d' ' -f2-)
grep -oE '"model"[: ]*"[^"]*"' "$F" | sort | uniq -c
```

mtime が更新され続け API 接続が ESTABLISHED なら作業中。更新が完全に止まり接続も無ければハングの可能性が高い。`approval_policy = "never"` のためユーザー承認待ちで止まることは構造上発生しない。
