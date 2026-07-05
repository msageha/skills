# skills

[Claude Code](https://docs.claude.com/en/docs/claude-code) 用の [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) 集。

## Skills

| Skill | 用途 |
|---|---|
| [daikin](daikin/) | ダイキン MCK706A-W（加湿空気清浄機）を REST API 経由で管理。温度・湿度・空気質センサーの取得・電源 ON/OFF |
| [deco](deco/) | TP-Link Deco BE85（メッシュルーター）を REST API 経由で管理。ネットワーク状況・接続クライアント・Wi-Fi ON/OFF/設定変更・再起動 |
| [epgstation](epgstation/) | EPGStation（TV録画サーバー）を REST API 経由で操作。番組検索・録画予約・自動録画ルール管理 |
| [pihole](pihole/) | Pi-hole（DNS 広告ブロッカー）v6 REST API 経由の管理。ブロック状況・クエリログ・許可/拒否リスト |
| [popin-aladdin](popin-aladdin/) | popIn Aladdin（照明一体型プロジェクター）を REST API 経由で操作。シーリングライト・再生/音量・メディアキャスト・リモコン/文字入力 |
| [stirling-pdf](stirling-pdf/) | Stirling PDF による PDF 操作。変換・結合・分割・圧縮・OCR・Markdown/画像/Word 変換など |
| [switch2-control](switch2-control/) | Nintendo Switch 2 を LAN 上の HTTP API 経由で Pro Controller として操作 |
| [codex-fugu-ultra](codex-fugu-ultra/) | Claude Code から codex MCP 経由で Sakana の fugu-ultra モデルにセカンドオピニオンや長時間作業を委譲 |
| [codex-fusion](codex-fusion/) | Claude Code から codex MCP 経由で OpenRouter の fusion モデルを呼び出す |

## 使い方

各ディレクトリを `~/.claude/skills/` 以下に配置するか、プロジェクトの `.claude/skills/` に配置すると Claude Code から利用できる。詳細は各 skill の `SKILL.md` を参照。

## License

[MIT](LICENSE)
