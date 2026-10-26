#!/usr/bin/env bash
# run-scanners.sh must not let the reviewed repository configure Bandit, Semgrep, OSV-Scanner,
# Trivy, zizmor, ShellCheck or PSScriptAnalyzer: their settings files and inline comments could
# hide findings. (PSScriptAnalyzer's settings file has its own test, run-scanners-psscriptanalyzer.sh.)
# One hostile repository uses every one of these ways at once, and is scanned from inside itself,
# the usual case for an agent. Each check names one finding the repository tries to hide.
#
#   bash tests/run-scanners-repo-settings.sh [path/to/run-scanners.sh]
#
# A scanner that is not installed is skipped; with APPSEC_TEST_REQUIRE_ALL=1 (CI) that is a
# failure. Semgrep, OSV-Scanner and Trivy download rules or query vulnerability databases, and
# the KEV catalog and EPSS scores are fetched (the scan runs without --offline, which would leave
# OSV-Scanner without a database). Nothing else is sent, and nothing is kept outside the test's
# temporary folder.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="${1:-$here/../skills/appsec-review/scripts/run-scanners.sh}"
script="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"

tmp="$(cd "$(mktemp -d)" && pwd -P)"
# APPSEC_TEST_KEEP=1 keeps the temporary folder, to read the scanners' outputs.
trap 'if [ "${APPSEC_TEST_KEEP:-0}" = 1 ]; then echo "kept: $tmp"; else rm -rf "$tmp"; fi' EXIT

# Only the scanners under test on the PATH: gitleaks, TruffleHog and Checkov have their own tests.
mkdir -p "$tmp/bin"
skipped=()
for tool in python3 git bandit semgrep osv-scanner trivy zizmor shellcheck pwsh; do
  if bin="$(command -v "$tool")"; then
    ln -s "$bin" "$tmp/bin/$tool"
  else
    skipped+=("$tool")
  fi
done
export PATH="$tmp/bin:/usr/bin:/bin"
has() { [ -e "$tmp/bin/$1" ]; }
if ! has python3 || ! has git; then echo "python3 and git are needed" >&2; exit 2; fi
if has pwsh && ! pwsh -NoProfile -Command 'if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) { exit 1 }' >/dev/null 2>&1; then
  rm -f "$tmp/bin/pwsh"; skipped+=("PSScriptAnalyzer")
fi

repo="$tmp/hostile"
out="$tmp/out"
mkdir -p "$repo/.github/workflows" "$repo/infra"
git init -q --template= "$repo"

# Bandit: a "# nosec" comment, and a .bandit file read from the scanned folder.
printf 'import subprocess\n\n\ndef run(cmd):\n    subprocess.call(cmd, shell=True)  # nosec\n' > "$repo/nosec.py"
printf 'def calc(expr):\n    return eval(expr)\n' > "$repo/evalit.py"
printf '[bandit]\nskips = B307\n' > "$repo/.bandit"

# Semgrep: "nosemgrep" comments, and a .semgrepignore.
printf 'import subprocess\n\n\ndef run(cmd):\n    subprocess.call(cmd, shell=True)  # nosemgrep\n    return eval(cmd)  # nosemgrep\n' > "$repo/sg_nosem.py"
printf 'import subprocess\n\n\ndef run(cmd):\n    subprocess.call(cmd, shell=True)\n    return eval(cmd)\n' > "$repo/sg_ignored.py"
printf 'sg_ignored.py\n' > "$repo/.semgrepignore"

# OSV-Scanner: an osv-scanner.toml that ignores a vulnerable package.
printf 'jinja2==2.4.1\n' > "$repo/requirements.txt"
printf '[[PackageOverrides]]\nname = "jinja2"\necosystem = "PyPI"\nignore = true\nreason = "the repository says so"\n' > "$repo/osv-scanner.toml"

