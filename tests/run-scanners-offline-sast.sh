#!/usr/bin/env bash
# run-scanners.sh --offline must keep Semgrep and Trivy offline: `semgrep scan --config p/default`
# downloads its rules from the Semgrep registry, and `trivy config` downloads its checks bundle.
# Offline, Semgrep is skipped and says so; Trivy uses the checks embedded in its binary. Trivy
# never sends usage telemetry nor asks for version updates, online or offline.
#
#   bash tests/run-scanners-offline-sast.sh [path/to/run-scanners.sh]
#
# Uses stand-in semgrep and trivy that record their arguments, so it needs no network and no
# scanner. When a real trivy is installed, it also runs it offline behind a recording proxy with an
# empty cache, and checks that it tried no connection. APPSEC_TEST_REQUIRE_ALL=1 (CI) makes a
# missing trivy a failure instead of a skip.
# The sh -c snippets take their values as positional parameters on purpose.
# shellcheck disable=SC2016
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="${1:-$here/../skills/appsec-review/scripts/run-scanners.sh}"
script="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"
real_trivy="$(command -v trivy || true)"

tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

fails=0
check() { # description, command...
  local what="$1"; shift
  if "$@"; then echo "ok   $what"; else echo "FAIL $what"; fails=$((fails + 1)); fi
}

# A repository with a Dockerfile, so that the IaC step (Trivy) runs; Semgrep runs on any repository.
repo="$tmp/repo"
mkdir -p "$repo"
git init -q --template= "$repo"
printf 'FROM alpine:3.20\nUSER root\n' > "$repo/Dockerfile"

# The stand-ins record their arguments, one per line, and write an empty result.
mkdir -p "$tmp/bin" "$tmp/home"
for tool in semgrep trivy; do
  cat > "$tmp/bin/$tool" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" > "$tmp/$tool-args"
out=""
prev=""
for a in "\$@"; do [ "\$prev" = "--output" ] && out="\$a"; prev="\$a"; done
[ -n "\$out" ] && printf '{}\n' > "\$out"
exit 0
EOF
  chmod +x "$tmp/bin/$tool"
done
export HOME="$tmp/home"

has_arg() { grep -qx -- "$1" "$2"; }
lacks_arg() { ! grep -qx -- "$1" "$2" 2>/dev/null; }

PATH="$tmp/bin:/usr/bin:/bin" bash "$script" "$repo" "$tmp/out-online" > "$tmp/summary-online" 2>&1
check "online: semgrep runs with the registry rules" has_arg p/default "$tmp/semgrep-args"
check "online: trivy is not told to skip the checks update" lacks_arg --skip-check-update "$tmp/trivy-args"
check "online: trivy sends no telemetry" has_arg --disable-telemetry "$tmp/trivy-args"
check "online: trivy asks for no version update" has_arg --skip-version-check "$tmp/trivy-args"
check "online: no SKIPPED (offline) line" sh -c '! grep -q "SKIPPED (offline)" "$1"' _ "$tmp/summary-online"

rm -f "$tmp/semgrep-args" "$tmp/trivy-args"
PATH="$tmp/bin:/usr/bin:/bin" bash "$script" "$repo" "$tmp/out-offline" --offline > "$tmp/summary-offline" 2>&1
check "--offline: semgrep is not run" test ! -e "$tmp/semgrep-args"
check "--offline: the summary says semgrep was skipped offline" grep -q "^semgrep .*SKIPPED (offline)" "$tmp/summary-offline"
check "--offline: trivy skips the checks update" has_arg --skip-check-update "$tmp/trivy-args"
check "--offline: trivy sends no telemetry" has_arg --disable-telemetry "$tmp/trivy-args"
check "--offline: trivy asks for no version update" has_arg --skip-version-check "$tmp/trivy-args"
check "--offline: the summary says trivy used its embedded checks" grep -q "^trivy config .*embedded checks" "$tmp/summary-offline"

# A real Trivy behind a local proxy that records the first line of every request and answers
# nothing useful, with an empty cache: any download or phone-home attempt (checks bundle,
# telemetry, version check) shows up in the proxy's log, whether Trivy logs it or not.
if [ -n "$real_trivy" ]; then
  mkdir -p "$tmp/real-bin" "$tmp/real-cache"
  ln -s "$real_trivy" "$tmp/real-bin/trivy"
  : > "$tmp/proxy-log"
  python3 -I -c '
import socket, sys
s = socket.socket()
s.bind(("127.0.0.1", 0))
s.listen(16)
open(sys.argv[2], "w").write(str(s.getsockname()[1]))
while True:
    c, _ = s.accept()
    c.settimeout(5)
    try:
        line = c.recv(4096).split(b"\r\n")[0].decode("latin-1")
    except OSError:
        line = "(no request line)"
    with open(sys.argv[1], "a") as f:
        f.write(line + "\n")
    c.close()
' "$tmp/proxy-log" "$tmp/proxy-port" &
  proxy_pid=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do [ -s "$tmp/proxy-port" ] && break; sleep 0.2; done
  proxy="http://127.0.0.1:$(cat "$tmp/proxy-port")"
  TRIVY_CACHE_DIR="$tmp/real-cache" HTTPS_PROXY="$proxy" HTTP_PROXY="$proxy" \
    https_proxy="$proxy" http_proxy="$proxy" NO_PROXY='' no_proxy='' \
    PATH="$tmp/real-bin:/usr/bin:/bin" bash "$script" "$repo" "$tmp/out-real" --offline > "$tmp/summary-real" 2>&1
  kill "$proxy_pid" 2>/dev/null
  wait "$proxy_pid" 2>/dev/null
  check "real trivy, --offline: it produced a report" test -s "$tmp/out-real/trivy-config.json"
  check "real trivy, --offline: no connection attempted" test ! -s "$tmp/proxy-log"
  [ -s "$tmp/proxy-log" ] && sed 's/^/     attempted: /' "$tmp/proxy-log"
elif [ "${APPSEC_TEST_REQUIRE_ALL:-0}" = 1 ]; then
  check "real trivy is installed (APPSEC_TEST_REQUIRE_ALL=1)" false
else
  echo "skip real trivy run (not installed)"
fi

[ "$fails" -eq 0 ] && echo "all checks passed" || echo "$fails check(s) failed"
[ "$fails" -eq 0 ]
