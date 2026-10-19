#!/usr/bin/env bash
# Builds distributable files into dist/ (git-ignored):
#
#   dist/appsec-skills-<version>.zip     the skills/ folder, for agents with a skills directory
#   dist/<skill>.zip                     one skill per archive (SKILL.md in one folder), for builders
#                                        that import a skill as a ZIP (Lovable)
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

# The zip unpacks into one folder holding the skills and both installers.
stage_zip="$(mktemp -d)"
mkdir -p "$stage_zip/appsec-skills-$version"
cp -R "$repo/skills" "$repo/install.sh" "$repo/install.ps1" "$repo/LICENSE" "$repo/README.md" "$stage_zip/appsec-skills-$version/"
(cd "$stage_zip" && zip -q -r "$dist/appsec-skills-$version.zip" "appsec-skills-$version" -x '*.DS_Store' -x '*__pycache__*' -x '*.pyc')
rm -rf "$stage_zip"

for skill_dir in "$repo"/skills/*/; do
  name="$(basename "$skill_dir")"
  out="$dist/$name.md"
  {
    echo "<!-- $name $version: single-file bundle. The scanner script is not included; see the repository. -->"
    if [ "$name" = "appsec-review" ]; then
      cat <<'NOTE'
> **Used in a chat, with code pasted or attached instead of a repository:**
> - Line numbers count from the first line of **each file**, never from the start of the paste. If a file's own numbering is unclear, quote the code and give no number.
> - No scanner runs here: write `none (chat)` under *Scanners run*, and under *Scanners missing* the command to run them later from a coding agent.
> - Write the whole report in the reply, every section of the template in order, the *Status* line of every finding, and the *Hand-off* instruction word for word: the user copies it to the agent that will fix the code.

NOTE
    fi
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

# One archive per skill, SKILL.md inside a single folder: the shape builders such as Lovable
# accept for an uploaded skill (Settings > Skills > Add > Upload ZIP).
for skill_dir in "$repo"/skills/*/; do
  name="$(basename "$skill_dir")"
  (cd "$repo/skills" && zip -q -r "$dist/$name.zip" "$name" -x '*.DS_Store' -x '*__pycache__*' -x '*.pyc')
  echo "  $name -> dist/$name.zip"
done

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
(cd "$stage" && zip -q -r "$dist/appsec-skills.plugin" . -x '*.DS_Store' -x '*__pycache__*' -x '*.pyc')
echo "  plugin -> dist/appsec-skills.plugin"

(cd "$dist" && shasum -a 256 ./* | sed 's# \./# #' > SHA256SUMS)
echo "  sums -> dist/SHA256SUMS"