# Trivy: a .trivyignore and a trivy.yaml, both read from the folder Trivy runs in, and an inline
# #trivy:ignore comment, which the script reports but cannot remove.
printf 'FROM alpine:3.20\nRUN echo hello\n' > "$repo/Dockerfile"
cat > "$repo/infra/main.tf" <<'EOF'
resource "aws_security_group" "open" {
  name = "open"
  ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
EOF
printf '#trivy:ignore:AVD-AWS-0107\nlocals {\n  quiet = true\n}\n' > "$repo/infra/quiet.tf"
printf 'DS-0002\nAVD-DS-0002\nDS002\n' > "$repo/.trivyignore"
printf 'scan:\n  skip-dirs:\n    - infra\n' > "$repo/trivy.yaml"

# zizmor: an inline ignore comment, and a zizmor.yml that disables a rule.
cat > "$repo/.github/workflows/ci.yml" <<'EOF'
on: push
permissions: {}
jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
      - uses: example-org/example-action@v1 # zizmor: ignore[unpinned-uses]
EOF
printf 'rules:\n  artipacked:\n    disable: true\n' > "$repo/.github/zizmor.yml"

# ShellCheck: a .shellcheckrc, and an inline disable comment, which is reported but kept.
cat > "$repo/rc.sh" <<'EOF'
#!/bin/sh
echo $1
EOF
printf '#!/bin/sh\n# shellcheck disable=SC2034\nunused=1\n' > "$repo/inline.sh"
printf 'disable=SC2086\n' > "$repo/.shellcheckrc"

# PSScriptAnalyzer: a SuppressMessageAttribute.
cat > "$repo/quiet.ps1" <<'EOF'
function Invoke-Quiet {
  [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '')]
  param([string]$Text)
  Invoke-Expression $Text
}
EOF

git -C "$repo" add -A
git -C "$repo" -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false commit -q -m init

(cd "$repo" && bash "$script" "$repo" "$out") > "$tmp/summary.txt" 2>&1

fail=0
check() { # description, command...
  local what="$1"; shift
  if "$@"; then echo "ok   - $what"; else echo "FAIL - $what"; fail=1; fi
}
# Prints one "<id> <path>" line per finding of a scanner's JSON output.
findings() { # scanner, file
  python3 -I - "$1" "$2" <<'EOF' 2>/dev/null
import json, sys
tool, path = sys.argv[1], sys.argv[2]
data = json.load(open(path))
rows = []
if tool == "bandit":
    rows = [(r["test_id"], r["filename"]) for r in data["results"]]
elif tool == "semgrep":
    rows = [(r["check_id"], r["path"]) for r in data["results"]]
elif tool == "osv":
    rows = [(v["id"], p["package"]["name"]) for r in data.get("results", [])
            for p in r.get("packages", []) for v in p.get("vulnerabilities", [])]
elif tool == "trivy":
    rows = [(m.get("ID", "") + "," + m.get("AVDID", ""), r["Target"])
            for r in data.get("Results", []) for m in r.get("Misconfigurations", [])]
elif tool == "zizmor":
    rows = [(f["ident"], "-") for f in data]
elif tool == "shellcheck":
    rows = [("SC%d" % c["code"], c["file"]) for c in data]
elif tool == "psscriptanalyzer":
    data = data if isinstance(data, list) else [data]
    rows = [(r["RuleName"] + ("+suppressed" if r.get("IsSuppressed") else ""), r["ScriptPath"]) for r in data]
for rule, where in rows:
    print(rule, where)
EOF
}
reported() { findings "$1" "$2" | grep -qE "$3"; } # scanner, file, regex on "<id> <path>"
listed() { grep -qF "$2" "$out/$1-repo-settings.txt" 2>/dev/null; } # scanner, line
summary_says() { grep -qE "^$1 settings +IGNORED" "$tmp/summary.txt"; }

if has bandit; then
  echo "--- bandit"
  check "bandit: the finding marked # nosec is reported" reported bandit "$out/bandit.json" "^B602 $repo/nosec.py$"
  check "bandit: the test skipped by .bandit is reported" reported bandit "$out/bandit.json" "^B307 $repo/evalit.py$"
  check "bandit: .bandit listed" listed bandit "Settings file (ignored): $repo/.bandit"
  check "bandit: # nosec listed" listed bandit "Mentions nosec (ignored): $repo/nosec.py"
  check "bandit: summary says IGNORED" summary_says bandit
