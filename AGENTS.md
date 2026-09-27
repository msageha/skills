# AGENTS.md

このリポジトリ (Agent Skills 集) 固有の作業規約。ユーザー共通の規約は `~/.config/agents/AGENTS.md` (chezmoi 管理) にあり、ここには複製しない。

## 構成

- 各 skill は `<name>/SKILL.md` と、必要なら `<name>/references/*.md` から成る 1 ディレクトリ。frontmatter の `name` はディレクトリ名と一致させる。
- skill は 1 ディレクトリ単位で symlink または copy されて使われるため、self-contained に書く。他 skill への参照は、同時に配置される前提の `../<skill>/` に限る (cognitive-rhythm-writing が japanese-tech-writing を読む形)。
- REST 系 skill は SKILL.md (要点と endpoint 表)・`references/api-reference.md` (schema)・`references/commands.md` (curl 例) の 3 層。Base URL や「確認してから実行する操作」など安全に関わる事実は 3 層で一致させる。
- `scripts/` は配布 (install) 用で、skill 本体からは参照しない。

## 変更時の手順

- skill を追加・改名・削除したら README の表を更新し、`mise run install-<agent>` で配置し直す。改名・削除で残る symlink は `scripts/install-skills.sh` が prune する。
- `mise.toml` の tasks を変えたら `mise run docs` で README のタスク一覧を再生成する (pre-commit hook でも実行される)。
- references の事実 (endpoint・field・default) は live の OpenAPI (Stirling PDF は `/v1/api-docs`、EPGStation は `/api/docs`) か実リクエストで裏取りしてから書く。

## 検証

- `mise exec -- prek run --all-files` (dprint・actionlint・task-docs 同期・基本 hook) を通す。
- `scripts/install-skills.sh` を変えたら shellcheck と、一時ディレクトリでの link / copy / prune の実行で確認する。
