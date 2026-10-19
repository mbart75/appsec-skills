#!/usr/bin/env bash
# Builds a blind scratch git repository from bench/deps/app and prints its path.
# The copy holds the application only: no answer key, no rubric.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="${TMPDIR:-/tmp}"
dest="$(mktemp -d "${tmp%/}/review.XXXXXX")/ledgerly"
mkdir -p "$dest"
cp -R "$here/app/." "$dest/"
cd "$dest"
git init -q -b main
git config user.name "Ledgerly dev"
git config user.email "dev@ledgerly.example"
git config commit.gpgsign false
git add -A
git commit -q -m "Ledgerly 1.4"
echo "$dest"
