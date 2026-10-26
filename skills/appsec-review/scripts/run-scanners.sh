#!/usr/bin/env bash
# The sh -c snippets take their values as positional parameters on purpose.
# shellcheck disable=SC2016
# Detects which security scanners are installed, runs the ones relevant to the
# repository, and writes their output to a directory OUTSIDE the repository, with the
# secret values found by gitleaks, TruffleHog and Bandit removed.
#
#   bash run-scanners.sh <repo_dir> <out_dir> [--history] [--verify-secrets] [--offline]
#
#   --history          also scan the whole git history for secrets (full mode)
#   --verify-secrets   let TruffleHog test found secrets against their provider
#                      (network call carrying the secret to its own issuer; off by default)
#   --offline          no dependency lookups: OSV-Scanner matches against its local database
#                      (download it beforehand with --download-offline-databases), and the
#                      CISA KEV catalog and EPSS scores are not fetched
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

here="$(cd "$(dirname "$0")" && pwd)"

is_git=0
git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 && is_git=1

# The reviewed repository must not configure the scanners that review it: their settings files
# and inline comments can hide findings, and some settings load code. Each scanner below gets
# its settings from this script, runs on a copy without its settings files when no option turns
# them off, and runs from an empty folder (Trivy reads its settings from the folder it runs in,
# Checkov resolves relative paths from it).
neutral="$out/.scan-cwd"
imposed="$out/.scan-settings"
rm -rf "$neutral" "$imposed"
mkdir -p "$neutral" "$imposed"
in_neutral() { (cd "$neutral" && exec "$@"); }

