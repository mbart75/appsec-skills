#!/usr/bin/env bash
# The sh -c snippets take their values as positional parameters on purpose.
# shellcheck disable=SC2016
# Detects which security scanners are installed, runs the ones relevant to the
# repository, and writes their raw output to a directory OUTSIDE the repository.
#
#   bash run-scanners.sh <repo_dir> <out_dir> [--history] [--verify-secrets] [--offline]
#
#   --history          also scan the whole git history for secrets (full mode)
#   --verify-secrets   let TruffleHog test found secrets against their provider
#                      (network call carrying the secret to its own issuer; off by default)
#   --offline          do not fetch the CISA KEV catalog and EPSS scores
#
# Never installs anything. Never sends source code anywhere. Some tools download
# rules or query public vulnerability databases with package names and versions;
# cve-priority.py sends CVE identifiers to the FIRST EPSS API and downloads the KEV catalog.
# Exit code is 0 even when scanners report findings: triage is the agent's job.
set -uo pipefail

usage() { echo "usage: bash run-scanners.sh <repo_dir> <out_dir> [--history] [--verify-secrets] [--offline]" >&2; exit 2; }

[ $# -ge 2 ] || usage
repo="$(cd "$1" 2>/dev/null && pwd -P)" || { echo "repository not found: $1" >&2; exit 2; }
# Resolve the output path without creating it yet: the check below must come first.
# Physical paths (pwd -P): a symlink must not hide that the output lands inside the repository.
out_parent="$(cd "$(dirname "$2")" 2>/dev/null && pwd -P)" || { echo "parent of output directory not found: $2" >&2; exit 2; }
out="$out_parent/$(basename "$2")"
shift 2

history=0
verify=0
offline=0
for arg in "$@"; do
  case "$arg" in
    --history) history=1 ;;
    --verify-secrets) verify=1 ;;
    --offline) offline=1 ;;
    *) usage ;;
  esac
done

# Reports are an attack map: refuse to write them inside the repository.
case "$out/" in
  "$repo"/*) echo "refusing: output directory is inside the repository ($out)" >&2; exit 2 ;;
esac
mkdir -p "$out" || exit 2

have() { command -v "$1" >/dev/null 2>&1; }
has_files() { find "$repo" -path '*/node_modules' -prune -o -path '*/.git' -prune -o -type f \( "$@" \) -print -quit | grep -q .; }

summary=()
record() { summary+=("$(printf '%-18s %-14s %s' "$1" "$2" "$3")"); }

run() { # name, output file, command...
  local name="$1" file="$2"; shift 2
  if "$@" >"$out/$file.stdout" 2>"$out/$file.stderr"; then
    record "$name" "ran" "$out/$file"
  else
    record "$name" "ran, exit $?" "$out/$file  (non-zero often means findings; check $file.stderr for errors)"
  fi
}

missing() { record "$1" "MISSING" "install: $2"; }
skipped() { record "$1" "not relevant" "$2"; }

is_git=0
git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 && is_git=1

# --- Secrets ------------------------------------------------------------------
if have gitleaks; then
  run gitleaks gitleaks-files.json gitleaks dir "$repo" --redact --no-banner \
    --report-format json --report-path "$out/gitleaks-files.json" --exit-code 0
  if [ "$history" -eq 1 ] && [ "$is_git" -eq 1 ]; then
    run "gitleaks history" gitleaks-history.json gitleaks git "$repo" --redact --no-banner \
      --report-format json --report-path "$out/gitleaks-history.json" --exit-code 0
  fi
else
  missing gitleaks "brew install gitleaks | https://github.com/gitleaks/gitleaks"
fi

if [ "$history" -eq 1 ] && [ "$is_git" -eq 1 ]; then
  if have trufflehog; then
    if [ "$verify" -eq 1 ]; then
      run trufflehog trufflehog.json sh -c 'trufflehog git "file://$1" --json --no-update > "$2"' _ "$repo" "$out/trufflehog.json"
    else
      run trufflehog trufflehog.json sh -c 'trufflehog git "file://$1" --json --no-update --no-verification > "$2"' _ "$repo" "$out/trufflehog.json"
    fi
  else
    missing trufflehog "brew install trufflehog | https://github.com/trufflesecurity/trufflehog"
  fi
fi

# --- Static analysis ------------------------------------------------------------
if have semgrep; then
  run semgrep semgrep.json semgrep scan --config p/default --metrics=off --json \
    --output "$out/semgrep.json" --quiet "$repo"
