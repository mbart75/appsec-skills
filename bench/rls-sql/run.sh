#!/usr/bin/env bash
# Tests the Supabase SQL published in the skills on a throwaway local PostgreSQL:
# the RLS baseline of appsec-harden (behaviour, as each account) and the read-only
# checklist queries of appsec-review (they run, and they flag known misconfigurations).
#
#   bash bench/rls-sql/run.sh            (PostgreSQL 15+ binaries on PATH, or PG_BIN=<bin dir>)
#
# The database lives in a temporary folder, listens on a Unix socket only (no TCP), and is
# deleted at the end. Exit code 1 if any test fails or a published query is out of sync.
set -euo pipefail
export LC_ALL=C LANG=C   # PostgreSQL refuses to start without a valid locale
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../.." && pwd)"
if [ -z "${PG_BIN:-}" ]; then
  if command -v pg_ctl >/dev/null 2>&1; then PG_BIN="$(dirname "$(command -v pg_ctl)")"
  elif command -v brew >/dev/null 2>&1 && [ -d "$(brew --prefix)/opt/postgresql@17/bin" ]; then PG_BIN="$(brew --prefix)/opt/postgresql@17/bin"
  else echo "PostgreSQL not found: install it or set PG_BIN" >&2; exit 2; fi
fi

fails=0
while IFS='|' read -r doc query; do
  case "$doc" in ''|'#'*) continue ;; esac
  if ! grep -qF -- "$query" "$repo/$doc"; then echo "OUT OF SYNC: query no longer in $doc: $query"; fails=$((fails + 1)); fi
done < "$here/queries.txt"

tmp="$(mktemp -d)"
cleanup() { "$PG_BIN/pg_ctl" -D "$tmp/data" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$tmp"; }
trap cleanup EXIT
"$PG_BIN/initdb" -D "$tmp/data" -U postgres --auth=trust --locale=C --encoding=UTF8 >/dev/null
"$PG_BIN/pg_ctl" -D "$tmp/data" -l "$tmp/log" -w -o "-k $tmp -p 54329 -c listen_addresses=''" start >/dev/null
psql_() { "$PG_BIN/psql" -h "$tmp" -p 54329 -U postgres -d postgres -X -v ON_ERROR_STOP=1 "$@"; }

for f in 01-supabase-sim.sql 02-baseline.sql 03-bad.sql; do psql_ -q -f "$here/$f" >/dev/null; done

out="$(psql_ -f "$here/04-behaviour.sql" 2>&1; psql_ -f "$here/05-detection.sql" 2>&1)"
printf '%s\n' "$out" | sed -n 's/^.*NOTICE:  //p'

while IFS='|' read -r doc query; do
  case "$doc" in ''|'#'*) continue ;; esac
  q="${query//<table>/profiles}"; q="${q//<function>/unsafe_fn}"
  if ! psql_ -q -c "$q" >/dev/null 2>"$tmp/err"; then echo "FAIL query does not run ($doc): $q"; cat "$tmp/err"; fails=$((fails + 1)); fi
done < "$here/queries.txt"

fails=$((fails + $(printf '%s\n' "$out" | grep -c 'NOTICE:  FAIL' || true)))
errors="$(printf '%s\n' "$out" | grep -c '^psql:.*ERROR' || true)"
[ "$errors" -gt 0 ] && { printf '%s\n' "$out" | grep '^psql:.*ERROR'; fails=$((fails + errors)); }
echo "published queries checked: $(grep -cv '^#' "$here/queries.txt")"
if [ "$fails" -eq 0 ]; then echo "ALL PASS"; else echo "$fails FAILURE(S)"; exit 1; fi
