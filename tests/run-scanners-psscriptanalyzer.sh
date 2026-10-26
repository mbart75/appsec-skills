#!/usr/bin/env bash
# run-scanners.sh must not let the reviewed repository configure PSScriptAnalyzer: its
# PSScriptAnalyzerSettings.psd1 can load PowerShell modules (CustomRulePath) and hide findings
# (ExcludeRules). A relative module path is resolved from the folder PSScriptAnalyzer runs in,
# an absolute one from anywhere: both are tested, each from the folder where it would work.
#
#   bash tests/run-scanners-psscriptanalyzer.sh [path/to/run-scanners.sh]
#
# Needs PowerShell 7 with PSScriptAnalyzer. The "malicious" module only writes a marker file into
# the temporary folder of this test. Nothing is read, sent or kept outside of it.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="${1:-$here/../skills/appsec-review/scripts/run-scanners.sh}"
script="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"
pwsh_bin="$(command -v pwsh)" || { echo "pwsh is not installed" >&2; exit 2; }
pwsh -NoProfile -Command 'if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) { exit 1 }' >/dev/null 2>&1 \
  || { echo "PSScriptAnalyzer is not installed" >&2; exit 2; }

tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

# Only PowerShell on the PATH: the other scanners are not under test and some are slow.
mkdir -p "$tmp/bin" "$tmp/elsewhere"
ln -s "$pwsh_bin" "$tmp/bin/pwsh"
export PATH="$tmp/bin:/usr/bin:/bin"

# A repository with one plain finding (Write-Host), which its settings file excludes, and a
# module that proves it was loaded by writing a marker, nothing else.
make_repo() { # directory, CustomRulePath, marker name
  mkdir -p "$1/rules"
  git init -q --template= "$1"
  printf 'Write-Host "hello"\n' > "$1/hello.ps1"
  printf "Set-Content -LiteralPath '%s' -Value ran\nfunction Measure-Nothing { param([System.Management.Automation.Language.ScriptBlockAst]\$ScriptBlockAst) }\nExport-ModuleMember -Function Measure-*\n" \
    "$tmp/MARKER-$3" > "$1/rules/rule.psm1"
  printf "@{\n  CustomRulePath = @('%s')\n  IncludeDefaultRules = \$true\n  ExcludeRules = @('PSAvoidUsingWriteHost')\n}\n" "$2" > "$1/PSScriptAnalyzerSettings.psd1"
  git -C "$1" add -A
  git -C "$1" -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false commit -q -m init
}

fail=0
check() { # description, command...
  local what="$1"; shift
  if "$@"; then echo "ok   - $what"; else echo "FAIL - $what"; fail=1; fi
}
write_host_reported() { # output file
  python3 -I -c '
import json, sys
data = json.load(open(sys.argv[1]))
for r in data if isinstance(data, list) else [data]:
    if r["RuleName"] == "PSAvoidUsingWriteHost" and r["ScriptPath"] == sys.argv[2]:
        sys.exit(0)
sys.exit(1)
' "$1" "$2" 2>/dev/null
}

# Variant "relative": scanned from inside the repository, the usual case for an agent.
# Variant "absolute": scanned from another folder.
make_repo "$tmp/hostile-relative" rules/rule.psm1 relative
make_repo "$tmp/hostile-absolute" "$tmp/hostile-absolute/rules/rule.psm1" absolute

for variant in relative absolute; do
  repo="$tmp/hostile-$variant"
  out="$tmp/out-$variant"
  from="$repo"; [ "$variant" = absolute ] && from="$tmp/elsewhere"
  (cd "$from" && bash "$script" "$repo" "$out" --offline) > "$tmp/summary-$variant.txt" 2>&1

  echo "--- variant: $variant"
  check "$variant: the repository's module was not loaded" test ! -e "$tmp/MARKER-$variant"
  check "$variant: the finding the repository excluded is reported" write_host_reported "$out/psscriptanalyzer.json" "$repo/hello.ps1"
  check "$variant: the repository's settings are listed for the reviewer" grep -q 'psscriptanalyzer settings *IGNORED' "$tmp/summary-$variant.txt"
  check "$variant: settings file listed" grep -qF "Settings file (ignored): $repo/PSScriptAnalyzerSettings.psd1" "$out/psscriptanalyzer-repo-settings.txt" 2>/dev/null
  check "$variant: the reviewed repository is left untouched" test -z "$(git -C "$repo" status --porcelain --ignored)"
  check "$variant: no working folder left in the output folder" test ! -e "$out/.psscriptanalyzer-work"
done

# A clean script must still leave an output file: an empty array, not a missing file that reads
# like a scanner that did not run.
clean="$tmp/clean"
mkdir -p "$clean"
git init -q --template= "$clean"
printf 'Write-Output "hello"\n' > "$clean/clean.ps1"
bash "$script" "$clean" "$tmp/out-clean" --offline > "$tmp/summary-clean.txt" 2>&1
echo "--- variant: clean"
check "clean: the summary says PSScriptAnalyzer ran" grep -q '^psscriptanalyzer *ran ' "$tmp/summary-clean.txt"
check "clean: the output is an empty JSON array" python3 -I -c 'import json, sys; sys.exit(json.load(open(sys.argv[1])) != [])' "$tmp/out-clean/psscriptanalyzer.json"
check "one finding: the output is still an array" python3 -I -c 'import json, sys; sys.exit(not isinstance(json.load(open(sys.argv[1])), list))' "$tmp/out-relative/psscriptanalyzer.json"

if [ "$fail" -ne 0 ]; then
  for variant in relative absolute clean; do echo "--- run-scanners.sh summary ($variant)"; cat "$tmp/summary-$variant.txt"; done
  exit 1
fi
