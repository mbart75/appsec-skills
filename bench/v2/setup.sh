#!/usr/bin/env bash
# Builds a blind copy of one bench v2 case, ready to be reviewed.
#
#   bench/v2/setup.sh <case-id> vulnerable|fixed     e.g. bench/v2/setup.sh R03 vulnerable
#
# Fetches only the requested commit, then re-creates the tree with a fresh
# single-commit history: the reviewer cannot read the upstream history, the
# later fix, or the advisory. Prints the path of the copy.
set -euo pipefail

case_id="${1:?usage: setup.sh <case-id> vulnerable|fixed}"
variant="${2:?usage: setup.sh <case-id> vulnerable|fixed}"
case "$variant" in vulnerable|fixed) ;; *) echo "variant must be vulnerable or fixed" >&2; exit 1 ;; esac

here="$(cd "$(dirname "$0")" && pwd)"
# Minimal reader for cases.yaml: the block of the requested case, then its fields.
block="$(awk -v id="$case_id" '
  $0 ~ "^  - id: " { inblock = ($3 == id) }
  inblock { print }
' "$here/cases.yaml")"
[ -n "$block" ] || { echo "unknown case: $case_id" >&2; exit 1; }
field() { printf '%s\n' "$block" | awk -v k="$1" '$1 == k":" { print $2; exit }'; }
repo="$(field repo)"
commit="$(field "$variant")"
if [ -z "$repo" ] || [ -z "$commit" ]; then echo "incomplete case: $case_id" >&2; exit 1; fi

tmp="${TMPDIR:-/tmp}"
fetch="$(mktemp -d "${tmp%/}/fetch.XXXXXX")"
trap 'rm -rf "$fetch"' EXIT
# Throwaway repositories of third-party code at a vulnerable commit: created without hooks (--template=), never pushed.
git -C "$fetch" init -q --template=
git -C "$fetch" fetch -q --depth 1 "https://github.com/$repo.git" "$commit"
git -C "$fetch" checkout -q FETCH_HEAD

# Neutral directory name: neither the case nor the variant is visible in the path.
dest="$(mktemp -d "${tmp%/}/review.XXXXXX")/project"
mkdir -p "$dest"
(cd "$fetch" && tar --exclude=.git -cf - .) | (cd "$dest" && tar -xf -)
git -C "$dest" init -q --template= -b main
git -C "$dest" config user.name "dev"
git -C "$dest" config user.email "dev@example.invalid"
git -C "$dest" config commit.gpgsign false
git -C "$dest" add -A
git -C "$dest" commit -q -m "import"
echo "$dest"
