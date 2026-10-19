#!/usr/bin/env bash
# Builds distributable files into dist/ (git-ignored):
#
#   dist/appsec-skills-<version>.zip     the skills/ folder, for agents with a skills directory
#   dist/<skill>.md                      one self-contained Markdown file per skill, with every
#                                        reference inlined, for chat assistants that cannot read
#                                        a folder (attach it to the conversation or a custom assistant)
#
# Usage: bash scripts/build.sh [version]     (default: "dev")
set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
version="${1:-dev}"
dist="$repo/dist"
rm -rf "$dist"
mkdir -p "$dist"

(cd "$repo" && zip -q -r "$dist/appsec-skills-$version.zip" skills LICENSE -x '*.DS_Store')

for skill_dir in "$repo"/skills/*/; do
  name="$(basename "$skill_dir")"
  out="$dist/$name.md"
  {
    echo "<!-- $name $version: single-file bundle. The scanner script is not included; see the repository. -->"
    cat "$skill_dir/SKILL.md"
    for sub in references templates; do
      [ -d "$skill_dir/$sub" ] || continue
      for ref in "$skill_dir/$sub"/*.md; do
        printf '\n\n---\n\n<!-- file: %s/%s -->\n\n' "$sub" "$(basename "$ref")"
        cat "$ref"
      done
    done
  } > "$out"
  echo "  $name -> dist/$name.md ($(wc -w < "$out" | tr -d ' ') words)"
done
echo "  zip  -> dist/appsec-skills-$version.zip"

# Cowork and other environments that install plugin archives: same skills, plus a manifest.
stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/.claude-plugin"
cp -R "$repo/skills" "$stage/skills"
cat > "$stage/.claude-plugin/plugin.json" <<JSON
{
  "name": "appsec-skills",
  "version": "$version",
  "description": "Security review for AI coding agents: verified findings, report as a work order any AI can execute, verify mode",
  "author": { "name": "Maxence Barthelemy" },
  "license": "MIT"
}
JSON
(cd "$stage" && zip -q -r "$dist/appsec-skills.plugin" . -x '*.DS_Store')
echo "  plugin -> dist/appsec-skills.plugin"
