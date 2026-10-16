#!/usr/bin/env bash
# Usage: deploy.sh <build_dir> <branch>
set -euo pipefail

build_dir="${1:?usage: deploy.sh <build_dir> <branch>}"
branch="${2:?usage: deploy.sh <build_dir> <branch>}"
# Resolve symlinks and "..", then compare against an exact allow-list.
target="$(cd -- "${DEPLOY_TARGET:?DEPLOY_TARGET must be set}" && pwd -P)"

case "$target" in
  /srv/tinyshop/app | /srv/tinyshop/previews) ;;
  *) echo "refusing to deploy to $target" >&2; exit 1 ;;
esac
[ -d "$build_dir" ] || { echo "build directory not found: $build_dir" >&2; exit 1; }

echo "Deploying $build_dir"
find "$target" -mindepth 1 -delete
cp -R -- "$build_dir"/. "$target"/
printf 'Deployed branch %s at %s\n' "$branch" "$(date)"
