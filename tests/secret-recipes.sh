#!/usr/bin/env bash
# The commands that references/secrets-supply-chain.md gives for looking at a secret without
# reading it must do what they say: on the bench's blind copy, which commits fake secrets on
# purpose, each one prints the facts a reviewer needs and none of the secret values.
#
#   bash tests/secret-recipes.sh
#
# The commands are taken from the reference itself, so the test follows what is published.
# Needs git and python3. The fake secrets never leave the temporary copy and this test's output.
# The sh -c snippets take their values as positional parameters on purpose.
# shellcheck disable=SC2016
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$here/.."
ref="$root/skills/appsec-review/references/secrets-supply-chain.md"

copy="$(bash "$root/bench/setup.sh" vulnerable)" || { echo "bench/setup.sh failed" >&2; exit 2; }
trap 'rm -rf "$(dirname "$copy")"' EXIT

# The fenced bash blocks of the "Looking at a secret without reading it" section, one per line.
commands=()
while IFS= read -r line; do commands+=("$line"); done < <(python3 -I - "$ref" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
section = text.split("### Looking at a secret without reading it", 1)[1].split("\nJudging a match", 1)[0]
for block in re.findall(r"```bash\n(.*?)\n\s*```", section, re.S):
    print(block.strip())
PY
)
[ "${#commands[@]}" -eq 4 ] || { echo "expected 4 commands in the reference, found ${#commands[@]}" >&2; exit 1; }

# The secrets seeded in the copy: the history file's values, the JWT's signature, the script password.
secrets=()
while IFS= read -r s; do [ -n "$s" ] && secrets+=("$s"); done < <(
  git -C "$copy" log --all --format='%H' -- .env.production | while read -r c; do
    git -C "$copy" show "$c:.env.production" 2>/dev/null | cut -d= -f2-
  done
  grep -o 'eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*\.[A-Za-z0-9_-]*' "$copy/public/config.js" | cut -d. -f3
  grep -o "ConvertTo-SecureString '[^']*'" "$copy/scripts/Sync-Users.ps1" | cut -d"'" -f2
)
[ "${#secrets[@]}" -ge 4 ] || { echo "could not read the seeded secrets" >&2; exit 2; }

fail=0
check() { # description, command...
  local what="$1"; shift
  if "$@"; then echo "ok   - $what"; else echo "FAIL - $what"; fail=1; fi
}
no_secret() { # file
  local s
  for s in "${secrets[@]}"; do
    if grep -qF -- "$s" "$1" || grep -qF -- "${s:4:12}" "$1"; then return 1; fi
  done
}

run_recipe() { # number, output file, placeholder values...
  local cmd="${commands[$1]}"
  cmd="${cmd//<path>/.env.production}"
  cmd="${cmd//<commit>/$commit}"
  cmd="${cmd//<file>/public/config.js}"
  (cd "$copy" && bash -c "$cmd") > "$2" 2>&1
}

out="$(mktemp -d)"
trap 'rm -rf "$(dirname "$copy")" "$out"' EXIT
commit="$(git -C "$copy" log --all --diff-filter=A --format='%h' -- .env.production)"

run_recipe 0 "$out/history" ; check "history: names the commit that added the file" grep -q "^$commit .*" "$out/history"
check "history: names the file" grep -q '\.env\.production' "$out/history"
check "history: no secret value" no_secret "$out/history"

run_recipe 1 "$out/names"; check "names: lists both variables" sh -c 'grep -qx DATABASE_URL "$1" && grep -qx LLM_API_KEY "$1"' _ "$out/names"
check "names: no secret value" no_secret "$out/names"

run_recipe 2 "$out/shape"; check "shape: prefix and length of each value" grep -q '^LLM_API_KEY=llmk\.\.\. ([0-9]* characters)$' "$out/shape"
check "shape: no secret value" no_secret "$out/shape"

run_recipe 3 "$out/claims"; check "claims: the JWT's role is readable" grep -q '"role" *: *"service_role"' "$out/claims"
check "claims: no secret value (no signature)" no_secret "$out/claims"

# Control: the raw patch the reference replaces does show the secrets, so the checks above can fail.
(cd "$copy" && git log --all -p -- .env.production) > "$out/raw"
shows_secret() { ! no_secret "$1"; }
check "control: a raw git log -p is caught as showing secrets" shows_secret "$out/raw"

if [ "$fail" -ne 0 ]; then echo "some checks failed"; exit 1; fi
echo "all checks passed"
