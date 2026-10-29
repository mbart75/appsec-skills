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
#   (allowUnsandboxedCommands false): it writes only inside the copy's parent folder, cannot
#   read credentials, notes or this repository, and reaches only the scanners' sources;
# - no settings, hooks or MCP servers come from the copy, the user or this machine
#   (--setting-sources "", --strict-mcp-config with no server, hooks off);
# - acceptEdits replaces bypassPermissions: the file tools write only inside the copy's folder;
# - no tool that acts outside the sandbox: web, messages to other sessions, routines, schedules.
# bench/sandbox-check.sh checks all of this on a trapped copy.
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
case "$work/" in "$HOME"/Developer/*|"$repo"/*) echo "the copy must live outside ~/Developer and this repository" >&2; exit 1 ;; esac
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

# The sandbox sets the shell's TMPDIR to /tmp/claude-<uid>, shared by every session: on 2026-10-28
# runs reused each other's $TMPDIR/appsec-out there. BASH_ENV points the shell back at $work/tmp;
# the file sits next to $work, readable by the sandbox but not writable, so the reviewed code
# cannot change what every later shell sources. A tool that still writes in /tmp/claude-<uid> has
# its files moved into the results afterwards (below), hence one run at a time.
shared_tmp="/private/tmp/claude-$(id -u)"
lock="${TMPDIR:-/tmp}/appsec-bench-run.lock"
mkdir "$lock" 2>/dev/null || { echo "another bench run is in progress ($lock): runs must not overlap" >&2; exit 1; }
trap 'rmdir "$lock"' EXIT
mkdir -p "$shared_tmp"
entries() { find "$shared_tmp" -mindepth 1 -maxdepth 1 -print | sed 's#.*/##' | sort; }
entries > "$results/shared-tmp-before.txt"

mkdir -p "$work/tmp" "$work/cache" "$work/config"
bash_env="$work.bash_env"
printf 'export TMPDIR=%q\n' "$work/tmp" > "$bash_env"
# Claude Code's own temporary folder (scratchpad, task outputs) moves inside $work too. One copy,
# one run: a second run on the same copy would see the first one's files.
[ -e "$work/claude" ] && { echo "this copy was already reviewed: make a fresh one with setup.sh" >&2; exit 1; }
mkdir -m 700 "$work/claude"
# Pinned skills, next to the copy: the results folder may sit in a place the reviewer cannot read.
plugin=()
if [ "$skill" -eq 1 ]; then
  mkdir -p "$work/plugin/.claude-plugin"
  git -C "$repo" archive "$ref" skills | tar -x -C "$work/plugin"
  printf '{"name":"appsec-skills","version":"bench","description":"bench copy of %s"}\n' \
    "$(git -C "$repo" rev-parse --short "$ref")" > "$work/plugin/.claude-plugin/plugin.json"
  plugin=(--plugin-dir "$work/plugin")
fi

python3 -I - "$results/settings.json" "$work" "$offline" "$shared_tmp" <<'PY'
import json, sys
import os
out, work, offline, shared_tmp = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4]
# The sandbox points the shell's TMPDIR at /tmp/claude-<uid> and must write there. Inside it, every
# other session keeps its scratchpad in a "-<project>" folder: those are closed to writing (on
# 2026-10-28 two reviews wrote into the calling session's). Sessions started during the run are not.
sessions = sorted(os.path.join(shared_tmp, d) for d in os.listdir(shared_tmp)
                  if d.startswith("-") and os.path.isdir(os.path.join(shared_tmp, d))) \
    if os.path.isdir(shared_tmp) else []
# Off-limits for the reviewer: credentials, notes, other projects and this repository (answer
# keys), other Claude sessions, caches (earlier bench evidence lives in ~/Library/Caches).
private = ["~/.ssh", "~/.gnupg", "~/.aws", "~/.azure", "~/.config", "~/.docker", "~/.kube",
           "~/.netrc", "~/.npmrc", "~/.pypirc", "~/.git-credentials", "~/.claude", "~/.codex",
           "~/Developer", "~/Documents", "~/Desktop", "~/Downloads",
           "~/Library/Keychains", "~/Library/Mobile Documents", "~/Library/Application Support",
           "~/Library/Caches", "~/Library/Cookies", "~/Library/Mail", "~/Library/Messages"]
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
        "filesystem": {"allowWrite": [work], "denyWrite": sessions, "denyRead": private},
        "network": {"allowedDomains": [] if offline else scanners},
    },
    "permissions": {
        # "~/" rules: Claude Code reads "/x" as relative to the settings file.
        "deny": ["WebFetch", "WebSearch"] + outside
        + [f"{tool}({p}/**)" for p in private for tool in ("Read", "Edit")]
        + [f"Read({p})" for p in private],
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
date +%s > "$results/start"
status=0
# env -i: nothing from the calling session reaches the reviewer. Claude Code still hands its shell
# the reviewer session's own messaging socket and token; the sandbox keeps that socket out of
# reach (sandbox-check.sh tests it). The caches point inside $work, and git reads no global or
# system configuration (no user's hooks template, excludes or aliases).
(cd "$copy" && printf '%s' "$prompt" | env -i HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" \
  PATH="$path" SHELL=/bin/bash LANG=en_US.UTF-8 TMPDIR="$work/tmp" CLAUDE_CODE_TMPDIR="$work/claude" \
  XDG_CACHE_HOME="$work/cache" XDG_CONFIG_HOME="$work/config" GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
  BASH_ENV="$bash_env" \
  GOPATH="$work/cache/go" GOCACHE="$work/cache/go-build" GOTOOLCHAIN=local GOPROXY=off \
  npm_config_cache="$work/cache/npm" PIP_CACHE_DIR="$work/cache/pip" \
  "$claude_bin" -p --model "$model" \
    --setting-sources "" --settings "$results/settings.json" \
    --strict-mcp-config --permission-mode acceptEdits --add-dir "$work" \
    --disallowedTools WebSearch WebFetch SendMessage ListAgents RemoteTrigger CronCreate CronDelete \
      ScheduleWakeup PushNotification \
    --output-format stream-json --verbose ${plugin[@]+"${plugin[@]}"} \
    > "$results/stream.jsonl" 2> "$results/stderr") || status=$?
date +%s > "$results/end"
echo "$status" > "$results/exit"
mv "$bash_env" "$results/bash_env"
# What the run created in the shared TMPDIR (scanner outputs, scratch files) moves into the
# results: evidence for this run, and nothing left for the next one to find. Claude Code's own
# entries (session folders "-<project>", cwd-*, zsh) stay.
entries | while IFS= read -r e; do
  case "$e" in -*|cwd-*|zsh|bash-edit-diff|cc-socks|cache-break-state-*) continue ;; esac
  grep -qxF -- "$e" "$results/shared-tmp-before.txt" && continue
  mkdir -p "$results/shared-tmp"
  mv -- "$shared_tmp/$e" "$results/shared-tmp/" || echo "could not move $shared_tmp/$e" >&2
done
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
# Reports written outside the copy (the skill keeps reports out of the repository): in its folder,
# or in the shared TMPDIR, moved above.
find "$work" "$results/shared-tmp" \( -path "$copy" -o -path "$work/cache" -o -path "$work/plugin" \) -prune \
  -o -type f -name '*report*.md' -print 2>/dev/null \
  | while IFS= read -r f; do cp "$f" "$results/"; done || true
echo "$results"
exit "$status"
