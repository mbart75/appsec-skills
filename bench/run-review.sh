#!/usr/bin/env bash
# Runs one bench review with Claude Code, isolated from this machine.
#
#   bench/run-review.sh [options] <copy> <results>
#
#   <copy>      blind copy printed by bench/setup.sh or bench/v2/setup.sh (.../review.XXXXXX/<name>)
#   <results>   new folder for this run's results; must not exist yet
#
#   --ref <git-ref>     skills to load: this repository's skills/ at that ref (default: HEAD)
#   --no-skill          baseline run, without the skills
#   --model <model>     default: claude-haiku-5-5 (bench/score.md section 6)
#   --offline           no network at all for the reviewer's shell, not even the scanners' sources
#   --expect-env <file> stop unless this machine's tool inventory matches that env.txt from an earlier run
#   --prompt <text>     replaces the bench prompt: for bench/sandbox-check.sh only, never for a scored run
#
# Exit code: claude's, or 3 when the session had an MCP server or a tool that acts outside the
# sandbox (init.json): such a run is invalid, whatever its report.
#
# The reviewed code is untrusted: on 2026-10-28, reviews installed Go with Homebrew, ran npm
# install scripts and third-party tests on the host, and Claude Code tried to start the MCP
# server declared in the reviewed repository's .mcp.json. Here:
# - every shell command of the reviewer runs in Claude Code's sandbox, with no way out
#   (allowUnsandboxedCommands false): it writes only inside the copy's parent folder and in this
#   run's own temporary folder (copied into the results), cannot read the home folder or this
#   repository, and reaches only the scanners' sources;
# - no settings, hooks or MCP servers come from the copy, the user or this machine
#   (--setting-sources "", --strict-mcp-config with no server, hooks off);
# - acceptEdits replaces bypassPermissions: the file tools write only inside the copy's folder and
#   the run's temporary folder;
# - no tool that acts outside the sandbox: web, messages to other sessions, routines, schedules.
# bench/sandbox-check.sh checks all of this on a trapped copy. On macOS the Mac is kept awake
# during the run (caffeinate): in the 2026-11 bench v2 measurement, sleeps broke one run and
# inflated another. A sleep that still happens (lid closed, battery) is recorded in sleep.txt.
set -euo pipefail

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

ref=HEAD skill=1 model=claude-haiku-5-5 offline=0 expect="" prompt=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ref) ref="${2:?--ref needs a value}"; shift 2 ;;
    --no-skill) skill=0; shift ;;
    --model) model="${2:?--model needs a value}"; shift 2 ;;
    --offline) offline=1; shift ;;
    --expect-env) expect="${2:?--expect-env needs a file}"; shift 2 ;;
    --prompt) prompt="${2:?--prompt needs a value}"; shift 2 ;;
    -h|--help) usage ;;
    -*) echo "unknown option: $1" >&2; usage ;;
    *) break ;;
  esac
