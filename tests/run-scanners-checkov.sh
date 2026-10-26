#!/usr/bin/env bash
# run-scanners.sh must not let the reviewed repository configure Checkov: its .checkov.yaml can
# load Python checks (external-checks-dir, external-checks-git) and hide findings (skip-check).
# Each hostile repository is scanned from inside itself, the usual case for an agent.
#
#   bash tests/run-scanners-checkov.sh [path/to/run-scanners.sh]
#
# Also checks that Trivy, absent from its PATH, is reported missing like the other scanners.
#
# Needs Checkov 3.3 or later. The "malicious" check only writes a marker file into the temporary
# folder of this test. Nothing is read, sent or kept outside of it.
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
script="${1:-$here/../skills/appsec-review/scripts/run-scanners.sh}"
script="$(cd "$(dirname "$script")" && pwd)/$(basename "$script")"
checkov_bin="$(command -v checkov)" || { echo "checkov is not installed" >&2; exit 2; }

tmp="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$tmp"' EXIT

# Only Checkov on the PATH: the other scanners are not under test and some are slow. A throwaway
# HOME keeps Checkov's caches and any ~/.checkov.yaml out of the picture.
mkdir -p "$tmp/bin" "$tmp/home"
ln -s "$checkov_bin" "$tmp/bin/checkov"
export PATH="$tmp/bin:/usr/bin:/bin"
export HOME="$tmp/home"
unset CKV_SKIP_CHECK CKV_CHECK CKV_FRAMEWORK CKV_SKIP_FRAMEWORK

# A custom check that proves it ran by writing a marker, nothing else.
write_check() { # directory, marker name
  mkdir -p "$1"
  : > "$1/__init__.py"
  printf 'open(%s, "w").write("ran")\n' "\"$tmp/MARKER-$2\"" > "$1/evil.py"
}

# A repository with one open SSH rule (CKV_AWS_24, a plain finding) and one finding suppressed
# in line, which the script reports but cannot remove.
make_repo() { # directory
  mkdir -p "$1"
  git init -q --template= "$1"
  cat > "$1/main.tf" <<'EOF'
resource "aws_security_group" "open" {
  name = "open"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
EOF
  cat > "$1/inline.tf" <<'EOF'
resource "aws_security_group" "quiet" {
  #checkov:skip=CKV_AWS_24:the repository says so
  name = "quiet"
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
EOF
}
commit() { # directory
  git -C "$1" add -A && git -C "$1" -c user.name=test -c user.email=test@example.invalid -c commit.gpgsign=false commit -q -m init
}

# Variant 1: checks loaded from a folder of the repository (the path is relative to the folder
# Checkov runs from) and findings skipped.
dir_repo="$tmp/hostile-dir"
make_repo "$dir_repo"
write_check "$dir_repo/checks" dir
printf 'skip-check:\n  - CKV_AWS_24\nexternal-checks-dir:\n  - checks\n' > "$dir_repo/.checkov.yaml"
commit "$dir_repo"

# Variant 2: checks loaded from a git URL, whatever the folder Checkov runs from.
git_repo="$tmp/hostile-git"
ext_repo="$tmp/external-checks"
make_repo "$git_repo"
mkdir -p "$ext_repo" && git init -q --template= "$ext_repo"
write_check "$ext_repo/checks" git
commit "$ext_repo"
printf 'skip-check:\n  - CKV_AWS_24\nexternal-checks-git:\n  - file://%s\n' "$ext_repo" > "$git_repo/.checkov.yml"
commit "$git_repo"

fail=0
check() { # description, command...
  local what="$1"; shift
  if "$@"; then echo "ok   - $what"; else echo "FAIL - $what"; fail=1; fi
}

for variant in dir git; do
  repo="$tmp/hostile-$variant"
  out="$tmp/out-$variant"
  (cd "$repo" && bash "$script" "$repo" "$out" --offline) > "$tmp/summary-$variant.txt" 2>&1

  failed_ids() { python3 -I -c '
import json, sys
data = json.load(open(sys.argv[1]))
for report in data if isinstance(data, list) else [data]:
    for c in report.get("results", {}).get("failed_checks", []):
        print(c["check_id"], c["file_path"])
' "$out/checkov.json"; }
  open_ssh_reported() { failed_ids | grep -qx 'CKV_AWS_24 /main.tf'; }
  settings_file="$repo/.checkov.$([ "$variant" = dir ] && echo yaml || echo yml)"

  echo "--- variant: $variant"
  check "$variant: the repository's Python check did not run" test ! -e "$tmp/MARKER-$variant"
  check "$variant: the finding the repository tried to skip is reported, with a path relative to the repository" open_ssh_reported
  check "$variant: the repository's settings are listed for the reviewer" grep -q 'checkov settings *IGNORED' "$tmp/summary-$variant.txt"
  check "$variant: settings file listed" grep -qF "Settings file (ignored): $settings_file" "$out/checkov-repo-settings.txt"
  check "$variant: inline skip listed (cannot be removed)" grep -qF "Mentions checkov:skip (kept): $repo/inline.tf" "$out/checkov-repo-settings.txt"
  check "$variant: the reviewed repository is left untouched" test -z "$(git -C "$repo" status --porcelain --ignored)"
  check "$variant: no working copy left in the output folder" test ! -e "$out/.checkov-work"
  # Trivy is not on this PATH: like every absent scanner, it is listed with how to install it.
  if command -v trivy >/dev/null; then
    echo "skip - $variant: trivy is in /usr/bin or /bin, so it cannot be reported missing"
  else
    check "$variant: trivy, not installed, is listed as missing with its install command" \
      grep -q '^trivy *MISSING *install: brew install trivy' "$tmp/summary-$variant.txt"
  fi
done

if [ "$fail" -ne 0 ]; then
  for variant in dir git; do echo "--- run-scanners.sh summary ($variant)"; cat "$tmp/summary-$variant.txt"; done
  exit 1
fi
