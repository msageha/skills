# skills

[Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) 集。Claude Code / Codex / Antigravity / OpenClaw から使う。

## Skills

| Skill                                                 | 用途                                                                                                                              |
| ----------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| [daikin](daikin/)                                     | ダイキン MCK706A-W（加湿空気清浄機）を REST API 経由で管理。温度・湿度・空気質センサーの取得・電源 ON/OFF                         |
| [deco](deco/)                                         | TP-Link Deco BE85（メッシュルーター）を REST API 経由で管理。ネットワーク状況・接続クライアント・Wi-Fi ON/OFF/設定変更・再起動    |
| [epgstation](epgstation/)                             | EPGStation（TV録画サーバー）を REST API 経由で操作。番組検索・録画予約・自動録画ルール管理                                        |
| [pihole](pihole/)                                     | Pi-hole（DNS 広告ブロッカー）v6 REST API 経由の管理。ブロック状況・クエリログ・許可/拒否リスト                                    |
| [popin-aladdin](popin-aladdin/)                       | popIn Aladdin（照明一体型プロジェクター）を REST API 経由で操作。シーリングライト・再生/音量・メディアキャスト・リモコン/文字入力 |
| [stirling-pdf](stirling-pdf/)                         | Stirling PDF による PDF 操作。変換・結合・分割・圧縮・OCR・Markdown/画像/Word 変換など                                            |
| [switch2-control](switch2-control/)                   | Nintendo Switch 2 を LAN 上の HTTP API 経由で Pro Controller として操作                                                           |
| [codex-model-profiles](codex-model-profiles/)         | codex CLI のプロファイルで既定以外のモデル (Sakana fugu、OpenRouter fusion / pareto-code) にセカンドオピニオンや長時間作業を委譲  |
| [japanese-tech-writing](japanese-tech-writing/)       | 日本語技術文書・書籍原稿の文章規範。整形・パラグラフライティング・論証の厳密さ・LLM っぽい空句の禁止などを定める                  |
| [cognitive-rhythm-writing](cognitive-rhythm-writing/) | 説明的な文章に緩急（認知モードの切替と未回収の緊張）を設計する規範。japanese-tech-writing と併用                                  |

## 使い方

`mise run install-<agent>` (下のタスク一覧) で各エージェントの skills ディレクトリに全 skill を配置する。プロジェクト単位で使うなら、skill ディレクトリをそのプロジェクトの skills ディレクトリ (Claude Code は `.claude/skills/`) に置く。詳細は各 skill の `SKILL.md` を参照。

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

Symlink all skills into ~/.gemini/antigravity-cli/skills

## `install-claude`

- **Usage:** `install-claude`

Symlink all skills into ~/.claude/skills

## `install-codex`

- **Usage:** `install-codex`

Symlink all skills into ~/.codex/skills

## `install-openclaw`

- **Usage:** `install-openclaw`

Copy all skills into ~/.openclaw/workspace/skills (its loader rejects symlinks that resolve outside the workspace unless skills.load.allowSymlinkTargets is set)
<!-- /mise-tasks -->
<!-- dprint-ignore-end -->

## License

[MIT](LICENSE)
