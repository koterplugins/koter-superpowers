#!/usr/bin/env bash
# Checks the structure of the package built by build-grok.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
plugin=plugins/koter

version=$(jq -r .version "$plugin/.claude-plugin/plugin.json")
zip="dist/koter-grok-$version.zip"
pkg=$(mktemp -d)
trap 'rm -rf "$pkg"' EXIT
unzip -q "$zip" -d "$pkg"

fail() { echo "$zip: $*" >&2; exit 1; }

[ -s "$pkg/LEIA-ME.txt" ] || fail "missing LEIA-ME.txt at the root"

expected=$(cd "$plugin/skills" && ls -d */ | tr -d / | sort)
shipped=$(cd "$pkg" && ls -d */ | tr -d / | sort)
[ "$shipped" = "$expected" ] || fail "the folders differ from the skills in $plugin/skills"
[ -z "$(find "$pkg" -mindepth 1 -maxdepth 1 -type f ! -name LEIA-ME.txt)" ] || fail "only LEIA-ME.txt may sit at the root"

for skill in $shipped; do
  dir="$pkg/$skill"
  [ "$(cd "$dir" && ls -A | sort | tr '\n' ' ')" = "descricao.txt instrucoes.txt nome.txt " ] \
    || fail "$skill must hold only nome.txt, descricao.txt and instrucoes.txt"
  [ "$(cat "$dir/nome.txt")" = "$skill" ] || fail "$skill/nome.txt does not match the folder"
  [ -n "$(tr -d '[:space:]' < "$dir/descricao.txt")" ] || fail "$skill/descricao.txt is empty"
  [ "$(head -n 1 "$dir/instrucoes.txt")" != "---" ] || fail "$skill/instrucoes.txt still has the frontmatter"

  # Every annex cited in the text is a section of the same file.
  for annex in $(grep -oE '"Anexo [0-9]+ · ' "$dir/instrucoes.txt" | grep -oE '[0-9]+' | sort -u); do
    grep -qE "^# Anexo $annex · " "$dir/instrucoes.txt" || fail "$skill/instrucoes.txt cites Anexo $annex without the section"
  done
done

! grep -rnE 'references/[a-z0-9-]+\.md' "$pkg" || fail "a references/ file was cited without being embedded"
! grep -rnF '$ARGUMENTS' "$pkg" || fail "a command placeholder leaked into the package"

while IFS= read -r -d '' file; do
  iconv -f UTF-8 -t UTF-8 "$file" > /dev/null 2>&1 || fail "${file#"$pkg"/} is not valid UTF-8"
done < <(find "$pkg" -type f -print0)

for skill in introducao $(sed -nE 's/^  (koter-[a-z-]+) .*/\1/p' "$pkg/LEIA-ME.txt"); do
  [ -d "$pkg/$skill" ] || fail "LEIA-ME.txt recommends $skill, which is not in the package"
done

echo "ok: $zip ($(wc -w <<< "$shipped") skills)"
