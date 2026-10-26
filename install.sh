#!/usr/bin/env bash
# Installs the appsec-* skills into the AI coding agents present on this machine.
#
#   ./install.sh                      interactive: pick agents and skills from a menu
#   ./install.sh --agents claude,codex --yes
#   ./install.sh --all-detected --yes
#   ./install.sh --dir ~/my-agent/skills --yes
#   ./install.sh --uninstall          remove the appsec-* skills from the chosen agents
#   ./install.sh --dry-run            show what would change, change nothing
#
# Options
#   --agents <list>    comma-separated: claude, codex, cursor, copilot, gemini, opencode, agents
#   --all-detected     every agent whose configuration folder exists
#   --dir <path>       an explicit skills folder (agent not in the list)
#   --skills <list>    comma-separated skill names (default: all appsec-* skills)
#   --link             link instead of copy (only from a git clone; "git pull" then updates every agent)
#   --uninstall        remove instead of install
#   --dry-run          print the plan only
#   --yes              do not ask for confirmation
#
# Safety: inside a skills folder, only folders named appsec-* are created, replaced or
# removed. When installing, the chosen skills folder itself (and its parents) is created
# if it is missing; uninstalling never creates it. No network, no sudo, nothing outside
# the chosen skills folders is touched.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/skills"

agents_arg=""
dirs=()
skills_arg=""
all_detected=0
mode="copy"
action="install"
dry=0
yes=0

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --agents) agents_arg="${2:?--agents needs a value}"; shift ;;
    --all-detected) all_detected=1 ;;
    --dir) dirs+=("${2:?--dir needs a path}"); shift ;;
    --skills) skills_arg="${2:?--skills needs a value}"; shift ;;
    --link) mode="link" ;;
    --uninstall) action="uninstall" ;;
    --dry-run) dry=1 ;;
    --yes|-y) yes=1 ;;
    -h|--help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done

[ -d "$src" ] || die "no skills/ folder next to this script; run it from the unzipped release or a clone"

# Known agents: key | name | config folder | skills folder
catalogue() {
  cat <<EOF
claude|Claude Code|$HOME/.claude|$HOME/.claude/skills
codex|Codex|$HOME/.codex|$HOME/.codex/skills
cursor|Cursor|$HOME/.cursor|$HOME/.cursor/skills
copilot|GitHub Copilot CLI|$HOME/.copilot|$HOME/.copilot/skills
gemini|Gemini CLI|$HOME/.gemini|$HOME/.gemini/skills
opencode|OpenCode|$HOME/.config/opencode|$HOME/.config/opencode/skills
agents|Shared folder read by several agents|$HOME/.agents|$HOME/.agents/skills
EOF
}

skills_available=()
for d in "$src"/appsec-*/; do
  [ -f "$d/SKILL.md" ] && skills_available+=("$(basename "$d")")
