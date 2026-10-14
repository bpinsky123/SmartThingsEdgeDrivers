#!/usr/bin/env bash
# Build either BP package from one shared source tree.
set -euo pipefail

variant=${1:-}
case "$variant" in
  migration-test|beta|migrated) ;;
  *)
    echo "Usage: $0 {migration-test|beta|migrated} [output-zip]" >&2
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
find "$stage_dir" -type f \( -name '*.zip' -o -name '*.rewrite' \) -delete

if [ "$variant" = beta ] || [ "$variant" = migrated ]; then
  driver_name="Z-Wave Lock BP Beta"
  package_key="zwave-lock-bp-beta"
  if [ "$variant" = migrated ]; then
    driver_name="Z-Wave Lock BP Migrated"
    package_key="zwave-lock-bp-migrated"
  fi

  sed -i \
    -e "s/^name: .*/name: '$driver_name'/" \
    -e "s/^packageKey: .*/packageKey: '$package_key'/" \
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

if [ "$variant" = migrated ]; then
  cp -a "$driver_dir/packaging/migrated/." "$stage_dir/"
fi

(
  cd "$stage_dir"
  smartthings edge:drivers:package --build-only "$output"
)
printf 'Wrote %s\n' "$output"
