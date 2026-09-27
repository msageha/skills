---
name: codex-model-profiles
description: codex CLI の model profile (`--profile`) で既定以外のモデル (Sakana の fugu-ultra / fugu-cyber、OpenRouter の fusion / pareto-code) に調査・設計レビュー・デバッグ・実装を委譲する方法。別モデルのセカンドオピニオンが欲しいとき、長時間のエージェント作業を任せたいとき、または「fugu / torafugu / sakana / fusion / pareto / openrouter のモデルで考えさせて」と頼まれたときに使う。
---

# codex の model profile で別モデルを呼ぶ

codex CLI の `--profile <name>` (`-p`) は `$CODEX_HOME/<name>.config.toml` (既定 `~/.codex/`) を base config (`config.toml`) に重ねる。profile 1 つがモデル・provider・モデルカタログ・`features.image_generation = false` をまとめて切り替えるので、呼び出し側は profile 名だけ指定すればよい。

## profile 一覧

| profile       | model                    | provider / API key の環境変数       | 特徴                                                                 |
| ------------- | ------------------------ | ----------------------------------- | -------------------------------------------------------------------- |
| `fugu`        | `fugu-ultra`             | `sakana` / `SAKANA_API_KEY`         | Sakana fugu-ultra。1M context。軽量版 `fugu-mini` も同カタログにある |
| `fugu-cyber`  | `fugu-cyber`             | `fugu_cyber` / `FUGU_PAYG_API_KEY`  | Sakana PAYG 版の fugu。1M context                                    |
| `fusion`      | `openrouter/fusion`      | `openrouter` / `OPENROUTER_API_KEY` | 1M context                                                           |
| `pareto-code` | `openrouter/pareto-code` | `openrouter` / `OPENROUTER_API_KEY` | 2M context。text 入力のみ (画像は渡せない)                           |

全 profile 共通で reasoning effort は `high` (カタログ上 high のみ)、`features.image_generation = false` (これらの API は image_generation tool 非対応で、有効のままだと 400 `Invalid value: 'image_generation'` になる)。正本は各 `<name>.config.toml` と `<name>.json` で、この表は選択の案内。

## いつ使うか

- 難しい設計判断・アーキテクチャ相談・込み入ったバグの根本原因分析を、別モデルのセカンドオピニオンとして仰ぎたいとき。
- 多段のツール呼び出しを伴う長時間のエージェント作業 (調査・実装・検証) を丸ごと任せたいとき。
- ユーザーがモデル名 (fugu / fusion / pareto など) を明示したとき。

## 呼び出し方

### ターミナルで対話する

```bash
codex --profile fusion
```

### Claude Code から委譲する (非対話)

```bash
profile=fugu
[ -f "${CODEX_HOME:-$HOME/.codex}/$profile.config.toml" ] || { echo "unknown profile: $profile" >&2; exit 1; }
out=$(mktemp -d /tmp/codex-out.XXXXXX)
# $out/prompt.md にプロンプトを書いてから:
codex exec -p "$profile" -s read-only -C /path/to/project \
  -o "$out/answer.md" - < "$out/prompt.md" > "$out/run.log" 2>&1
```

- **実行前に profile の存在を確認し、無ければ止める。** 存在しない名前はエラーにならず、base config の既定モデルで実行される (無言フォールバック)。
- プロンプトはファイルに書き、`-` で stdin から読ませる。引数で渡す場合は stdin を `</dev/null` で閉じる。stdin が開いたままだと (バックグラウンド実行など) 追加入力の EOF を待ち続けてセッションが始まらない。
- `-s read-only` は相談・レビュー向け。編集まで任せるなら `-s workspace-write`。
- プロンプトと出力先は委譲ごとに分ける。並列に走らせると同じ `prompt.md` / `run.log` / `answer.md` を上書きし合い、読み込み中のプロンプトに後続の指示が混ざる。
- `run.log` の先頭に `model:` / `provider:` / `sandbox:` / `session id:` が出る。まずここで意図した profile が効いていることを確認する。
- 最終回答は `-o` のファイルに書かれる。数十分かかることがあるのでバックグラウンドで実行し、完了後にファイルを読む。
- 続きを頼むときは `codex exec -p "$profile" -s read-only resume <session id> "<続きの指示>"`。resume が引き継ぐのは会話だけで、`-p` / `-s` を省くと model と sandbox は base config (既定モデル・`workspace-write`) に戻る。`resume --last` は並列に走らせた別セッションを拾い得るので使わない。
- `codex review` には `--profile` が無い。別モデルにレビューさせるときは `codex exec -p` にレビュー依頼を書く。

## 前提条件

- API key の環境変数が codex プロセスの環境にあること (`~/.codex/.env` で供給)。未設定だと認証エラーになる。
- `config.toml` の `[model_providers.<provider>]` に provider (`name` / `base_url` / `env_key` / `wire_api = "responses"` / `stream_idle_timeout_ms = 600000`) が定義されていること。profile 側 (`<name>.config.toml`) が持つのは `model` / `model_provider` / `model_catalog_json` / `model_reasoning_effort` / `[features]` だけ。
- `<name>.json` (モデルカタログ: slug・context_window・対応 reasoning effort) があること。
- 作業ディレクトリが codex 側で信頼済み (`[projects."<path>"] trust_level = "trusted"`。この環境で trusted なのは `~/Works/src` と `~/.local/share/chezmoi`) で、`config.toml` に `approval_policy = "never"` があること。承認待ちで止まらない前提はこれに依存する。

新しいモデルを足すときは `<name>.config.toml` と `<name>.json` を既存のものに倣って作り、上の表に 1 行追加する。

## 生存確認

```bash
pgrep -fl 'codex exec'   # プロセスが生きているか
tail -n 5 "$out/run.log" # イベントが増えているか
```

プロセスが無く `answer.md` も無ければ異常終了。`run.log` の末尾でエラーを確認する。応答本文でモデルが名乗る名前 (「Fugu orchestration system の worker agent」等) は検証の根拠にせず、`run.log` 先頭の `model:` を見る。
