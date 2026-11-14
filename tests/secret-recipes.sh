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

run_recipe 2 "$out/shape"; check "shape: length of each value, no prefix for a key without a public marker" grep -qx 'LLM_API_KEY: [0-9][0-9]* characters, no public type prefix' "$out/shape"
check "shape: no secret value" no_secret "$out/shape"
no_first_chars() { # file: not even the first 4 characters of a history value
  local s
  while IFS= read -r s; do
    if [ "${#s}" -ge 4 ] && grep -qF -- "${s:0:4}" "$1"; then return 1; fi
  done < <(git -C "$copy" log --all --format='%H' -- .env.production | while read -r c; do
    git -C "$copy" show "$c:.env.production" 2>/dev/null | cut -d= -f2-
  done)
}
check "shape: no first characters of a value without a public marker" no_first_chars "$out/shape"

# Public type markers are shown, and nothing after them: fake values written as a blob of the temporary copy.
filler="$(printf 'Q%.0s' {1..24})"
blob="$(printf '# comment\nSTRIPE=sk_live_%s\nAWS="AKIA%s"\nSLACK=xoxb-%s\nPLAIN=%s\n' "$filler" "$filler" "$filler" "$filler" | git -C "$copy" hash-object -w --stdin)"
cmd="${commands[2]}"; cmd="${cmd//<commit>:<path>/$blob}"
(cd "$copy" && bash -c "$cmd") > "$out/markers" 2>&1
check "shape: public markers shown" sh -c 'grep -qx "STRIPE: 32 characters, public type prefix sk_live_" "$1" && grep -qx "AWS: 28 characters, public type prefix AKIA" "$1" && grep -qx "SLACK: 29 characters, public type prefix xoxb-" "$1"' _ "$out/markers"
check "shape: other values get their length only" grep -qx 'PLAIN: 24 characters, no public type prefix' "$out/markers"
check "shape: nothing after a marker, no comment line" sh -c '! grep -qE "Q|comment" "$1"' _ "$out/markers"

# Lines that are not NAME=value give their line number and length only: a key block (its last line padded
# with "=", which looks like NAME=), the rest of a quoted value on later lines (an escaped quote does not
# close it), a padded base64 line outside any block, a JSON line from a *.tfstate.
blob="$(printf 'export TOKEN="sk_test_%s"\n-----BEGIN FAKE KEY-----\n%s\nQQQQQQQQ==\n-----END FAKE KEY-----\n  "password": "Q%s=Q",\nMULTI="-----BEGIN FAKE KEY-----\nQQQQtail=\n-----END FAKE KEY-----"\nAFTER=x\nJ="{\\"a\\":\\"Q\\"\nQQQQ==\n}"\n  QQQQQQQQ==\n' "$filler" "$filler" "$filler" | git -C "$copy" hash-object -w --stdin)"
for i in 1 2; do
  cmd="${commands[$i]}"; cmd="${cmd//<commit>:<path>/$blob}"
  (cd "$copy" && bash -c "$cmd") > "$out/other$i" 2>&1
done
check "names: export prefix removed, names before and after the other lines" sh -c 'grep -qx TOKEN "$1" && grep -qx MULTI "$1" && grep -qx AFTER "$1"' _ "$out/other1"
check "names: key block, JSON, quoted values and padding as line number and length" sh -c 'grep -qx "line 4: key block, 10 characters" "$1" && grep -qx "line 6: not NAME=value, 44 characters" "$1" && grep -qx "line 8: rest of a quoted value, 9 characters" "$1" && grep -qx "line 12: rest of a quoted value, 6 characters" "$1" && grep -qx "line 14: empty value or base64 padding, 12 characters" "$1"' _ "$out/other1"
check "shape: export prefix removed, multi-line value flagged, value after it read" sh -c 'grep -qx "TOKEN: 32 characters, public type prefix sk_test_" "$1" && grep -qx "MULTI: 24 characters, no public type prefix, continued on later lines" "$1" && grep -qx "AFTER: 1 characters, no public type prefix" "$1"' _ "$out/other2"
check "shape: key block, JSON, quoted values and padding as line number and length" sh -c 'grep -qx "line 4: key block, 10 characters" "$1" && grep -qx "line 6: not NAME=value, 44 characters" "$1" && grep -qx "line 8: rest of a quoted value, 9 characters" "$1" && grep -qx "line 12: rest of a quoted value, 6 characters" "$1" && grep -qx "line 14: empty value or base64 padding, 12 characters" "$1"' _ "$out/other2"
check "names and shape: nothing of a line that is not NAME=value" sh -c '! grep -qE "Q|BEGIN|password|tail" "$1" "$2"' _ "$out/other1" "$out/other2"

