#!/usr/bin/env bash
# Builds a blind scratch git repository from bench/deps/app and prints its path.
# The copy holds the application only: no answer key, no rubric.
# Dependency manifests are stored as *.fixture so that GitHub's dependency graph does not
# raise alerts for these deliberately outdated versions; the copy gets their real names.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="${TMPDIR:-/tmp}"
dest="$(mktemp -d "${tmp%/}/review.XXXXXX")/ledgerly"
mkdir -p "$dest"
cp -R "$here/app/." "$dest/"
cd "$dest"
find . -name '*.fixture' -type f | while IFS= read -r f; do mv "$f" "${f%.fixture}"; done
# Throwaway repository of seeded test material: created without hooks (--template=), never pushed.
git init -q --template= -b main
git config user.name "Ledgerly dev"
git config user.email "dev@ledgerly.example"
git config commit.gpgsign false
git add -A
git commit -q -m "Ledgerly 1.4"
echo "$dest"
