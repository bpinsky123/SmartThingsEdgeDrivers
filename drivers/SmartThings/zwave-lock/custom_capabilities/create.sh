#!/bin/sh
set -eu

root="$(cd "$(dirname "$0")" && pwd)"
namespace="heartsample19211"

capabilities="
lockActivity
deviceNetworkId
schlageLockAlarm
autoLock
lockAndLeave
vacationMode
keypadBeep
schlageInteriorButton
"

for name in $capabilities; do
  id="${namespace}.${name}"
  smartthings capabilities:create --namespace "$namespace" -i "${root}/${id}.capability.json"
  smartthings capabilities:presentation:create "$id" --capability-version 1 -i "${root}/${id}.presentation.json"
done