# A closing quote followed by spaces and "#" ends the value: the names after it are read. A "#" inside the
# quotes, or with no closing quote before it, does not: the value goes on, and its later lines (even one that
# looks like NAME=value) give their line number and length only.
blob="$(printf 'A="QQQQ" # note\nB='"'"'QQQQ'"'"' # note\nC="Q#Q"\nD="QQQQ # note\nHIDDEN=QQQQ\nQQ"\nAFTER=z\n' | git -C "$copy" hash-object -w --stdin)"
for i in 1 2; do
  cmd="${commands[$i]}"; cmd="${cmd//<commit>:<path>/$blob}"
  (cd "$copy" && bash -c "$cmd") > "$out/comment$i" 2>&1
done
check "names: a trailing comment closes a quoted value, a quoted # does not" sh -c 'grep -qx A "$1" && grep -qx B "$1" && grep -qx C "$1" && grep -qx D "$1" && grep -qx AFTER "$1" && grep -qx "line 5: rest of a quoted value, 11 characters" "$1" && grep -qx "line 6: rest of a quoted value, 3 characters" "$1"' _ "$out/comment1"
check "shape: a trailing comment is not part of the value, a quoted # is" sh -c 'grep -qx "A: 4 characters, no public type prefix" "$1" && grep -qx "B: 4 characters, no public type prefix" "$1" && grep -qx "C: 3 characters, no public type prefix" "$1" && grep -qx "D: 11 characters, no public type prefix, continued on later lines" "$1" && grep -qx "line 5: rest of a quoted value, 11 characters" "$1" && grep -qx "line 6: rest of a quoted value, 3 characters" "$1" && grep -qx "AFTER: 1 characters, no public type prefix" "$1"' _ "$out/comment2"
check "names and shape: no value, no comment, nothing of a continued line" sh -c '! grep -qE "Q|note|HIDDEN" "$1" "$2"' _ "$out/comment1" "$out/comment2"
# Between single quotes a backslash escapes nothing: in A='Q\'Q' # note the quote after the backslash closes
# the value and the next one opens a new one, which goes on to the following lines.
blob="$(printf 'A=%sQ\\%sQ%s # note\nHIDDEN=QQQQ\n' "'" "'" "'" | git -C "$copy" hash-object -w --stdin)"
for i in 1 2; do
  cmd="${commands[$i]}"; cmd="${cmd//<commit>:<path>/$blob}"
  (cd "$copy" && bash -c "$cmd") > "$out/single$i" 2>&1
done
check "names and shape: no backslash escape between single quotes" sh -c 'grep -qx "line 2: rest of a quoted value, 11 characters" "$1" && grep -qx "line 2: rest of a quoted value, 11 characters" "$2" && ! grep -qE "Q|note|HIDDEN" "$1" "$2"' _ "$out/single1" "$out/single2"

run_recipe 3 "$out/claims"; check "claims: the JWT's role is readable" grep -q '"role" *: *"service_role"' "$out/claims"
check "claims: no secret value (no signature)" no_secret "$out/claims"

# Control: the raw patch the reference replaces does show the secrets, so the checks above can fail.
(cd "$copy" && git log --all -p -- .env.production) > "$out/raw"
shows_secret() { ! no_secret "$1"; }
check "control: a raw git log -p is caught as showing secrets" shows_secret "$out/raw"

if [ "$fail" -ne 0 ]; then echo "some checks failed"; exit 1; fi
echo "all checks passed"