# Lists the repository's own settings for one scanner in <scanner>-repo-settings.txt, for the
# reviewer: information, not settings. "(ignored)": this script turns them off; "(kept)": no
# option does, and the summary says LISTED.
list_settings() { # scanner, settings file names..., --, "comment:ignored" or "comment:kept"...
  local name="$1" file="$out/$1-repo-settings.txt" names=() m
  shift
  while [ $# -gt 0 ] && [ "$1" != -- ]; do names+=(-o -name "$1"); shift; done
  shift
  {
    if [ "${#names[@]}" -gt 0 ]; then
      find "$repo" -path '*/node_modules' -prune -o -path '*/.git' -prune -o \
        \( "${names[@]:1}" \) -print | sed 's/^/Settings file (ignored): /'
    fi
    for m in "$@"; do
      grep -rIl --exclude-dir=.git --exclude-dir=node_modules -e "${m%:*}" "$repo" 2>/dev/null \
        | sed "s/^/Mentions ${m%:*} (${m##*:}): /"
    done
  } > "$file"
  if grep -q '(ignored): ' "$file"; then
    record "$name settings" "IGNORED" "$file  (the repository's own exclusions: report them, look where they point)"
  fi
  if grep -q '(kept): ' "$file"; then
    record "$name skips" "LISTED" "$file  (inline suppressions this scanner cannot turn off: report them, look at what they hide)"
  fi
  [ -s "$file" ] || rm -f "$file"
}

# Copies the repository without .git, node_modules and the named settings files, for a scanner
# that would otherwise obey them.
copy_without() { # destination, file names...
  local dest="$1" names=() n
  shift
  for n in "$@"; do names+=(-o -name "$n"); done
  mkdir -p "$dest"
  find "$repo" -mindepth 1 -maxdepth 1 ! -name .git ! -name node_modules -exec cp -RP {} "$dest/" \;
  find "$dest" \( "${names[@]:1}" \) -exec rm -f {} +
}
has_named() { find "$repo" -path '*/node_modules' -prune -o -path '*/.git' -prune -o -name "$1" -print -quit | grep -q .; }

# Absolute paths in a report made on a copy name the copy: point them back at the repository.
repoint() { # report, copy
  FROM="$2" TO="$repo" awk '{ o = ""; while ((i = index($0, ENVIRON["FROM"])) > 0) { o = o substr($0, 1, i - 1) ENVIRON["TO"]; $0 = substr($0, i + length(ENVIRON["FROM"])) } print o $0 }' \
    "$1" > "$1.repointed" && mv "$1.repointed" "$1"
}

# --- Secrets ------------------------------------------------------------------
# The reviewed repository must not be able to hide its own secrets. gitleaks would obey
# its .gitleaks.toml, a .gitleaksignore (in the repository or the current folder),
# gitleaks:allow comments and the GITLEAKS_CONFIG and GITLEAKS_CONFIG_TOML variables.
# So: the reference config shipped next to this script, the comments ignored, the ignore
# path set to an empty folder, and since gitleaks 8.30 still reads <target>/.gitleaksignore
# whatever the flags say, the scans run on copies without it. gitleaks runs from inside
# the scanned folder, so reported paths are relative to the repository root.
# The repository's own settings are listed for the reviewer: information, not settings.
if have gitleaks; then
  settings="$out/gitleaks-repo-settings.txt"
  {
    for var in GITLEAKS_CONFIG GITLEAKS_CONFIG_TOML; do
      [ -n "${!var:-}" ] && echo "Environment variable $var was set (ignored)"
    done
    find "$repo" -path '*/node_modules' -prune -o -path '*/.git' -prune -o \
      \( -name '.gitleaks.toml' -o -name '.gitleaksignore' \) -print | sed 's/^/Settings file (ignored): /'
    grep -rIl --exclude-dir=.git --exclude-dir=node_modules -e 'gitleaks:allow' "$repo" 2>/dev/null \
      | sed 's/^/Mentions gitleaks:allow (ignored): /'
  } > "$settings"
  if [ -s "$settings" ]; then
    record "gitleaks settings" "IGNORED" "$settings  (the repository's own exclusions: report them, look where they point)"
  else
    rm -f "$settings"
  fi
  unset GITLEAKS_CONFIG GITLEAKS_CONFIG_TOML

  work="$out/.gitleaks-work"
  rm -rf "$work"
  mkdir -p "$work/no-ignore"
  gl_flags=(--config "$here/gitleaks.toml" --gitleaks-ignore-path "$work/no-ignore" --ignore-gitleaks-allow
    --redact --no-banner --report-format json --exit-code 0)

  src="$repo"
  if [ -e "$repo/.gitleaksignore" ] || [ -L "$repo/.gitleaksignore" ]; then
    # Copy everything but .git (which gitleaks dir skips) and the root .gitleaksignore.
    src="$work/tree"
    mkdir -p "$src"
    find "$repo" -mindepth 1 -maxdepth 1 ! -name .git ! -name .gitleaksignore -exec cp -RP {} "$src/" \;
  fi
  run gitleaks gitleaks-files.json sh -c 'cd "$1" && shift && exec "$@"' _ "$src" \
    gitleaks dir . "${gl_flags[@]}" --report-path "$out/gitleaks-files.json"

  if [ "$history" -eq 1 ] && [ "$is_git" -eq 1 ]; then
    # A bare mirror has every ref of the repository and no working tree, hence no
    # .gitleaksignore, and a fresh git config instead of the reviewed one.
    if git clone --quiet --mirror --no-local -- "$repo" "$work/history.git" >"$out/gitleaks-history.json.stderr" 2>&1; then
      run "gitleaks history" gitleaks-history.json sh -c 'cd "$1" && shift && exec "$@"' _ "$work/history.git" \
        gitleaks git . "${gl_flags[@]}" --report-path "$out/gitleaks-history.json"
    else
      record "gitleaks history" "FAILED" "could not mirror the repository for the scan, see $out/gitleaks-history.json.stderr"
    fi
  fi
  rm -rf "$work"
else
  missing gitleaks "brew install gitleaks | https://github.com/gitleaks/gitleaks"
fi

# TruffleHog obeys trufflehog:ignore comments, and PRE_COMMIT, HUSKY, HUSKY_GIT_PARAMS or
# TRUFFLEHOG_PRE_COMMIT turn the scan into a pre-commit check: HEAD..HEAD (nothing), verified
# results only, the repository's own git config trusted. So: --no-ignore-tag, the variables
# unset, and both listed for the reviewer. Its JSON keeps the secret in Raw, RawV2 and
# SecretParts, so it goes through redact-findings.py before it reaches the disk.
if [ "$history" -eq 1 ] && [ "$is_git" -eq 1 ]; then
  if have trufflehog && have python3; then
    settings="$out/trufflehog-repo-settings.txt"
    {
      for var in PRE_COMMIT HUSKY HUSKY_GIT_PARAMS TRUFFLEHOG_PRE_COMMIT; do
        [ -n "${!var:-}" ] && echo "Environment variable $var was set (ignored)"
      done
      grep -rIl --exclude-dir=.git --exclude-dir=node_modules -e 'trufflehog:ignore' "$repo" 2>/dev/null \
        | sed 's/^/Mentions trufflehog:ignore (ignored): /'
    } > "$settings"
    if [ -s "$settings" ]; then
      record "trufflehog settings" "IGNORED" "$settings  (the repository's own exclusions: report them, look where they point)"
    else
      rm -f "$settings"
    fi
    unset PRE_COMMIT HUSKY HUSKY_GIT_PARAMS TRUFFLEHOG_PRE_COMMIT

    th_flags=(--json --no-update)
    [ "$verify" -eq 1 ] || th_flags+=(--no-verification)
    # --no-ignore-tag exists since TruffleHog 3.97.5. Older versions still scan, but obey the comments.
    # (A variable, not a pipe into grep -q: pipefail would turn the early exit into a failure.)
    th_help="$(trufflehog git --help 2>&1)"
    case "$th_help" in
      *'--[no-]no-ignore-tag'*) th_flags+=(--no-ignore-tag); th_name=trufflehog ;;
      *) record "trufflehog" "OUTDATED" "obeys trufflehog:ignore comments: update to 3.97.5 or later"
         th_name="trufflehog (old)" ;;
    esac
    run "$th_name" trufflehog.json bash -c 'set -o pipefail; trufflehog git "file://$1" "${@:4}" | python3 -I "$2" trufflehog > "$3"' \
      _ "$repo" "$here/redact-findings.py" "$out/trufflehog.json" "${th_flags[@]}"
  elif have trufflehog; then
    record "trufflehog" "NOT RUN" "python3 is needed to redact the secrets from its output"
  else
    missing trufflehog "brew install trufflehog | https://github.com/trufflesecurity/trufflehog"
  fi
