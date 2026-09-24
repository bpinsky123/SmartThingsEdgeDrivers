#!/usr/bin/env bash
# Build and install either BP package from the shared source tree.
set -euo pipefail

variant=${1:-}
case "$variant" in
  migration-test|beta) ;;
  *)
    echo "Usage: $0 {migration-test|beta} [output-zip]" >&2
    exit 2
    ;;
esac

driver_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
archive=${2:-"$driver_dir/zwave-lock-bp-$variant.zip"}
stage_dir=$(mktemp -d)

cleanup() {
  rm -rf "$stage_dir"
}
trap cleanup EXIT

# The SmartThings CLI is installed in /home/bep on this development host.
if [ -x "$HOME/smartthings" ]; then
  export PATH="$HOME:$PATH"
fi

"$driver_dir/scripts/package-bp.sh" "$variant" "$archive"
unzip -q "$archive" -d "$stage_dir"
smartthings edge:drivers:package "$stage_dir" --install
