---
name: codex-fusion
description: Claude Code から codex MCP 経由で OpenRouter の fusion モデル（openrouter/fusion）を呼び出す方法。セカンドオピニオン・難しい設計やデバッグの相談・長時間のエージェント作業を fusion に委譲したいとき、または「fusion / openrouter のモデルで考えさせて」と頼まれたときに使う。CLI では `codex --profile fusion` で起動できる。
---

# codex で fusion（OpenRouter）を呼び出す

OpenRouter の **fusion**（`openrouter/fusion`、1M コンテキスト / high reasoning）に作業を委譲する手順。CLI では `codex --profile fusion` で起動でき、Claude Code からは codex MCP サーバー（ツール `mcp__codex__codex`）経由で呼ぶ。`gpt-5.5` などの既定モデルではなく fusion を確実に指定して呼ぶための設定をまとめる。

## いつ使うか

- 難しい設計判断・アーキテクチャ相談・込み入ったバグの根本原因分析を別モデルのセカンドオピニオンとして仰ぎたいとき。
- 多段のツール呼び出しを伴う長時間のエージェント作業（調査・実装・検証）を fusion に丸ごと任せたいとき。
- ユーザーが「fusion」「openrouter のモデル」で考えさせて、と明示したとき。

## CLI から（直接起動）

ターミナルで対話的に使う場合はプロファイル指定で起動できる。

```bash
codex --profile fusion
```

このプロファイルは `~/.codex/fusion.config.toml`（model `openrouter/fusion`、provider `openrouter`、catalog `~/.codex/fusion.json`、`features.image_generation = false`）に対応する。

## Claude Code から（MCP 経由）

`mcp__codex__codex` を以下のパラメータで呼ぶ。MCP ツールには `profile` パラメータが無いため、CLI の `--profile fusion` に相当する内容を `model` + `config` オーバーライドで再現する。`model` 単体では既定プロバイダに向くので、`config` でプロバイダ・カタログ・reasoning を併せて上書きするのが要点。

```jsonc
{
  "prompt": "<fusion に渡す最初の指示>",
  "model": "openrouter/fusion",
  "cwd": "/path/to/trusted/project",   // 信頼済みプロジェクト（後述）を指定
  "config": {
    "model_provider": "openrouter",
    "model_reasoning_effort": "high",
    "model_catalog_json": "~/.codex/fusion.json",
    "features": { "image_generation": false }
  }
}
```

会話を継続する場合は `mcp__codex__codex-reply` に、初回応答で返ってきた `threadId` と次の `prompt` を渡す。継続呼び出しでは `model` / `config` を再指定する必要はない（スレッドが設定を保持する）。

```jsonc
{ "threadId": "<初回応答の thread id>", "prompt": "<続きの指示>" }
```

## 各パラメータの意味

- `model: "openrouter/fusion"` — カタログ `~/.codex/fusion.json` に定義された slug。
- `model_provider: "openrouter"` — `~/.codex/config.toml` の `[model_providers.openrouter]`（`base_url = https://openrouter.ai/api/v1`、`env_key = OPENROUTER_API_KEY`、`wire_api = responses`）を指す。これを指定しないと既定プロバイダに向いて fusion に届かない。
- `model_catalog_json: "~/.codex/fusion.json"` — fusion の定義（context_window 1M、対応 reasoning effort など）を読ませる。
- `model_reasoning_effort: "high"` — fusion がサポートする reasoning レベル（カタログ上 high のみ）。
- `features.image_generation: false` — **必須**。省略すると API が tools 非対応で `Invalid value: 'image_generation'` の 400 を返す。

## 前提条件

- **`OPENROUTER_API_KEY`** が codex MCP サーバー（および CLI）の起動環境に設定されていること。`~/.codex/.env` 等で供給される。未設定だと認証エラーになる。
- `~/.codex/config.toml` に `[model_providers.openrouter]` が定義済みであること（MCP がここを読む）。プロバイダ定義そのものは `config` オーバーライドではなく config.toml 側に必要。
- `~/.codex/fusion.json`（モデルカタログ）と `~/.codex/fusion.config.toml`（CLI の `--profile fusion` が読む config 全体差し替え版）が存在すること。
- `cwd` に渡すプロジェクトが codex 側で信頼済み（`trust_level = "trusted"`）だと、サンドボックス/承認まわりで引っかからずに動く。`approval_policy = "never"` / `sandbox_mode = "workspace-write"` が既定。

## 落とし穴・注意

- **MCP には `profile` パラメータが無い**。CLI の `--profile fusion` は MCP からは選べないため、上記の `model` + `config` オーバーライドで同等内容を再現する。
- **`features.image_generation: false` を必ず入れる**。最も踏みやすい 400 エラー要因。
- **同期・長時間ブロッキング**。`mcp__codex__codex` は codex の1ターン全体（多段のツール呼び出し・reasoning を含む）が終わるまで返らない。fusion + high reasoning では数十分かかることがあり、その間 Claude 側は応答待ちで無音になる。固まって見えても、API への TLS 接続と `~/.codex/sessions/.../rollout-*.jsonl`・`state_5.sqlite-wal` の mtime が更新され続けていれば正常進行。
- **応答の自己申告モデル名に惑わされない**。OpenRouter 経由のモデルは自分を別名で名乗ることがあるが、モデル指定が効いていないわけではない。確証が要るなら rollout の `"model":"openrouter/fusion"` を確認する。

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

## 関連

- 同じ仕組みで Sakana の fugu-ultra を呼ぶ手順は `codex-fugu-ultra` skill を参照（provider が `sakana`、env_key が `SAKANA_API_KEY`、catalog が `~/.codex/fugu.json` になる点だけ異なる）。`~/.codex/` には他に `owl-alpha` / `pareto-code` も同形式（`NAME.config.toml` + `NAME.json`、provider `openrouter`）で用意されている。
