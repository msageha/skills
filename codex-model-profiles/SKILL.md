---
name: codex-model-profiles
description: codex CLI の model profile (`--profile`) で既定以外のモデル (Sakana の fugu-ultra / fugu-cyber) を呼ぶ方法。ユーザーがこれらのモデルを名指ししたとき (「fugu / torafugu / sakana のモデルで考えさせて」) や、委譲先に指定したときに使う。ふだんの相談・独立レビューでの別モデルには使わない。Codex の中からは使わない。
---

# codex の model profile で別モデルを呼ぶ

codex CLI の `--profile <name>` (`-p`) は `$CODEX_HOME/<name>.config.toml` (既定 `~/.codex/`) を base config (`config.toml`) に重ねる。profile 1 つがモデル・provider・モデルカタログ・`features.image_generation = false` をまとめて切り替えるので、呼び出し側は profile 名だけ指定すればよい。

## profile 一覧

| profile      | model        | provider / API key の環境変数      | 特徴                                                                 |
| ------------ | ------------ | ---------------------------------- | -------------------------------------------------------------------- |
| `fugu`       | `fugu-ultra` | `sakana` / `SAKANA_API_KEY`        | Sakana fugu-ultra。1M context。軽量版 `fugu-mini` も同カタログにある |
| `fugu-cyber` | `fugu-cyber` | `fugu_cyber` / `FUGU_PAYG_API_KEY` | Sakana PAYG 版の fugu。1M context                                    |

全 profile 共通で reasoning effort は `high` (カタログ上 high のみ)、`features.image_generation = false` (これらの API は image_generation tool 非対応で、有効のままだと 400 `Invalid value: 'image_generation'` になる)。正本は dotfiles の source にある profile とモデルカタログで、この表は選択の案内。

## いつ使うか

- ユーザーが fugu などのモデルを名指しして、相談・設計レビュー・原因分析を頼んだとき。送り先が既定の codex とは別の provider (Sakana の API) になるので、名指しが無ければ使わない。ふだんの相談・独立レビューでの別モデルは、各ツールの既定の手段で呼ぶ。
- ユーザーが、これらのモデルに調査・実装・検証を任せると指定したとき。指定が無ければ、方針の決定と実装は任せない。
- Codex の中からは使わない (Codex の中から `codex exec` を起動しない)。

## 呼び出し方

### ターミナルで対話する

```bash
codex --profile fugu
```

### ほかのエージェントから委譲する (非対話)

まず profile の存在を確かめ、無ければ止める。存在しない名前はエラーにならず、base config の既定モデルで実行される (無言のフォールバック)。

```bash
test -f "${CODEX_HOME:-$HOME/.codex}/<profile>.config.toml"
```

委譲ごとに出力先のディレクトリ (`<out-dir>`。`mktemp -d` で作る) を分け、プロンプトを `<out-dir>/prompt.md` に書いてから起動する。

```bash
codex exec -p "<profile>" -s read-only --ignore-rules -C "<project-dir>" -o "<out-dir>/answer.md" - < "<out-dir>/prompt.md" > "<out-dir>/run.log" 2>&1
```

