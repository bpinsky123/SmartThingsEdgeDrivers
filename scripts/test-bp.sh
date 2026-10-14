#!/usr/bin/env bash
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
driver_dir="$repo_root/drivers/SmartThings/zwave-lock"
lua_libs_dir="$repo_root/lua_libs-api_v21"
python_bin="$repo_root/.venv/bin/python"

if [[ ! -d "$lua_libs_dir/integration_test" ]]; then
  echo "Missing SmartThings Lua libraries: $lua_libs_dir" >&2
  exit 1
fi

if [[ ! -x "$python_bin" ]]; then
  echo "Missing Python test environment: $python_bin" >&2
  exit 1
fi

capability_dir=$(mktemp -d "${TMPDIR:-/tmp}/zwave-lock-capabilities.XXXXXX")
trap 'rm -rf "$capability_dir"' EXIT

for definition in "$driver_dir"/custom_capabilities/*.capability.json; do
  capability=$(basename "$definition" .capability.json)
  cp "$definition" "$capability_dir/${capability}_1.json"
done

cd "$repo_root"

luacheck --config .github/workflows/.luacheckrc \
  "$driver_dir/src/legacy-handlers/schlage-lock/schlage-lock-bp/init.lua"

export LUA_PATH="$lua_libs_dir/?.lua;$lua_libs_dir/?/init.lua;;"
export ST_CAPABILITY_JSON_DIR="$capability_dir"

exec "$python_bin" tools/run_driver_tests.py -v -f 'zwave-lock' "$@"
