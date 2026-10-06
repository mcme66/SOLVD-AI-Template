#!/usr/bin/env bash
# Usage: check-api-version.sh <max-version> [files...]
# Fails if any given metadata file declares <apiVersion> greater than <max-version>.
set -euo pipefail
max="$1"; shift
status=0
for f in "$@"; do
  [ -f "$f" ] || continue
  v=$(grep -o '<apiVersion>[0-9.]*' "$f" | head -1 | sed 's/<apiVersion>//' || true)
  [ -z "$v" ] && continue
  if awk -v a="$v" -v b="$max" 'BEGIN { exit !(a > b) }'; then
    echo "::error file=$f::apiVersion $v exceeds production $max"
    status=1
  fi
done
exit $status
