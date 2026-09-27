#!/usr/bin/env bash
# Usage: scripts/install-skills.sh <link|copy> <dest>
# このリポジトリ直下で SKILL.md を持つディレクトリを dest に配置する。
# link: symlink を張り、dest 内に残った本リポジトリ由来の dangling symlink を削除する
# copy: ディレクトリごとコピーする (symlink を辿れない skill loader 向け)
set -euo pipefail
shopt -s nullglob

mode="${1:-}"
dest="${2:-}"
if [ $# -ne 2 ] || { [ "$mode" != link ] && [ "$mode" != copy ]; }; then
  echo "usage: $0 <link|copy> <dest>" >&2
  exit 2
fi

repo="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$dest"

for skill_md in "$repo"/*/SKILL.md; do
  skill="$(basename "$(dirname "$skill_md")")"
  if [ "$mode" = link ]; then
    if [ -e "$dest/$skill" ] && [ ! -L "$dest/$skill" ]; then
      echo "error: $dest/$skill exists and is not a symlink; remove it first" >&2
      exit 1
    fi
    ln -sfn "$repo/$skill" "$dest/$skill"
    echo "linked $skill -> $dest/$skill"
  else
    rm -rf "${dest:?}/${skill:?}"
    cp -R "$repo/$skill" "$dest/$skill"
    echo "copied $skill -> $dest/$skill"
  fi
done

# このスクリプトが張った symlink は "$repo/<skill>" の形なので、その形の dangling だけを削除する
# ("$repo/../x" のような別経路や、他所で張られた入れ子パスの link には触らない)
[ "$mode" = link ] || exit 0
for entry in "$dest"/*; do
  [ -L "$entry" ] && [ ! -e "$entry" ] || continue
  case "$(readlink "$entry")" in
    "$repo"/*/*) ;;
    "$repo"/*)
      rm "$entry"
      echo "pruned dangling $entry"
      ;;
  esac
done