done
[ $# -eq 2 ] || usage
copy="$(cd "$1" && pwd -P)"
results="$2"
here="$(cd "$(dirname "$0")" && pwd -P)"
repo="$(cd "$here/.." && pwd -P)"
claude_bin="$(command -v claude)" || { echo "claude not found on PATH" >&2; exit 1; }

# The reviewer may write in the copy's parent folder only: the copy, its own temporary folder
# and caches. setup.sh creates that folder for this copy alone.
work="$(dirname "$copy")"
case "$(basename "$work")" in review.*) ;; *) echo "not a bench copy (expected .../review.XXXXXX/<name>): $copy" >&2; exit 1 ;; esac
case "$work/" in
  "$HOME"/*|"$repo"/*) echo "the copy must live outside the home folder and this repository" >&2; exit 1 ;;
  /tmp/claude-*|/private/tmp/claude-*) echo "the copy must live outside /tmp/claude-<uid>, shared by every session" >&2; exit 1 ;;
esac
[ -e "$results" ] && { echo "results folder already exists: $results" >&2; exit 1; }
mkdir -p "$results"
results="$(cd "$results" && pwd -P)"

# Fixed PATH: the same tools for every run, recorded in env.txt. Nothing can be installed during
# a run (no write outside $work, no package registry), so the inventory cannot change midway.
path="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
inventory() {
  local t
  for t in git python3 node npm go cargo php ruby java semgrep opengrep trivy gitleaks trufflehog \
           osv-scanner bandit checkov zizmor shellcheck pwsh govulncheck; do
    if PATH="$path" command -v "$t" >/dev/null 2>&1; then
      # First line that carries a version number (ShellCheck prints a title first, Semgrep a blank line).
      printf '%s\t%s\n' "$t" "$(PATH="$path" "$t" --version 2>&1 | grep -m 1 -E '[0-9]+\.[0-9]+' || echo 'no version')"
    else
      printf '%s\t-\n' "$t"
    fi
  done
  printf 'claude\t%s\n' "$("$claude_bin" --version 2>&1 | head -n 1)"
}
inventory > "$results/env.txt"
if [ -n "$expect" ] && ! diff -u "$expect" "$results/env.txt" >&2; then
  echo "tool inventory differs from $expect: runs would not be comparable" >&2
  exit 1
fi

# This run's temporary folder. Claude Code points the shell's TMPDIR at <CLAUDE_CODE_TMPDIR>/claude-<uid>,
# but only when that path fits in 44 bytes (it holds AF_UNIX sockets); otherwise it falls back to
# /tmp/claude-<uid>, shared by every session. A folder in $work is far too long, so until
# 2026-11-04 every run's $TMPDIR was that shared folder: scanner outputs and reports landed there,
# on 2026-10-28 runs reused each other's $TMPDIR/appsec-out, and the file tools could not write
# there. Hence a short folder of its own, writable by the shell and the file tools, copied into the
# results after the run. /tmp/claude-<uid> is closed to writing.
shared_tmp="/private/tmp/claude-$(id -u)"
mkdir -p "$shared_tmp"
lock="$shared_tmp/appsec-bench-run.lock"
mkdir "$lock" 2>/dev/null || { echo "another bench run is in progress ($lock): runs must not overlap" >&2; exit 1; }
run_tmp=""
# Each step guarded: a failing cleanup must neither skip the next one nor change the exit code
# (3 means an invalid run).
# open_folders: folders the run left closed or read-only (000, 444, 555) are opened to their owner,
# each before find descends into it (-exec ... \;). Folders only: a chmod of a file would reach,
# through a hard link, a file outside. find never follows a symbolic link, and chmod -h acts on
# the link itself if one replaced a folder meanwhile.
open_folders() { find "$1" -type d ! -perm -u=rwx -exec chmod -h u+rwx {} \; 2>/dev/null || true; }
# ShellCheck takes finish for unreachable (SC2317, SC2329 in newer versions): the EXIT
# trap below calls it.
# shellcheck disable=SC2317,SC2329
finish() {
  rmdir "$lock" 2>/dev/null || echo "could not remove the lock $lock" >&2
  if [ -n "$run_tmp" ]; then
    open_folders "$run_tmp"
    rm -rf "$run_tmp" 2>/dev/null || echo "could not remove $run_tmp" >&2
  fi
}
trap finish EXIT
# One copy, one run: a second run on the same copy would see the first one's files.
mkdir "$work/cache" 2>/dev/null || { echo "this copy was already reviewed: make a fresh one with setup.sh" >&2; exit 1; }
mkdir -p "$work/config"
run_tmp="$(mktemp -d /private/tmp/bench.XXXXXX)"
shell_tmp="$run_tmp/claude-$(id -u)"
[ "${#shell_tmp}" -le 44 ] || { echo "temporary folder path too long for Claude Code: $shell_tmp" >&2; exit 1; }
printf '%s\n' "$shell_tmp" > "$results/run-tmp"
# Pinned skills, next to the copy: the results folder may sit in a place the reviewer cannot read.
plugin=()
if [ "$skill" -eq 1 ]; then
  mkdir -p "$work/plugin/.claude-plugin"
  git -C "$repo" archive "$ref" skills | tar -x -C "$work/plugin"
  printf '{"name":"appsec-skills","version":"bench","description":"bench copy of %s"}\n' \
    "$(git -C "$repo" rev-parse --short "$ref")" > "$work/plugin/.claude-plugin/plugin.json"
  plugin=(--plugin-dir "$work/plugin")
fi

python3 -I - "$results/settings.json" "$work" "$offline" "$shared_tmp" "$repo" "$run_tmp" <<'PY'
import json, sys
out, work, offline, shared_tmp, repo, run_tmp = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4], sys.argv[5], sys.argv[6]
# Off-limits for the reviewer: the whole home folder (credentials, ~/.claude.json, shell history,
# notes, other projects, earlier bench evidence in ~/Library/Caches) and this repository, wherever
# it is cloned (answer keys). The copy, its folder and the tools live outside the home folder.
private = ["~", repo]
# Permission rules read "/x" relative to the settings file: "//x" is absolute.
rules = ["~"] + ["/" + repo]
# What run-scanners.sh and cve-priority.py fetch online: Semgrep rules, Trivy checks, OSV, KEV, EPSS,
# Checkov's guidelines (the BC_* ids). Update checks (pypi.org) stay blocked: they change no result.
scanners = ["semgrep.dev", "mirror.gcr.io", "ghcr.io", "pkg-containers.githubusercontent.com",
            "api.osv.dev", "www.cisa.gov", "api.first.org", "api0.prismacloud.io"]
# Tools that act outside the sandbox, through the Claude Code process: messages to other local
# sessions, cloud routines, schedules, notifications. No bench run of 2026-10-28 used them.
outside = ["SendMessage", "ListAgents", "RemoteTrigger", "CronCreate", "CronDelete",
           "ScheduleWakeup", "PushNotification"]
settings = {
    "sandbox": {
        "enabled": True,
        "autoAllowBashIfSandboxed": True,
        "allowUnsandboxedCommands": False,
        # PowerShell modules (PSScriptAnalyzer) install in the home folder: public code, read-only.
        # /tmp/claude-<uid>: every session's scratchpad ("-<project>" folders; on 2026-10-28 two
        # reviews wrote into the calling session's) and, until 2026-11-04, every run's outputs.
        # /tmp/claude: the sandbox's built-in fallback temporary folder, writable by default and
        # shared by every sandboxed session.
        "filesystem": {"allowWrite": [work, run_tmp], "denyWrite": [shared_tmp, "/private/tmp/claude"],
                       "denyRead": private,
                       "allowRead": ["~/.local/share/powershell/Modules"]},
        "network": {"allowedDomains": [] if offline else scanners},
    },
    "permissions": {
        "deny": ["WebFetch", "WebSearch"] + outside
        + [f"{tool}({p}/**)" for p in rules for tool in ("Read", "Edit")]
        + [f"Edit(/{shared_tmp}/**)"],
    },
    "disableAllHooks": True,
    "enableAllProjectMcpServers": False,
}
with open(out, "w") as f:
    json.dump(settings, f, indent=2)
PY

if [ -n "$prompt" ]; then :
elif [ "$skill" -eq 1 ]; then prompt="Use the appsec-review skill in full mode on this repository."
# Baseline prompt of the 0.7.9 bench v2 measurement, kept for comparability.
else prompt="Review this repository for security vulnerabilities. For each finding, give the location, the root cause and a severity."
fi
printf '%s\n' "$model" > "$results/model"
printf '%s\n' "$copy" > "$results/copy"
# Kept awake on macOS: idle sleep and, on AC power, system sleep. Closing the lid still sleeps.
keepawake=()
[ -x /usr/bin/caffeinate ] && keepawake=(/usr/bin/caffeinate -i -s)
start="$(date +%s)"
echo "$start" > "$results/start"
status=0
# env -i: nothing from the calling session reaches the reviewer. Claude Code still hands its shell
# the reviewer session's own messaging socket and token; the sandbox keeps that socket out of
# reach (sandbox-check.sh tests it). The caches point inside $work, and git reads no global or
# system configuration (no user's hooks template, excludes or aliases).
(cd "$copy" && printf '%s' "$prompt" | env -i HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" \
  PATH="$path" SHELL=/bin/bash LANG=en_US.UTF-8 TMPDIR="$run_tmp" CLAUDE_CODE_TMPDIR="$run_tmp" \
  XDG_CACHE_HOME="$work/cache" XDG_CONFIG_HOME="$work/config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
  GOPATH="$work/cache/go" GOCACHE="$work/cache/go-build" GOTOOLCHAIN=local GOPROXY=off \
  npm_config_cache="$work/cache/npm" PIP_CACHE_DIR="$work/cache/pip" \
  ${keepawake[@]+"${keepawake[@]}"} "$claude_bin" -p --model "$model" \
    --setting-sources "" --settings "$results/settings.json" \
    --strict-mcp-config --permission-mode acceptEdits --add-dir "$work" --add-dir "$run_tmp" \
    --disallowedTools WebSearch WebFetch SendMessage ListAgents RemoteTrigger CronCreate CronDelete \
      ScheduleWakeup PushNotification \
    --output-format stream-json --verbose ${plugin[@]+"${plugin[@]}"} \
    > "$results/stream.jsonl" 2> "$results/stderr") || status=$?
end="$(date +%s)"
echo "$end" > "$results/end"
echo "$status" > "$results/exit"
# Everything the run wrote in its temporary folder (scanner outputs, reports, Claude Code's own
# scratchpad and task outputs) goes into the results; the folder is then removed (trap).
# Only folders, symbolic links (copied as links, never followed) and files with a single link:
# no socket, no FIFO (a later grep -r of the results would hang on it), and no hard link, which
# could name a file of the home folder the sandbox kept the reviewer from reading.
mkdir -p "$results/tmp"
open_folders "$run_tmp"
(cd "$run_tmp" && find . \( -type d -o -type l -o \( -type f -links 1 \) \) -print0 \
  | cpio -0 -pdm --quiet "$results/tmp") || echo "could not copy all of $run_tmp into the results" >&2
# A sleep during the run inflates its time and tokens, or breaks it ("Your computer went to sleep
# mid-response"): recorded, so the run can be judged.
if [ -x /usr/bin/pmset ]; then
  /usr/bin/pmset -g log 2>/dev/null | python3 -I -c '
import sys, datetime
start, end = int(sys.argv[1]), int(sys.argv[2])
for line in sys.stdin:
    if "Entering Sleep" not in line:
        continue
    try:
        t = datetime.datetime.strptime(line[:25], "%Y-%m-%d %H:%M:%S %z").timestamp()
    except ValueError:
        continue
    if start <= t <= end:
        sys.stdout.write(line)
' "$start" "$end" > "$results/sleep.txt" || true
  if [ -s "$results/sleep.txt" ]; then
    echo "the Mac slept during this run ($results/sleep.txt): its time and tokens are inflated, check its transcript" >&2
  fi
fi
# init.json: what the session really had (tools, MCP servers, skills, plugins). out.json: the
# final result (message, cost, session id). A run that had an MCP server or a tool acting
# outside the sandbox is not a valid bench run: on 2026-10-28 every run had the user's claude.ai
# connectors (Gmail, Calendar, Notion…), 113 tools, because of --setting-sources project,local.
if ! python3 -I - "$results" <<'PY'
import json, os, sys
d = sys.argv[1]
init = result = None
with open(os.path.join(d, "stream.jsonl")) as f:
    for line in f:
        try:
            e = json.loads(line)
        except ValueError:
            continue
        if e.get("type") == "system" and e.get("subtype") == "init" and init is None:
            init = e
        elif e.get("type") == "result":
            result = e
for name, e in (("init.json", init), ("out.json", result)):
    if e is not None:
        with open(os.path.join(d, name), "w") as f:
            json.dump(e, f, indent=1)
if init is None:
    sys.exit("no init event: the session did not start")
outside = {"SendMessage", "ListAgents", "RemoteTrigger", "CronCreate", "CronDelete",
           "ScheduleWakeup", "PushNotification", "WebFetch", "WebSearch"}
bad = [t for t in init.get("tools", []) if t.startswith("mcp__") or t in outside]
bad += ["MCP server " + str(m.get("name")) for m in init.get("mcp_servers", [])]
if bad:
    sys.exit("INVALID RUN, the session had: " + ", ".join(bad))
PY
then
  echo invalid > "$results/exit"
  exit 3
fi
# Every Markdown file the run wrote outside the copy: the skill keeps reports out of the
# repository, and report names vary from run to run. Kept at their place under reports/work/
# (the copy's folder) and reports/tmp/ (the run's temporary folder); same filter as above.
for root in "$work" "$results/tmp"; do
  case "$root" in "$work") dest="$results/reports/work" ;; *) dest="$results/reports/tmp" ;; esac
  (cd "$root" && find . \( -path "./$(basename "$copy")" -o -path ./cache -o -path ./plugin \) -prune \
    -o -type f -links 1 -name '*.md' -print0) | while IFS= read -r -d '' f; do
    mkdir -p "$dest/$(dirname "${f#./}")" && cp -P "$root/$f" "$dest/${f#./}" \
      || echo "could not copy the report $root/$f" >&2
  done || echo "could not collect every report" >&2
done
echo "$results"
exit "$status"
