#!/usr/bin/env bash
# run-scanners.sh must find secrets that the reviewed repository tries to hide from gitleaks:
# its .gitleaks.toml, its .gitleaksignore, gitleaks:allow comments, a .gitleaksignore in the
# folder the script is run from, and the GITLEAKS_CONFIG and GITLEAKS_CONFIG_TOML variables.
#
#   bash tests/run-scanners-gitleaks.sh [path/to/run-scanners.sh]
#
# Needs gitleaks 8.30 or later. The fake tokens are built at run time and never written
# to this repository: a sha256 of a label, so they look random to gitleaks and are not real.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="${1:-$here/../skills/appsec-review/scripts/run-scanners.sh}"
script="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"
command -v gitleaks >/dev/null 2>&1 || { echo "gitleaks is not installed" >&2; exit 2; }

tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
fake() { printf 'ghp_%s' "$(printf 'appsec-skills fake token %s' "$1" | shasum -a 256 | cut -c1-36)"; }

repo="$tmp/hostile"
mkdir -p "$repo"
# No template: a hook installed by the user's git template must not run in this throwaway repository.
git init -q --template= "$repo"
g() { git -C "$repo" -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

# A secret only in history: committed, then deleted.
echo "old = \"$(fake history)\"" > "$repo/old.py"
g add old.py && g commit -q -m old && g rm -q old.py && g commit -q -m "remove old"
history_commit="$(g rev-list --all | tail -n 1)"

echo "token = \"$(fake tree)\"" > "$repo/app.py"
echo "other = \"$(fake allow)\"  # gitleaks:allow" > "$repo/allow.py"
# Every way the repository can tell gitleaks to look away.
printf '[allowlist]\npaths = [".*"]\n' > "$repo/.gitleaks.toml"
{
  for f in app.py allow.py old.py; do
    echo "$f:github-pat:1"
    echo "$repo/$f:github-pat:1"
    echo "$history_commit:$f:github-pat:1"
  done
} > "$repo/.gitleaksignore"
g add -A && g commit -q -m "add app"
cp "$repo/.gitleaksignore" "$tmp/cwd.gitleaksignore"
printf '[allowlist]\nregexes = [".*"]\n' > "$tmp/hostile.toml"

out="$tmp/out"
mkdir -p "$tmp/cwd" && cp "$tmp/cwd.gitleaksignore" "$tmp/cwd/.gitleaksignore"
(cd "$tmp/cwd" && GITLEAKS_CONFIG="$tmp/hostile.toml" GITLEAKS_CONFIG_TOML="$(cat "$tmp/hostile.toml")" \
  bash "$script" "$repo" "$out" --history --offline) > "$tmp/summary.txt" 2>&1

fail=0
check() { # description, command...
  local what="$1"; shift
  if "$@"; then echo "ok   - $what"; else echo "FAIL - $what"; fail=1; fi
}
found() { grep -Eq "\"File\": \"(.*/)?$2\"" "$out/$1" 2>/dev/null; }

check "secret in the tree found despite .gitleaks.toml, .gitleaksignore and the variables" found gitleaks-files.json app.py
check "secret marked gitleaks:allow found" found gitleaks-files.json allow.py
check "secret in history found despite .gitleaksignore" found gitleaks-history.json old.py
check "the repository's settings are listed for the reviewer" grep -q 'gitleaks settings *IGNORED' "$tmp/summary.txt"
for item in "Settings file (ignored): $repo/.gitleaks.toml" "Settings file (ignored): $repo/.gitleaksignore" \
  "Mentions gitleaks:allow (ignored): $repo/allow.py" "Environment variable GITLEAKS_CONFIG was set" \
  "Environment variable GITLEAKS_CONFIG_TOML was set"; do
  check "listed: $item" grep -qF "$item" "$out/gitleaks-repo-settings.txt"
done
no_secret_in_outputs() { ! grep -rqF -e "$(fake tree)" -e "$(fake allow)" -e "$(fake history)" "$out"/gitleaks-* "$tmp/summary.txt"; }
check "no secret value in the gitleaks outputs (redacted)" no_secret_in_outputs
check "the reviewed repository is left untouched" test -z "$(g status --porcelain)"
check "no working copy left in the output folder" test ! -e "$out/.gitleaks-work"

if [ "$fail" -ne 0 ]; then
  echo "--- run-scanners.sh summary"; cat "$tmp/summary.txt"
  exit 1
fi
