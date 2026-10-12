#!/usr/bin/env bash
set -euo pipefail
usage() {
  cat <<'EOF'
Usage:
  preserve-lock-code-names.sh export DEVICE_ID OUTPUT.json
  preserve-lock-code-names.sh restore DEVICE_ID INPUT.json [--dry-run]

Export saves lockCodes slot names only. It never reads, saves, or transmits PIN
values. Restore sends local lockCodes nameSlot commands after the BP driver has
finished its initial slot scan.
EOF
}
require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required command not found: $1" >&2
    exit 1
  }
}
command_name_slot() {
  local device_id=$1
  local slot=$2
  local name=$3
  local command_file
  command_file=$(mktemp)
  {
    printf 'component: main\ncapability: lockCodes\ncommand: nameSlot\narguments:\n'
    printf '  - %s\n' "$slot"
    printf '  - '
    jq -Rn --arg value "$name" '$value'
  } > "$command_file"
  if ! smartthings devices:commands "$device_id" -i "$command_file"; then
    rm -f "$command_file"
    return 1
  fi
  rm -f "$command_file"
}
require_command jq
require_command smartthings
case ${1:-} in
  export)
    [[ $# -eq 3 ]] || { usage >&2; exit 1; }
    device_id=$2
    output_file=$3
    temp_file=$(mktemp)
    trap 'rm -f "$temp_file"' EXIT
    smartthings devices:status "$device_id" --json |
      jq -e --arg device_id "$device_id" '
        .components.main.lockCodes.lockCodes.value
        | if type != "string" or . == "" then
            error("device has no lockCodes.lockCodes value")
          else
            fromjson
          end
        | if type != "object" then
            error("lockCodes.lockCodes is not an object")
          else
            {format: "bp-lock-code-names-v1", sourceDeviceId: $device_id, lockCodes: .}
          end
      ' > "$temp_file"
    mv "$temp_file" "$output_file"
    trap - EXIT
    echo "Saved code-slot names to $output_file"
    ;;
  restore)
    [[ $# -eq 3 || $# -eq 4 ]] || { usage >&2; exit 1; }
    device_id=$2
    input_file=$3
    dry_run=${4:-}
    [[ -f "$input_file" ]] || { echo "Input file not found: $input_file" >&2; exit 1; }
    [[ -z "$dry_run" || "$dry_run" == "--dry-run" ]] || { usage >&2; exit 1; }
    jq -e '
      .format == "bp-lock-code-names-v1"
      and (.lockCodes | type == "object")
      and all(.lockCodes | to_entries[];
        (.key | test("^[1-9][0-9]*$")) and (.value | type == "string" and length > 0)
      )
    ' "$input_file" >/dev/null ||
      { echo "Invalid BP lock-code name export: $input_file" >&2; exit 1; }
    while IFS= read -r entry; do
      decoded=$(printf '%s' "$entry" | base64 --decode)
      slot=$(jq -r '.key' <<<"$decoded")
      name=$(jq -r '.value' <<<"$decoded")
      if [[ "$dry_run" == "--dry-run" ]]; then
        printf 'Would restore slot %s name (%d characters)\n' "$slot" "${#name}"
      else
        command_name_slot "$device_id" "$slot" "$name"
        printf 'Restored slot %s name\n' "$slot"
      fi
    done < <(jq -r '.lockCodes | to_entries | sort_by(.key | tonumber)[] | @base64' "$input_file")
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
