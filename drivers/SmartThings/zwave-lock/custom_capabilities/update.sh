#!/bin/sh
set -eu

cd "$(dirname "$0")"
root=$(pwd)
organization="c0da6863-f1a3-454d-aef6-05ef6b5bff4c"

capabilities="
heartsample19211.schlageLockAlarm
heartsample19211.autoLock
heartsample19211.lockAndLeave
heartsample19211.vacationMode
heartsample19211.keypadBeep
heartsample19211.interiorSchlageButton
heartsample19211.deviceNetworkId
"

for id in $capabilities; do
  echo "Updating capability: $id"
  smartthings capabilities:update "$id" \
    --capability-version 1 \
    -i "$root/$id.capability.json"

  echo "Updating presentation: $id"
  smartthings capabilities:presentation:update "$id" \
    --capability-version 1 \
    --organization "$organization" \
    -i "$root/$id.presentation.json"
done