elif have opengrep; then
  run opengrep opengrep.json opengrep scan --config p/default --json \
    --output "$out/opengrep.json" --quiet "$repo"
else
  missing semgrep "brew install semgrep | pipx install semgrep | or Opengrep"
fi

if has_files -name '*.py'; then
  if have bandit; then
    run bandit bandit.json bandit -r "$repo" -f json -o "$out/bandit.json" -q -x '*/node_modules/*,*/.venv/*'
  else
    missing bandit "brew install bandit | pipx install bandit"
  fi
else
  skipped bandit "no Python files"
fi

if has_files -name '*.sh' -o -name '*.bash'; then
  if have shellcheck; then
    run shellcheck shellcheck.json sh -c \
      'find "$1" -path "*/node_modules" -prune -o -path "*/.git" -prune -o -type f \( -name "*.sh" -o -name "*.bash" \) -print0 | xargs -0 shellcheck -f json > "$2"' \
      _ "$repo" "$out/shellcheck.json"
  else
    missing shellcheck "brew install shellcheck"
  fi
else
  skipped shellcheck "no shell scripts"
fi

if has_files -name '*.ps1' -o -name '*.psm1'; then
  if have pwsh && pwsh -NoProfile -Command 'if (-not (Get-Module -ListAvailable PSScriptAnalyzer)) { exit 1 }' >/dev/null 2>&1; then
    # Paths reach PowerShell through the environment, never inside the command text:
    # the reviewed folder's name is not trusted and could otherwise inject commands.
    run psscriptanalyzer psscriptanalyzer.json env APPSEC_SCAN_REPO="$repo" APPSEC_SCAN_OUT="$out/psscriptanalyzer.json" \
      pwsh -NoProfile -Command \
      'Invoke-ScriptAnalyzer -Path $env:APPSEC_SCAN_REPO -Recurse | Select-Object RuleName, Severity, ScriptPath, Line, Message | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $env:APPSEC_SCAN_OUT'
  else
    missing psscriptanalyzer "Install-Module PSScriptAnalyzer -Scope CurrentUser (PowerShell 7)"
  fi
else
  skipped psscriptanalyzer "no PowerShell files"
fi

# --- Dependencies -----------------------------------------------------------------
if has_files -name 'package.json' -o -name 'requirements*.txt' -o -name 'pyproject.toml' -o -name 'go.mod' \
  -o -name 'Cargo.toml' -o -name 'pom.xml' -o -name 'Gemfile' -o -name 'composer.json' -o -name '*.lock' -o -name 'package-lock.json'; then
  if have osv-scanner; then
    run osv-scanner osv.json osv-scanner scan source -r "$repo" --format json --output "$out/osv.json"
    # Known exploited (CISA KEV) and likely exploited (EPSS) first.
    here="$(cd "$(dirname "$0")" && pwd)"
    if have python3 && [ -s "$out/osv.json" ]; then
      if [ "$offline" -eq 1 ]; then
        run cve-priority cve-priority.md python3 -I "$here/cve-priority.py" "$out" --offline
      else
        run cve-priority cve-priority.md python3 -I "$here/cve-priority.py" "$out"
      fi
    elif ! have python3; then
      missing cve-priority "python3 (to add KEV and EPSS to osv-scanner results)"
    fi
  else
    missing osv-scanner "brew install osv-scanner | https://github.com/google/osv-scanner"
  fi
else
  skipped osv-scanner "no dependency manifest"
fi

# --- Infrastructure as code and containers ----------------------------------------
if has_files -name '*.tf' -o -name 'Dockerfile' -o -name '*.yaml' -o -name '*.yml'; then
  if have checkov; then
    run checkov checkov.json sh -c 'checkov -d "$1" --quiet --compact -o json > "$2"' _ "$repo" "$out/checkov.json"
  else
    missing checkov "pipx install checkov | brew install checkov"
  fi
  if have trivy; then
    run "trivy config" trivy-config.json trivy config --quiet --format json --output "$out/trivy-config.json" "$repo"
  fi
else
  skipped checkov "no IaC or container files"
fi

# --- CI workflows -------------------------------------------------------------------
if [ -d "$repo/.github/workflows" ]; then
  if have zizmor; then
    run zizmor zizmor.json sh -c 'zizmor --offline --format json "$1" > "$2"' _ "$repo" "$out/zizmor.json"
  else
    missing zizmor "brew install zizmor | pipx install zizmor"
  fi
else
  skipped zizmor "no GitHub Actions workflows"
fi

# --- Summary --------------------------------------------------------------------------
echo "Scanner outputs: $out"
printf '%s\n' "${summary[@]}"
