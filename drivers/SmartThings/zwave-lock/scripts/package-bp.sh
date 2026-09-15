#!/usr/bin/env bash
# Build either BP package from one shared source tree.
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
output=${2:-"$driver_dir/zwave-lock-bp-$variant.zip"}
stage_dir=$(mktemp -d)

cleanup() {
  rm -rf "$stage_dir"
}
trap cleanup EXIT

cp -a "$driver_dir/." "$stage_dir"
rm -rf "$stage_dir/scripts"
find "$stage_dir" -type f -name '*.zip' -delete

if [ "$variant" = beta ]; then
  sed -i \
    -e "s/^name: .*/name: 'Z-Wave Lock BP Beta'/" \
    -e "s/^packageKey: .*/packageKey: 'zwave-lock-bp-beta'/" \
    "$stage_dir/config.yml"

  for profile in \
    "$stage_dir/profiles/schlage-be468.yml" \
    "$stage_dir/profiles/schlage-be469.yml"; do
    awk '
      $0 == "  - id: heartsample19211.bpMigrationTest" { skip = 1; next }
      skip && $0 == "    version: 1" { skip = 0; next }
      !skip { print }
    ' "$profile" > "$profile.tmp"
    mv "$profile.tmp" "$profile"
  done
fi

smartthings edge:drivers:package "$stage_dir" --build-only "$output"
printf 'Wrote %s\n' "$output"
