#!/usr/bin/env bash
set -euo pipefail

variant="${1:-}"

case "$variant" in
  beta)
    zip_file="zwave-lock-bp-beta.zip"
    ;;
  migration-test)
    zip_file="zwave-lock-bp-migration-test.zip"
    ;;
  *)
    echo "Usage: $0 {beta|migration-test}" >&2
    exit 2
    ;;
esac

if [[ ! -f "$zip_file" ]]; then
  echo "Package not found: $zip_file" >&2
  exit 1
fi

stage_dir=$(mktemp -d)
trap 'rm -rf "$stage_dir"' EXIT

unzip -q "$zip_file" -d "$stage_dir"
smartthings edge:drivers:package "$stage_dir" --install
