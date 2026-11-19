#!/usr/bin/env bash
# Fails when a tracked file carries a term from scripts/public-content-denylist.txt (one extended regex per line, case-insensitive).
set -uo pipefail
cd "$(dirname "$0")/.."

hits=$(git grep -n -I -i -E -f scripts/public-content-denylist.txt -- . ':!scripts/public-content-denylist.txt')
[ $? -le 1 ] || exit 2
# The audit log of the AI plans is a product feature, not a process note.
hits=$(grep -v -i 'registro de auditoria' <<< "$hits")

if [ -n "$hits" ]; then
  echo "$hits"
  echo "This repository is public: remove the internal process notes above." >&2
  exit 1
fi
echo "ok: no internal process notes"
