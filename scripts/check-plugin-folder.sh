#!/usr/bin/env bash
# Fails when plugins/koter holds a file that the Claude plugin directory only accepts from Verified organizations,
# or when its LICENSE and NOTICE differ from the ones at the root.
set -euo pipefail
cd "$(dirname "$0")/.."
plugin=plugins/koter

bad=()
while IFS= read -r -d '' file; do
  case "${file#"$plugin"/}" in
    */package.json | package.json | *-lock.json | *requirements*.txt) bad+=("$file: package manager file") ;;
    .claude-plugin/plugin.json) ;;
    *.claude-plugin/*) bad+=("$file: extra .claude-plugin folder") ;;
    LICENSE | NOTICE | *.md | *.txt | *.json | *.yaml | *.yml | *.png | *.jpg | *.jpeg | *.gif | *.webp | *.ico) ;;
    *) bad+=("$file: file type not allowed") ;;
  esac
  [ "$(head -c 2 "$file")" != '#!' ] || bad+=("$file: starts with #!")
done < <(git ls-files -z -- "$plugin")

for copy in LICENSE NOTICE; do
  cmp -s "$copy" "$plugin/$copy" || bad+=("$plugin/$copy: differs from $copy at the root")
done

if [ ${#bad[@]} -gt 0 ]; then
  printf '%s\n' "${bad[@]}" >&2
  echo "Keep scripts, configuration and other files outside $plugin." >&2
  exit 1
fi
echo "ok: $plugin holds only Markdown, text, JSON, YAML and images"