- プロンプトの冒頭に、ほかのエージェントからの依頼で、結果を呼び出し元へ返せばよいことを書く。相談・レビュー・調査だけを頼むときは、その旨も書く。書かないと、受け手は自分をユーザーに成果物を返す側とみなし、相談・独立レビューを起こし直しうる。ユーザーが明示しない限り、commit / push はさせないとも書く。
- プロンプトはファイルに書き、`-` で stdin から読ませる。引数では渡さない。
- `-C` の先が git リポジトリでなければ `--skip-git-repo-check` を足す (無いと codex exec は開始せずに終了する)。
- `-s read-only` は相談・レビュー向け。編集まで任せる (ユーザーが指定したとき) なら `-s workspace-write` にする。どちらでも `--ignore-rules` を付ける。`~/.codex/rules/` の allow に一致するコマンド (git commit 等) は、sandbox の外で実行されるため。
- 並列に走らせるときも出力先を分ける。同じ `prompt.md` / `run.log` / `answer.md` を共有すると上書きし合い、読み込み中のプロンプトに後続の指示が混ざる。
- `run.log` の先頭に `model:` / `provider:` / `approval:` / `sandbox:` / `session id:` が出る。まずここで、意図した profile が効いていることを確かめる。`approval:` は通常 `never` で、承認待ちでは止まらない (`approvals_reviewer` を自動レビューにした構成では config の `approval_policy` が使われる)。
- 最終回答は `-o` のファイルに書かれる。数十分かかることがあるのでバックグラウンドで実行する。完了は、起動したプロセスの終了コードが 0 であることを確かめ、`run.log` の途中の Error・Warning まで読んで結果に影響したかを判断し、回答を読んで依頼した完了条件を満たしているかで判定する (`answer.md` は起動の直後に作られうるので、あることだけでは完了と言えない)。
- 続きを頼むときは、続きの指示を新しい出力先のファイルに書き、初回と同じ `-C`・`-s` (編集を任せた委譲なら `workspace-write`)・`--skip-git-repo-check` (初回に付けたなら) を付けて `codex exec -p "<profile>" -s read-only --ignore-rules -C "<project-dir>" -o "<new-out-dir>/answer.md" resume "<session-id>" - < "<new-out-dir>/prompt.md" > "<new-out-dir>/run.log" 2>&1` で渡す。resume が引き継ぐのは会話だけで、`-p` / `-s` / `--ignore-rules` を省くと、model と sandbox は base config (既定モデル・`workspace-write`) に戻り、`~/.codex/rules/` も読み込まれる。`resume --last` は並列に走らせた別セッションを拾いうるので使わない。
- コードレビューは `codex exec -p "<profile>" -s read-only --ignore-rules review - < "<prompt-file>"` で頼む (トップレベルの `codex review` には `--profile` が無い)。対象範囲と検証の結果はプロンプトに書く。profile が効いたかは `run.log` の `model:` で確かめる。

## 前提条件

- `<name>.config.toml` が、使う codex の `$CODEX_HOME` (既定 `~/.codex/`) の下にあること。`CODEX_HOME` ごとに別で、無い `CODEX_HOME` では上の存在確認で止まる。
- API key の環境変数が codex プロセスの環境にあること (`$CODEX_HOME/.env` で供給。既定 `~/.codex/.env`)。未設定だと認証エラーになる。`.env` は secret ファイルなので中身を読まず、切り分けるときは、profile の provider が指定するキー名 (上の表の環境変数) の有無だけを確かめる (`grep -c '^<env-key>=' "<env-file>"`)。
- `config.toml` の `[model_providers.<provider>]` に provider (`name` / `base_url` / `env_key` / `wire_api = "responses"` / `stream_idle_timeout_ms = 600000`) が定義されていること。profile 側 (`<name>.config.toml`) が持つのは `model` / `model_provider` / `model_catalog_json` / `model_reasoning_effort` / `[features]` だけ。
- profile の `model_catalog_json` が指す `<name>.json` (モデルカタログ: slug・context_window・対応 reasoning effort) があること。

新しいモデルを足すときは、`$CODEX_HOME` の下を直接編集せず、dotfiles の source に profile とカタログを既存のものに倣って足して apply し、上の表に 1 行追加する。

## 生存確認

プロセスが生きているかは `pgrep -fl 'codex exec'`、イベントが増えているかは `tail -n 5 "<out-dir>/run.log"` で見る。

プロセスが非ゼロで終わったか、`run.log` の末尾にエラーがあれば異常終了で、`answer.md` があっても完了ではない。応答本文でモデルが名乗る名前 (「Fugu orchestration system の worker agent」等) は検証の根拠にせず、`run.log` 先頭の `model:` を見る。
