# skills

[Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) 集。Claude Code / Codex / Antigravity / OpenClaw / Grok から使う (Grok は `~/.claude/skills` と `~/.agents/skills` を読むので、`install-claude` か `install-codex` の配置を使う)。

## Skills

| Skill                                                 | 用途                                                                                                                                                                                                                                     |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [daikin](daikin/)                                     | ダイキン MCK706A-W（加湿空気清浄機）を REST API 経由で管理。温湿度・空気質センサーの取得、電源・加湿切替・コース・風量・湿度設定の変更                                                                                                   |
| [deco](deco/)                                         | TP-Link Deco BE85（メッシュルーター）を REST API 経由で管理。ネットワーク状況・接続クライアント・Wi-Fi ON/OFF/設定変更・システムログ・ファームウェア確認/更新・速度測定・LED・DHCP 予約/ポート転送など luci・Deco アプリの各操作・再起動 |
| [epgstation](epgstation/)                             | EPGStation（TV録画サーバー）を REST API 経由で操作。番組検索・録画予約・自動録画ルール管理                                                                                                                                               |
| [pihole](pihole/)                                     | Pi-hole（DNS 広告ブロッカー）v6 REST API 経由の管理。ブロック状況・クエリログ・許可/拒否リスト                                                                                                                                           |
| [popin-aladdin](popin-aladdin/)                       | popIn Aladdin（照明一体型プロジェクター）を REST API 経由で操作。シーリングライト・再生/音量・メディアキャスト・リモコン/文字入力・アプリ起動・スクリーンショット・電源 OFF                                                              |
| [stirling-pdf](stirling-pdf/)                         | Stirling PDF サーバーでの PDF と Markdown / 画像 / Word / HTML の相互変換と圧縮。Stirling PDF を名指ししたときは結合・分割・OCR なども                                                                                                   |
| [switch2-control](switch2-control/)                   | Nintendo Switch 2 を LAN 上の HTTP API 経由で Pro Controller として操作                                                                                                                                                                  |
| [codex-model-profiles](codex-model-profiles/)         | codex CLI のプロファイルで既定以外のモデル (Sakana fugu) を呼ぶ。ユーザーがモデルを名指ししたときや委譲先に指定したときに使う                                                                                                            |
| [japanese-tech-writing](japanese-tech-writing/)       | 日本語の技術書・記事の原稿の文章規範。整形・パラグラフライティング・論証の厳密さ・LLM っぽい空句の禁止などを定める (文の書き方の一般則は clear-writing に従う)                                                                           |
| [cognitive-rhythm-writing](cognitive-rhythm-writing/) | 読み物として読ませる章・記事の順序と構成 (未回収の問いを立てて返す順序) の規範。japanese-tech-writing と併用                                                                                                                             |

## 使い方

`mise run install-<agent>` (下のタスク一覧) で各エージェントの skills ディレクトリに全 skill を配置する。プロジェクト単位で使うなら、skill ディレクトリをそのプロジェクトの skills ディレクトリ (Claude Code は `.claude/skills/`) に置く。cognitive-rhythm-writing は japanese-tech-writing を同じ階層から読むので、両方を置く。

`install-openclaw` は、git が追跡しているファイルだけをコピーする (commit 前の skill は配置せずに止まる)。配置したコピーには配置元を書いた印 (`.installed-from`) を置き、印の無い同名のディレクトリがあれば上書きせずに止まる。印の無いコピー (印を書かない方法で配置したもの) があるときは、配置先の該当ディレクトリを消してから実行し直す。`install-*` の link は、配置先に他所を指す同名の symlink があっても止まる。印のあるコピーは実行のたびに置き換わるので、配置先で足したファイルは残らない。詳細は各 skill の `SKILL.md` を参照。

## タスク

タスクは `mise run <task>` で実行する。`mise.toml` の `[tasks]` を変更した場合は
`mise run docs` を実行し、以下の一覧を更新する (pre-commit hook からも自動実行される)。

<!-- dprint-ignore-start -->
<!-- mise-tasks -->
## `docs`

- **Usage:** `docs`

Sync the task list embedded in README.md with mise.toml

## `install-agy`

- **Usage:** `install-agy`

Symlink all skills into ~/.gemini/config/skills

## `install-claude`

- **Usage:** `install-claude`

Symlink all skills into ~/.claude/skills

## `install-codex`

- **Usage:** `install-codex`

Symlink all skills into ~/.agents/skills (Codex reads it whatever CODEX_HOME is)

## `install-openclaw`

- **Usage:** `install-openclaw`

Copy all skills into ~/.openclaw/workspace/skills (its loader rejects symlinks that resolve outside the workspace unless skills.load.allowSymlinkTargets is set)
<!-- /mise-tasks -->
<!-- dprint-ignore-end -->

## License

[MIT](LICENSE)
