#!/usr/bin/env bash
# Usage: scripts/install-skills.sh <link|copy> <dest>
# このリポジトリ直下で SKILL.md を持つディレクトリを dest に配置し、このリポジトリから配置したもののうち
# SKILL.md を持たなくなった skill (改名・削除の残骸) を dest から削除する。
# link: symlink を張る
# copy: git が追跡しているファイルだけをコピーする (symlink を辿れない skill loader 向け。.gitignore で
#       除外した secret 等を配置先へ持ち込まない)。コピーには配置元を書いた印のファイルを置き、印の無い
#       同名のディレクトリ (利用者が置いた skill 等) は上書きせず止まる。印のあるコピーは更新のたびに
#       置き換わるので、配置先で足したファイルは残らない
set -euo pipefail
shopt -s nullglob

mode="${1:-}"
dest="${2:-}"
if [ $# -ne 2 ] || { [ "$mode" != link ] && [ "$mode" != copy ]; }; then
  echo "usage: $0 <link|copy> <dest>" >&2
  exit 2
fi

repo="$(cd "$(dirname "$0")/.." && pwd)"
marker=.installed-from
mkdir -p "$dest"

# copy で配置したディレクトリか (印の配置元がこのリポジトリか)
copied_from_repo() {
  [ -d "$1" ] && [ ! -L "$1" ] && [ -f "$1/$marker" ] && [ "$(cat "$1/$marker")" = "$repo" ]
}

# 差し替えの途中で終わったとき (失敗・シグナル) は、退避した既存のコピーを元の場所へ戻してから一時ディレクトリを消す。
# 戻せなければ一時ディレクトリを残し、場所を示す
tmp=
target=
cleanup() {
  [ -n "$tmp" ] || return 0
  if [ -e "$tmp/old" ] && [ ! -e "$target" ]; then
    mv "$tmp/old" "$target" || { echo "error: the previous copy is left at $tmp/old" >&2; return 0; }
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

for skill_md in "$repo"/*/SKILL.md; do
  skill="$(basename "$(dirname "$skill_md")")"
  target="$dest/$skill"
  if [ "$mode" = link ]; then
    if [ -e "$target" ] && [ ! -L "$target" ]; then
      echo "error: $target exists and is not a symlink; remove it first" >&2
      exit 1
    fi
    # dest をほかの配布元と共有する場合 (~/.agents/skills 等) に、他所を指す同名の link を張り替えない
    if [ -L "$target" ] && [ "$(readlink "$target")" != "$repo/$skill" ]; then
      echo "error: $target links to $(readlink "$target"), not $repo/$skill; remove it first" >&2
      exit 1
    fi
    ln -sfn "$repo/$skill" "$target"
    # Windows の bash (MSYS2 等) は設定によって ln -s で symlink ではなくコピーを作るので、作れたかを確かめる
    if [ ! -L "$target" ]; then
      echo "error: $target was not created as a symlink; enable native symlinks or use copy" >&2
      exit 1
    fi
    echo "linked $skill -> $target"
  else
    if [ -e "$target" ] || [ -L "$target" ]; then
      copied_from_repo "$target" || {
        echo "error: $target has no $marker naming $repo (not copied by this script); remove it first" >&2
        exit 1
      }
    fi
    # 途中で失敗しても既存のコピーが欠けないよう、同じ dest の一時ディレクトリの中に作り、
    # 既存のコピーを退避してから差し替える (差し替えに失敗したら退避したものを戻す)。
    # mktemp -d のディレクトリは 0700 なので、その中に作ったコピー (元の権限を保つ) を動かす
    if [ -z "$(git -C "$repo" ls-files -- "$skill/SKILL.md")" ]; then
      echo "error: $skill/SKILL.md is not tracked by git; git add the skill directory before copying" >&2
      exit 1
    fi
    tmp="$(mktemp -d "$dest/.$skill.XXXXXX")"
    mkdir "$tmp/tree"
    git -C "$repo" ls-files -z -- "$skill" | tar -C "$repo" --no-recursion --null -T - -cf - | tar -C "$tmp/tree" -xf -
    mv "$tmp/tree/$skill" "$tmp/new"
    printf '%s\n' "$repo" >"$tmp/new/$marker"
    [ ! -e "$target" ] || mv "$target" "$tmp/old"
    mv "$tmp/new" "$target"
    rm -rf "$tmp"
    tmp=
    echo "copied $skill -> $target"
  fi
done

# 削除の対象は、このスクリプトが配置した形のものだけにする: link は "$repo/<skill>" を指す symlink
# ("$repo/../x" のような別経路や、他所で張られた入れ子パスの link には触らない)、copy は印のあるディレクトリ
for entry in "$dest"/*; do
  skill="$(basename "$entry")"
  [ -f "$repo/$skill/SKILL.md" ] && continue
  if [ "$mode" = link ]; then
    [ -L "$entry" ] && [ "$(readlink "$entry")" = "$repo/$skill" ] || continue
    rm "$entry"
  else
    copied_from_repo "$entry" || continue
    rm -rf "$entry"
  fi
  echo "pruned $entry"
done
