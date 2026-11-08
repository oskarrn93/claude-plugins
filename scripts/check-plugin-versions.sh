#!/usr/bin/env bash
# Fails if a plugin changed since <base-ref> without a version increase. Once
# plugin.json sets a version, consumers stay on their cached copy until it changes.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: $0 <base-ref>" >&2
  exit 64
fi
base=$1

root=$(cd "$(git rev-parse --show-toplevel)" && pwd -P)
cd "$root"

status=0
fail() {
  echo "$1: $2" >&2
  status=1
}

for dir in plugins/*/; do
  dir=${dir%/}
  plugin=${dir#plugins/}
  manifest=$dir/.claude-plugin/plugin.json

  paths=("$dir")
  # A symlinked file's content lives outside the plugin, so git reports its
  # changes only under the link's target.
  while IFS= read -r link; do
    target=$(readlink "$link")
    case $target in
      /*) ;;
      *) target=$(dirname "$link")/$target ;;
    esac
    if ! target_dir=$(cd "$(dirname "$target")" 2>/dev/null && pwd -P) || [[ $target_dir != "$root"/* ]]; then
      fail "$plugin" "symlink $link points outside the repo or to a missing directory"
      continue
    fi
    paths+=("${target_dir#"$root"/}/$(basename "$target")")
  done < <(find "$dir" -type l)

  if git diff --quiet "$base...HEAD" -- "${paths[@]}"; then
    continue
  fi

  version=$(jq -r '.version // empty' "$manifest")
  if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    fail "$plugin" "changed, but $manifest has no MAJOR.MINOR.PATCH version (found '$version')"
    continue
  fi

  base_version=$(git show "$base:$manifest" 2>/dev/null | jq -r '.version // empty' || true)
  if [ -z "$base_version" ]; then
    continue
  fi

  highest=$(printf '%s\n%s\n' "$base_version" "$version" | sort -V | tail -n 1)
  if [ "$version" = "$base_version" ] || [ "$highest" != "$version" ]; then
    fail "$plugin" "changed, so bump version in $manifest above $base_version (found $version)"
  fi
done

exit "$status"
