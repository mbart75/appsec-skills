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
# The reviewed code is untrusted: on 2026-10-28, reviews installed Go with Homebrew, ran npm
# install scripts and third-party tests on the host, and Claude Code tried to start the MCP
# server declared in the reviewed repository's .mcp.json. Here:
# - every shell command of the reviewer runs in Claude Code's sandbox, with no way out
#   (allowUnsandboxedCommands false): it writes only inside the copy's parent folder, cannot
#   read credentials, notes or this repository, and reaches only the scanners' sources;
# - no settings, hooks or MCP servers come from the copy, the user or this machine
#   (--setting-sources "", --strict-mcp-config with no server, hooks off);
# - acceptEdits replaces bypassPermissions: the file tools write only inside the copy;
# - no tool that acts outside the sandbox: web, messages to other sessions, routines, schedules.
# bench/sandbox-check.sh checks all of this on a trapped copy.
set -euo pipefail

usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

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
      printf '%s\t%s\n' "$t" "$(PATH="$path" "$t" --version 2>&1 | head -n 1)"
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

mkdir -p "$work/tmp" "$work/cache"
# Claude Code's own temporary folder (scratchpad, task outputs) moves inside $work too: the shared
# /tmp/claude-<uid> holds every other session's scratchpad, and stays read-only for the reviewer.
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

python3 -I - "$results/settings.json" "$work" "$offline" "/private/tmp/claude-$(id -u)" <<'PY'
import json, sys
out, work, offline, shared_tmp = sys.argv[1], sys.argv[2], sys.argv[3] == "1", sys.argv[4]
# Off-limits for the reviewer: credentials, notes, other projects and this repository (answer
# keys), other Claude sessions, caches (earlier bench evidence lives in ~/Library/Caches).
private = ["~/.ssh", "~/.gnupg", "~/.aws", "~/.azure", "~/.config", "~/.docker", "~/.kube",
           "~/.netrc", "~/.npmrc", "~/.pypirc", "~/.git-credentials", "~/.claude", "~/.codex",
           "~/Developer", "~/Documents", "~/Desktop", "~/Downloads",
           "~/Library/Keychains", "~/Library/Mobile Documents", "~/Library/Application Support",
           "~/Library/Caches", "~/Library/Cookies", "~/Library/Mail", "~/Library/Messages"]
# What run-scanners.sh and cve-priority.py fetch online: Semgrep rules, Trivy checks, OSV, KEV, EPSS.
scanners = ["semgrep.dev", "mirror.gcr.io", "ghcr.io", "pkg-containers.githubusercontent.com",
            "api.osv.dev", "www.cisa.gov", "api.first.org"]
# Tools that act outside the sandbox, through the Claude Code process: messages to other local
# sessions, cloud routines, schedules, notifications. No bench run of 2026-10-28 used them.
outside = ["SendMessage", "ListAgents", "RemoteTrigger", "CronCreate", "CronDelete",
           "ScheduleWakeup", "PushNotification"]
settings = {
    "sandbox": {
        "enabled": True,
        "autoAllowBashIfSandboxed": True,
        "allowUnsandboxedCommands": False,
        "filesystem": {"allowWrite": [work], "denyWrite": [shared_tmp, "/tmp/claude"], "denyRead": private},
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
# reach (sandbox-check.sh tests it). The caches point inside $work.
(cd "$copy" && printf '%s' "$prompt" | env -i HOME="$HOME" USER="$USER" LOGNAME="$LOGNAME" \
  PATH="$path" SHELL=/bin/bash LANG=en_US.UTF-8 TMPDIR="$work/tmp" CLAUDE_CODE_TMPDIR="$work/claude" \
  XDG_CACHE_HOME="$work/cache" \
  GOPATH="$work/cache/go" GOCACHE="$work/cache/go-build" GOTOOLCHAIN=local GOPROXY=off \
  npm_config_cache="$work/cache/npm" PIP_CACHE_DIR="$work/cache/pip" \
  "$claude_bin" -p --model "$model" \
    --setting-sources "" --settings "$results/settings.json" \
    --strict-mcp-config --permission-mode acceptEdits \
    --disallowedTools WebSearch WebFetch SendMessage ListAgents RemoteTrigger CronCreate CronDelete \
      ScheduleWakeup PushNotification \
    --output-format json ${plugin[@]+"${plugin[@]}"} \
    > "$results/out.json" 2> "$results/stderr") || status=$?
date +%s > "$results/end"
echo "$status" > "$results/exit"
# Reports written outside the copy, next to it (the skill keeps reports out of the repository).
find "$work" \( -path "$copy" -o -path "$work/cache" -o -path "$work/plugin" -o -path "$work/claude" \) -prune -o -type f -name '*report*.md' -print \
  | while IFS= read -r f; do cp "$f" "$results/"; done
echo "$results"
exit "$status"
