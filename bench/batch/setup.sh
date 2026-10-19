#!/usr/bin/env bash
# Builds a blind scratch git repository from bench/batch/app and prints its path.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="${TMPDIR:-/tmp}"
dest="$(mktemp -d "${tmp%/}/review.XXXXXX")/receiptly"
mkdir -p "$dest"
cp -R "$here/app/." "$dest/"
cd "$dest"
git init -q -b main
git config user.name "Receiptly dev"
git config user.email "dev@receiptly.example"
git config commit.gpgsign false
git add -A
git commit -q -m "Receiptly 1.0"
echo "$dest"