fi

# --- Static analysis ------------------------------------------------------------
if have semgrep || have opengrep; then
  sg=semgrep; have semgrep || sg=opengrep
  # nosemgrep comments: --disable-nosem. .semgrepignore files: the option that skips them is
  # internal, so the scan runs on a copy without them (and without .git, so no .gitignore applies).
  list_settings "$sg" .semgrepignore -- 'nosem:ignored'
  sg_src="$repo"
  if has_named .semgrepignore; then
    sg_src="$out/.semgrep-work"
    rm -rf "$sg_src"
    copy_without "$sg_src" .semgrepignore
  fi
  if [ "$sg" = semgrep ]; then
    # Semgrep keeps its log and settings under the home folder, which sandboxed agents
    # (Codex, for one) cannot write: point it at a folder inside the output directory.
    mkdir -p "$out/.semgrep-home"
    run semgrep semgrep.json in_neutral env XDG_CONFIG_HOME="$out/.semgrep-home" XDG_CACHE_HOME="$out/.semgrep-home" \
      semgrep scan --config p/default --metrics=off --disable-nosem --json \
      --output "$out/semgrep.json" --quiet "$sg_src"
  else
    run opengrep opengrep.json in_neutral opengrep scan --config p/default --disable-nosem --json \
      --output "$out/opengrep.json" --quiet "$sg_src"
  fi
  if [ "$sg_src" != "$repo" ]; then
    [ -s "$out/$sg.json" ] && repoint "$out/$sg.json" "$sg_src"
    rm -rf "$sg_src"
  fi
else
  missing semgrep "brew install semgrep | pipx install semgrep | or Opengrep"
fi

if has_files -name '*.py'; then
  if have bandit && have python3; then
    # The repository's .bandit file is replaced by an empty one, # nosec comments are ignored.
    list_settings bandit .bandit -- 'nosec:ignored'
    printf '[bandit]\n' > "$imposed/bandit.ini"
    # Bandit copies the flagged lines, and a hardcoded password's value, into its JSON.
    run bandit bandit.json in_neutral bash -c 'set -o pipefail; bandit -r "$1" -f json -q -x "*/node_modules/*,*/.venv/*" --ini "$4" --ignore-nosec | python3 -I "$2" bandit > "$3"' \
      _ "$repo" "$here/redact-findings.py" "$out/bandit.json" "$imposed/bandit.ini"
  elif have bandit; then
    record "bandit" "NOT RUN" "python3 is needed to redact the secrets from its output"
  else
    missing bandit "brew install bandit | pipx install bandit"
  fi
else
  skipped bandit "no Python files"
fi

