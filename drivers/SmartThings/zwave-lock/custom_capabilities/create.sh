#!/bin/sh
set -eu

root="$(cd "$(dirname "$0")" && pwd)"
namespace="heartsample19211"
organization="c0da6863-f1a3-454d-aef6-05ef6b5bff4c"

capabilities="
lockActivity
deviceNetworkId
schlageLockAlarm
autoLock
lockAndLeave
vacationMode
keypadBeep
schlageInteriorControl
"

for name in $capabilities; do
  id="$namespace.$name"
  if ! smartthings capabilities:update "$id" --capability-version 1 -i "$root/$id.capability.json"; then
    smartthings capabilities:create --namespace "$namespace" --organization "$organization" -i "$root/$id.capability.json"
  fi

  if ! smartthings capabilities:presentation:update "$id" --capability-version 1 --organization "$organization" -i "$root/$id.presentation.json"; then
    smartthings capabilities:presentation:create "$id" --organization "$organization" --capability-version 1 -i "$root/$id.presentation.json"
  fi
done