fi
if has semgrep; then
  echo "--- semgrep"
  check "semgrep: the findings marked nosemgrep are reported" reported semgrep "$out/semgrep.json" " $repo/sg_nosem.py$"
  check "semgrep: the file in .semgrepignore is scanned, its path names the repository" reported semgrep "$out/semgrep.json" " $repo/sg_ignored.py$"
  check "semgrep: .semgrepignore listed" listed semgrep "Settings file (ignored): $repo/.semgrepignore"
  check "semgrep: nosemgrep listed" listed semgrep "Mentions nosem (ignored): $repo/sg_nosem.py"
  check "semgrep: summary says IGNORED" summary_says semgrep
fi
if has osv-scanner; then
  echo "--- osv-scanner"
  check "osv-scanner: the package osv-scanner.toml ignores is reported" reported osv "$out/osv.json" " jinja2$"
  check "osv-scanner: osv-scanner.toml listed" listed osv-scanner "Settings file (ignored): $repo/osv-scanner.toml"
  check "osv-scanner: summary says IGNORED" summary_says osv-scanner
fi
if has trivy; then
  echo "--- trivy"
  check "trivy: the check in .trivyignore is reported" reported trivy "$out/trivy-config.json" "DS-?0*2[, ].* Dockerfile$"
  check "trivy: the folder trivy.yaml skips is scanned" reported trivy "$out/trivy-config.json" " infra/main.tf$"
  check "trivy: .trivyignore listed" listed trivy "Settings file (ignored): $repo/.trivyignore"
  check "trivy: trivy.yaml listed" listed trivy "Settings file (ignored): $repo/trivy.yaml"
  check "trivy: inline #trivy:ignore listed (cannot be removed)" listed trivy "Mentions trivy:ignore (kept): $repo/infra/quiet.tf"
  check "trivy: summary says IGNORED" summary_says trivy
fi
if has zizmor; then
  echo "--- zizmor"
  check "zizmor: the finding marked zizmor: ignore is reported" reported zizmor "$out/zizmor.json" "^unpinned-uses "
  check "zizmor: the rule zizmor.yml disables is reported" reported zizmor "$out/zizmor.json" "^artipacked "
  check "zizmor: zizmor.yml listed" listed zizmor "Settings file (ignored): $repo/.github/zizmor.yml"
  check "zizmor: inline ignore listed" listed zizmor "Mentions zizmor: ignore (ignored): $repo/.github/workflows/ci.yml"
  check "zizmor: summary says IGNORED" summary_says zizmor
fi
if has shellcheck; then
  echo "--- shellcheck"
  check "shellcheck: the warning .shellcheckrc disables is reported" reported shellcheck "$out/shellcheck.json" "^SC2086 $repo/rc.sh$"
  check "shellcheck: .shellcheckrc listed" listed shellcheck "Settings file (ignored): $repo/.shellcheckrc"
  check "shellcheck: inline disable listed (cannot be removed)" listed shellcheck "Mentions shellcheck disable (kept): $repo/inline.sh"
  check "shellcheck: summary says IGNORED" summary_says shellcheck
fi
if has pwsh; then
  echo "--- psscriptanalyzer"
  check "psscriptanalyzer: the suppressed finding is reported, marked suppressed" reported psscriptanalyzer "$out/psscriptanalyzer.json" "^PSAvoidUsingInvokeExpression\+suppressed $repo/quiet.ps1$"
  check "psscriptanalyzer: SuppressMessageAttribute listed" listed psscriptanalyzer "Mentions SuppressMessage (ignored): $repo/quiet.ps1"
  check "psscriptanalyzer: summary says IGNORED" summary_says psscriptanalyzer
fi
echo "---"
check "the reviewed repository is left untouched" test -z "$(git -C "$repo" status --porcelain --ignored)"
check "no working folder left in the output folder" test -z "$(find "$out" -mindepth 1 -maxdepth 1 -name '.*' ! -name .semgrep-home -print -quit)"

if [ "${#skipped[@]}" -gt 0 ]; then
  echo "skipped, not installed: ${skipped[*]}"
  [ "${APPSEC_TEST_REQUIRE_ALL:-0}" = 1 ] && { echo "FAIL - APPSEC_TEST_REQUIRE_ALL=1"; fail=1; }
fi
if [ "$fail" -ne 0 ]; then
  echo "--- run-scanners.sh summary"; cat "$tmp/summary.txt"
  exit 1
fi
