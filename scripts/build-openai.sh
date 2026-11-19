#!/usr/bin/env bash
# Builds dist/koter-openai-<version>.zip, the ChatGPT package, from the Claude plugin sources.
set -euo pipefail
cd "$(dirname "$0")/.."
plugin=plugins/koter

version=$(jq -r .version "$plugin/.claude-plugin/plugin.json")
out="dist/koter-openai-$version.zip"
stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT

cp -R "$plugin/skills" "$plugin/assets" "$stage/"

jq --slurpfile openai scripts/openai-extension.json '{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json",
  name, version, description, author, homepage, repository, license, keywords,
  extensions: {"com.openai": $openai[0]}
}' "$plugin/.claude-plugin/plugin.json" > "$stage/plugin.json"

jq '{
  "$schema": "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json",
  mcpServers: (.mcpServers | map_values({
    type: "streamable-http",
    url,
    extensions: {"com.openai": {auth: {type: "oauth", client: {mode: "cimd"}}}}
  }))
}' "$plugin/.mcp.json" > "$stage/mcp.json"

mkdir -p dist
rm -f "$out"
(cd "$stage" && zip -qrX "$OLDPWD/$out" .)
echo "$out"