done
[ ${#skills_available[@]} -gt 0 ] || die "no appsec-* skill found in $src"

# --- choose skills --------------------------------------------------------------
skills=()
if [ -n "$skills_arg" ]; then
  IFS=',' read -r -a wanted <<< "$skills_arg"
  for s in "${wanted[@]}"; do
    # Exact names only: a value with a path (appsec-x/../..) must not reach rm -rf below.
    found=0
    for a in "${skills_available[@]}"; do [ "$s" = "$a" ] && found=1; done
    [ "$found" -eq 1 ] || die "unknown skill: $s (available: ${skills_available[*]})"
    skills+=("$s")
  done
else
  skills=("${skills_available[@]}")
fi

# --- choose targets ---------------------------------------------------------------
targets=()   # "name|skills folder"
add_target() { targets+=("$1|$2"); }

if [ -n "$agents_arg" ]; then
  IFS=',' read -r -a wanted <<< "$agents_arg"
  for key in "${wanted[@]}"; do
    line="$(catalogue | awk -F'|' -v k="$key" '$1 == k')"
    [ -n "$line" ] || die "unknown agent: $key (known: $(catalogue | cut -d'|' -f1 | paste -sd, -))"
    IFS='|' read -r _ name _ folder <<< "$line"
    add_target "$name" "$folder"
  done
fi
for d in ${dirs[@]+"${dirs[@]}"}; do add_target "Custom folder" "$d"; done

if [ "$all_detected" -eq 1 ]; then
  while IFS='|' read -r _ name config folder; do
    [ -d "$config" ] && add_target "$name" "$folder"
  done < <(catalogue)
fi

if [ ${#targets[@]} -eq 0 ]; then
  [ -t 0 ] || die "no agent chosen; use --agents, --all-detected or --dir (or run in a terminal for the menu)"
  echo "Which AI agents do you use? Detected ones are marked with *."
  i=0
  keys=()
  while IFS='|' read -r key name config folder; do
    i=$((i + 1)); keys+=("$key")
    mark=" "; [ -d "$config" ] && mark="*"
    printf '  %d) %s %s   (%s)\n' "$i" "$mark" "$name" "$folder"
  done < <(catalogue)
  echo "  c) Another folder (you type its path)"
  printf 'Numbers separated by spaces, or Enter for all detected: '
  read -r answer
  if [ -z "$answer" ]; then
    while IFS='|' read -r _ name config folder; do
      [ -d "$config" ] && add_target "$name" "$folder"
    done < <(catalogue)
  else
    read -r -a choices <<< "$answer"   # split on spaces without filename expansion
    for n in "${choices[@]}"; do
      if [ "$n" = "c" ]; then
        printf 'Path of the skills folder: '; read -r custom
        add_target "Custom folder" "${custom/#\~/$HOME}"
      elif [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le ${#keys[@]} ]; then
        line="$(catalogue | sed -n "${n}p")"
        IFS='|' read -r _ name _ folder <<< "$line"
        add_target "$name" "$folder"
      else
        die "invalid choice: $n"
      fi
    done
  fi
fi
[ ${#targets[@]} -gt 0 ] || die "no agent detected; choose one with --agents or --dir"

if [ "$mode" = "link" ] && [ ! -d "$here/.git" ]; then
  die "--link needs a git clone (a zip copy would leave links to a folder you may delete); use the default copy mode"
fi

# --- plan -----------------------------------------------------------------------------
echo
echo "Plan ($action, mode: $mode):"
for t in "${targets[@]}"; do
  IFS='|' read -r name folder <<< "$t"
  echo "  $name -> $folder"
  for s in "${skills[@]}"; do echo "      $s"; done
done
if [ "$dry" -eq 1 ]; then echo "(dry run: nothing changed)"; exit 0; fi
if [ "$yes" -eq 0 ]; then
  [ -t 0 ] || die "add --yes to confirm when not running in a terminal"
  printf 'Proceed? [y/N] '; read -r ok
  case "$ok" in y|Y|yes|o|O|oui) ;; *) echo "Nothing changed."; exit 0 ;; esac
fi

# --- apply ------------------------------------------------------------------------------
for t in "${targets[@]}"; do
  IFS='|' read -r name folder <<< "$t"
  if [ "$action" = "install" ]; then mkdir -p "$folder"; fi
  for s in "${skills[@]}"; do
    case "$s" in appsec-*) ;; *) die "refusing to touch a non appsec-* folder: $s" ;; esac
    dest="$folder/$s"
    if [ "$action" = "uninstall" ]; then
      if [ -e "$dest" ] || [ -L "$dest" ]; then rm -rf -- "$dest"; echo "  removed $dest"; fi
      continue
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then rm -rf -- "$dest"; fi
    if [ "$mode" = "link" ]; then ln -s "$src/$s" "$dest"; else cp -R "$src/$s" "$dest"; fi
    echo "  $s -> $dest"
  done
done

echo
if [ "$action" = "install" ]; then
  echo "Done. Restart your agent, then try:  Use appsec-review in full mode on this repository."
  [ "$mode" = "copy" ] && echo "To update later: download the new release and run this script again."
else
  echo "Done."
fi
