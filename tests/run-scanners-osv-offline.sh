#!/usr/bin/env bash
# run-scanners.sh --offline must keep OSV-Scanner offline: without it, OSV-Scanner sends every
# package name and version to osv.dev. And an offline scan without a local database finds
# nothing, so the summary must say so instead of looking clean.
#
#   bash tests/run-scanners-osv-offline.sh [path/to/run-scanners.sh]
#
# Uses a stand-in osv-scanner that records its arguments, so it needs no network and no
# scanner. When a real osv-scanner is installed, it also runs it offline with an empty cache.
# The sh -c snippets take their values as positional parameters on purpose.
# shellcheck disable=SC2016
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="${1:-$here/../skills/appsec-review/scripts/run-scanners.sh}"
script="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"
real_osv="$(command -v osv-scanner || true)"

tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

fails=0
check() { # description, command...
  local what="$1"; shift
  if "$@"; then echo "ok   $what"; else echo "FAIL $what"; fails=$((fails + 1)); fi
}

# A repository with one dependency manifest, so that the dependency step runs. OSV-Scanner skips
# a lockfile entry without "resolved", so the entry has one.
repo="$tmp/repo"
mkdir -p "$repo"
git init -q --template= "$repo"
cat > "$repo/package-lock.json" <<'EOF'
{"name":"x","version":"1.0.0","lockfileVersion":3,"requires":true,
 "packages":{"":{"name":"x","version":"1.0.0","dependencies":{"lodash":"4.17.15"}},
 "node_modules/lodash":{"version":"4.17.15","resolved":"https://registry.npmjs.org/lodash/-/lodash-4.17.15.tgz"}}}
EOF

# The stand-in behaves like OSV-Scanner 2.x without a local database: offline, it writes an empty
# result and fails with the real message. Online, it writes an empty file, so cve-priority.py does
# not run (it would fetch KEV and EPSS).
mkdir -p "$tmp/bin" "$tmp/home"
cat > "$tmp/bin/osv-scanner" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$tmp/osv-args"
out=""
prev=""
for a in "\$@"; do [ "\$prev" = "--output" ] && out="\$a"; prev="\$a"; done
case " \$* " in
  *" --offline "*)
    printf '{"results": []}\n' > "\$out"
    echo "Error during extraction: unable to fetch OSV database: no offline version of the OSV database is available" >&2
    exit 127 ;;
  *) : > "\$out" ;;
esac
EOF
chmod +x "$tmp/bin/osv-scanner"
export HOME="$tmp/home"

PATH="$tmp/bin:/usr/bin:/bin" bash "$script" "$repo" "$tmp/out-online" > "$tmp/summary-online" 2>&1
check "online: osv-scanner scans the repository" grep -qx -- "$repo" "$tmp/osv-args"
check "online: osv-scanner is not told to stay offline" sh -c '! grep -qx -- --offline "$1"' _ "$tmp/osv-args"
check "online: no NO DATABASE line" sh -c '! grep -q "NO DATABASE" "$1"' _ "$tmp/summary-online"

rm -f "$tmp/osv-args"
PATH="$tmp/bin:/usr/bin:/bin" bash "$script" "$repo" "$tmp/out-offline" --offline > "$tmp/summary-offline" 2>&1
check "--offline: osv-scanner gets --offline" grep -qx -- --offline "$tmp/osv-args"
check "--offline: the summary says no database was available" grep -q "osv-scanner .*NO DATABASE" "$tmp/summary-offline"

if [ -n "$real_osv" ]; then
  mkdir -p "$tmp/real-bin" "$tmp/empty-cache"
  ln -s "$real_osv" "$tmp/real-bin/osv-scanner"
  OSV_SCANNER_LOCAL_DB_CACHE_DIRECTORY="$tmp/empty-cache" PATH="$tmp/real-bin:/usr/bin:/bin" \
    bash "$script" "$repo" "$tmp/out-real" --offline > "$tmp/summary-real" 2>&1
  check "real osv-scanner, --offline, empty cache: NO DATABASE in the summary" grep -q "osv-scanner .*NO DATABASE" "$tmp/summary-real"
  check "real osv-scanner, --offline, empty cache: nothing downloaded" sh -c '! find "$1" -name "*.zip" | grep -q .' _ "$tmp/empty-cache"
else
  echo "skip real osv-scanner run (not installed)"
fi

[ "$fails" -eq 0 ] && echo "all checks passed" || echo "$fails check(s) failed"
[ "$fails" -eq 0 ]
