#!/usr/bin/env bash
# run-scanners.sh must find secrets that the reviewed repository hides from TruffleHog
# (trufflehog:ignore comments, in the tree and in history, and the PRE_COMMIT, HUSKY,
# HUSKY_GIT_PARAMS and TRUFFLEHOG_PRE_COMMIT variables, which turn the scan into an empty
# pre-commit check), and no file it writes may hold a secret value in clear: TruffleHog's
# Raw, RawV2 and SecretParts, Bandit's code and "Possible hardcoded password" text.
#
#   bash tests/run-scanners-secrets.sh [path/to/run-scanners.sh]
#
# Needs trufflehog 3.99 or later, bandit and python3. Every other scanner installed also
# runs, and its outputs are checked too. The fake secrets are built at run time and never
# written to this repository: a sha256 of a label, so they look random and are not real.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="${1:-$here/../skills/appsec-review/scripts/run-scanners.sh}"
script="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"
for tool in trufflehog bandit python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "$tool is not installed" >&2; exit 2; }
done

tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT
hex() { printf 'appsec-skills fake secret %s' "$1" | shasum -a 256 | cut -c1-"$2"; }
fake() { printf 'ghp_%s' "$(hex "$1" 36)"; }
password="$(hex password 24)"

repo="$tmp/hostile"
mkdir -p "$repo"
# No template: a hook installed by the user's git template must not run in this throwaway repository.
git init -q --template= "$repo"
g() { git -C "$repo" -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false "$@"; }

# A secret only in history, marked to be ignored: committed, then deleted.
echo "old = \"$(fake history)\"  # trufflehog:ignore" > "$repo/old.py"
g add old.py && g commit -q -m old && g rm -q old.py && g commit -q -m "remove old"

echo "token = \"$(fake tree)\"  # trufflehog:ignore" > "$repo/app.py"
# Not hidden: TruffleHog reports it on any version, so its output must not hold the value.
echo "key = \"$(fake visible)\"" > "$repo/visible.py"
echo "password = \"$password\"" > "$repo/settings.py"
g add -A && g commit -q -m "add app"

# Two runs: the comments alone, then the comments with the variables set.
env -u PRE_COMMIT -u HUSKY -u HUSKY_GIT_PARAMS -u TRUFFLEHOG_PRE_COMMIT \
  bash "$script" "$repo" "$tmp/plain" --history --offline > "$tmp/plain.txt" 2>&1
PRE_COMMIT=1 HUSKY=1 HUSKY_GIT_PARAMS=x TRUFFLEHOG_PRE_COMMIT=1 \
  bash "$script" "$repo" "$tmp/env" --history --offline > "$tmp/env.txt" 2>&1

fail=0
check() { # description, command...
  local what="$1"; shift
  if "$@"; then echo "ok   - $what"; else echo "FAIL - $what"; fail=1; fi
}
# TruffleHog writes one JSON object per line; the file is in SourceMetadata.Data.Git.file.
th_found() { python3 -I -c '
import json, sys
files = set()
for line in open(sys.argv[1]):
    if line.strip():
        files.add(json.loads(line)["SourceMetadata"]["Data"]["Git"]["file"])
sys.exit(0 if sys.argv[2] in files else 1)' "$tmp/$1/trufflehog.json" "$2" 2>/dev/null; }
bandit_found() { grep -q "\"test_id\": \"B105\"" "$tmp/plain/bandit.json" 2>/dev/null; }

check "secret without any comment found" th_found plain visible.py
check "secret in the tree found despite trufflehog:ignore" th_found plain app.py
check "secret in history found despite trufflehog:ignore" th_found plain old.py
check "secret found despite the pre-commit variables" th_found env app.py
check "hardcoded password still reported by bandit" bandit_found
check "the repository's settings are listed for the reviewer" grep -q 'trufflehog settings *IGNORED' "$tmp/env.txt"
for item in "Mentions trufflehog:ignore (ignored): $repo/app.py" \
  "Environment variable PRE_COMMIT was set (ignored)" "Environment variable HUSKY was set (ignored)" \
  "Environment variable HUSKY_GIT_PARAMS was set (ignored)" "Environment variable TRUFFLEHOG_PRE_COMMIT was set (ignored)"; do
  check "listed: $item" grep -qF "$item" "$tmp/env/trufflehog-repo-settings.txt"
done
leaks() { grep -rlF -e "$(fake tree)" -e "$(fake history)" -e "$(fake visible)" -e "$password" "$tmp/plain" "$tmp/env" "$tmp/plain.txt" "$tmp/env.txt"; }
check "no secret value in any scanner output" test -z "$(leaks)"
check "the reviewed repository is left untouched" test -z "$(g status --porcelain)"

if [ "$fail" -ne 0 ]; then
  echo "--- files holding a secret value"; leaks
  echo "--- run-scanners.sh summaries"; cat "$tmp/plain.txt" "$tmp/env.txt"
  exit 1
fi
