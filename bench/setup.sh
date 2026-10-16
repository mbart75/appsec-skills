#!/usr/bin/env bash
# Builds a scratch git repository from one bench variant, ready to be reviewed.
#
#   bench/setup.sh vulnerable    prints the path of a fresh copy of vulnerable-app
#   bench/setup.sh secure        same for secure-app
#
# The copy lives outside this repository and contains only the application:
# no answer key, no README about seeded flaws, so the reviewing agent starts blind.
# The vulnerable variant also gets a git history in which a secret was committed
# and later deleted (flaw V34): it is gone from the files, not from the history.
set -euo pipefail

variant="${1:?usage: setup.sh vulnerable|secure}"
case "$variant" in
  vulnerable|secure) ;;
  *) echo "unknown variant: $variant (expected vulnerable or secure)" >&2; exit 1 ;;
esac

here="$(cd "$(dirname "$0")" && pwd)"
# Neutral directory name: the path must not tell the reviewing agent which variant it is.
tmp="${TMPDIR:-/tmp}"
dest="$(mktemp -d "${tmp%/}/review.XXXXXX")/tinyshop"
mkdir -p "$dest"
cd "$dest"

git init -q -b main
git config user.name "TinyShop dev"
git config user.email "dev@tinyshop.example"
git config commit.gpgsign false

if [ "$variant" = vulnerable ]; then
  # Fake values: no provider issues keys with this format.
  cat > .env.production <<'ENV'
DATABASE_URL=postgres://tinyshop:z8fHI9c6G5QxDAyaDCjkftQ7@db.qzvtkmwbrlnhxpsd.supabase.co:5432/postgres
LLM_API_KEY=llmk_live_AlM1ZEGn1rU9NQLR5f2DbYmD46Svizz5xUKjFdwX
ENV
  git add .env.production
  git commit -q -m "chore: production settings"
  git rm -q .env.production
  git commit -q -m "chore: remove env file"
fi

cp -R "$here/${variant}-app/." .
# Leftovers from local runs are not part of the application.
find . \( -name __pycache__ -o -name node_modules -o -name .DS_Store \) -prune -exec rm -rf {} +
git add -A
git commit -q -m "TinyShop 0.3.0"
echo "$dest"
