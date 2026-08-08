#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT

status=0
while IFS= read -r -d '' file; do
  formatted="$tmp_dir/$(basename "$file")"
  nimpretty --out:"$formatted" "$repo_root/$file" >/dev/null
  nimpretty "$formatted" >/dev/null
  if ! diff -u "$repo_root/$file" "$formatted"; then
    status=1
  fi
done < <(git -C "$repo_root" ls-files -z -- '*.nim')

if [[ "$status" -ne 0 ]]; then
  echo "Formatting check failed. Run nimpretty on the files above." >&2
  exit "$status"
fi

echo "All Nim files are formatted."
