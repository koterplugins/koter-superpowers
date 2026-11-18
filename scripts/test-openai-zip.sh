#!/usr/bin/env bash
# Checks the structure of the package built by build-openai.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(jq -r .version .claude-plugin/plugin.json)
zip="dist/koter-openai-$version.zip"
pkg=$(mktemp -d)
trap 'rm -rf "$pkg"' EXIT
unzip -q "$zip" -d "$pkg"

fail() { echo "$zip: $*" >&2; exit 1; }

diff -rq skills "$pkg/skills" || fail "skills/ differs from the source"
for extra in commands hooks .app.json .mcp.json .claude-plugin; do
  [ ! -e "$pkg/$extra" ] || fail "$extra must not ship"
done

jq -e --arg version "$version" '
  .["$schema"] == "https://agent-plugins.org/schemas/1.0.0/plugin.schema.json"
  and .name == "koter" and .version == $version
  and (.extensions["com.openai"] | has("apps") or has("hooks") | not)
  and (.extensions["com.openai"].interface
    | all(.displayName, .shortDescription, .longDescription, .developerName, .category,
          .websiteURL, .supportURL, .privacyPolicyURL, .termsOfServiceURL, .composerIcon, .logo; type == "string" and . != "")
      and (.displayName | length) <= 30 and (.shortDescription | length) <= 30
      and all(.websiteURL, .supportURL, .privacyPolicyURL, .termsOfServiceURL; startswith("https://")))
  and .extensions["com.openai"].publication.countries == []
' "$pkg/plugin.json" > /dev/null || fail "plugin.json is missing a field or breaks a limit"

jq -e --arg url "$(jq -r .mcpServers.koter.url .mcp.json)" '
  .["$schema"] == "https://agent-plugins.org/schemas/1.0.0/mcp.schema.json"
  and (.mcpServers | keys) == ["koter"]
  and .mcpServers.koter.type == "streamable-http" and .mcpServers.koter.url == $url
  and .mcpServers.koter.extensions["com.openai"].auth == {type: "oauth", client: {mode: "cimd"}}
' "$pkg/mcp.json" > /dev/null || fail "mcp.json does not point to the Koter server with OAuth (CIMD)"

for icon in $(jq -r '.extensions["com.openai"].interface | .composerIcon, .logo' "$pkg/plugin.json"); do
  [ -f "$pkg/$icon" ] || fail "missing icon $icon"
done

echo "ok: $zip"