if has_files -name '*.sh' -o -name '*.bash'; then
  if have shellcheck; then
    # --norc: no .shellcheckrc. Inline "# shellcheck disable=" comments cannot be turned off.
    list_settings shellcheck .shellcheckrc shellcheckrc -- 'shellcheck disable:kept'
    run shellcheck shellcheck.json in_neutral sh -c \
      'find "$1" -path "*/node_modules" -prune -o -path "*/.git" -prune -o -type f \( -name "*.sh" -o -name "*.bash" \) -print0 | xargs -0 shellcheck --norc -f json > "$2"' \
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
    # -IncludeSuppressed brings back the findings hidden by SuppressMessageAttribute, marked
    # IsSuppressed.
    list_settings psscriptanalyzer -- 'SuppressMessage:ignored'
    run psscriptanalyzer psscriptanalyzer.json env APPSEC_SCAN_REPO="$repo" APPSEC_SCAN_OUT="$out/psscriptanalyzer.json" \
      pwsh -NoProfile -Command \
      'Invoke-ScriptAnalyzer -Path $env:APPSEC_SCAN_REPO -Recurse -IncludeSuppressed | Select-Object RuleName, Severity, ScriptPath, Line, Message, IsSuppressed | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $env:APPSEC_SCAN_OUT'
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
    # An empty --config replaces the repository's osv-scanner.toml (ignored vulnerabilities and packages).
    list_settings osv-scanner osv-scanner.toml --
    : > "$imposed/osv-scanner.toml"
    # OSV-Scanner sends package names and versions to osv.dev (and resolves Maven dependencies
    # online). --offline stops that; without a local database it finds nothing, so say so.
    osv_flags=(--config "$imposed/osv-scanner.toml" --format json --output "$out/osv.json")
    [ "$offline" -eq 1 ] && osv_flags+=(--offline)
    run osv-scanner osv.json osv-scanner scan source -r "$repo" "${osv_flags[@]}"
    if [ "$offline" -eq 1 ] && grep -q 'no offline version of the OSV database' "$out/osv.json.stderr" 2>/dev/null; then
      record "osv-scanner" "NO DATABASE" "nothing was checked: run osv-scanner scan source --offline-vulnerabilities --download-offline-databases -r <repo> once online"
    fi
    # Known exploited (CISA KEV) and likely exploited (EPSS) first.
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
    # The reviewed repository must not configure Checkov. Its .checkov.yaml (or .yml) can import
    # Python (external-checks-dir, external-checks-git) and hide findings (skip-check, ...);
    # --config-file adds to it instead of replacing it. Checkov reads that file from the scanned
    # folder, then from the folder it runs in, so it scans a copy without it, from an empty folder
    # (which also keeps its .external_modules cache out of the repository). Inline #checkov:skip
    # comments cannot be turned off: they are listed for the reviewer.
    settings="$out/checkov-repo-settings.txt"
    {
      find "$repo" -path '*/node_modules' -prune -o -path '*/.git' -prune -o \
        \( -name '.checkov.yaml' -o -name '.checkov.yml' \) -print | sed 's/^/Settings file (ignored): /'
      grep -rIl --exclude-dir=.git --exclude-dir=node_modules -e 'checkov:skip' "$repo" 2>/dev/null \
        | sed 's/^/Mentions checkov:skip (kept): /'
    } > "$settings"
    if grep -q '^Settings file' "$settings"; then
      record "checkov settings" "IGNORED" "$settings  (the repository's own Checkov configuration: report it, look at what it skips and loads)"
    fi
    if grep -q '^Mentions' "$settings"; then
      record "checkov skips" "LISTED" "$settings  (inline #checkov:skip comments stay in force: report them, look at what they hide)"
    fi
    [ -s "$settings" ] || rm -f "$settings"

    work="$out/.checkov-work"
    rm -rf "$work"
    mkdir -p "$work/cwd"
    src="$repo"
    if has_named .checkov.yaml || has_named .checkov.yml; then
      src="$work/tree"
      copy_without "$src" .checkov.yaml .checkov.yml
    fi
    run checkov checkov.json sh -c 'cd "$1" && checkov -d "$2" --quiet --compact -o json > "$3"' _ "$work/cwd" "$src" "$out/checkov.json"
    if [ "$src" != "$repo" ] && [ -s "$out/checkov.json" ]; then
      repoint "$out/checkov.json" "$src"
    fi
    rm -rf "$work"
  else
    missing checkov "pipx install checkov | brew install checkov"
  fi
  if have trivy; then
    # Trivy reads .trivyignore and trivy.yaml from the folder it runs in: none, from the empty folder,
    # and both turned off by name. Inline #trivy:ignore comments cannot be turned off.
    list_settings trivy .trivyignore .trivyignore.yaml trivy.yaml -- 'trivy:ignore:kept'
    run "trivy config" trivy-config.json in_neutral trivy config --quiet --ignorefile '' --config '' \
      --format json --output "$out/trivy-config.json" "$repo"
  fi
else
  skipped checkov "no IaC or container files"
fi

# --- CI workflows -------------------------------------------------------------------
if [ -d "$repo/.github/workflows" ]; then
  if have zizmor; then
    # --no-config: no zizmor.yml from the repository. --no-ignores: no "# zizmor: ignore" comments.
    list_settings zizmor zizmor.yml zizmor.yaml -- 'zizmor: ignore:ignored'
    run zizmor zizmor.json in_neutral sh -c 'zizmor --offline --no-config --no-ignores --format json "$1" > "$2"' _ "$repo" "$out/zizmor.json"
  else
    missing zizmor "brew install zizmor | pipx install zizmor"
  fi
else
  skipped zizmor "no GitHub Actions workflows"
fi

rm -rf "$neutral" "$imposed"

# --- Summary --------------------------------------------------------------------------
echo "Scanner outputs: $out"
printf '%s\n' "${summary[@]}"
