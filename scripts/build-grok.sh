#!/usr/bin/env bash
# Builds dist/koter-grok-<version>.zip, the Grok skills package, from the Claude plugin sources.
set -euo pipefail
cd "$(dirname "$0")/.."
plugin=plugins/koter

version=$(jq -r .version "$plugin/.claude-plugin/plugin.json")
out="dist/koter-grok-$version.zip"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

node scripts/grok-skills.mjs "$stage"
cp scripts/grok-leia-me.txt "$stage/LEIA-ME.txt"

mkdir -p dist
rm -f "$out"
(cd "$stage" && zip -qrX "$OLDPWD/$out" .)
echo "$out"
