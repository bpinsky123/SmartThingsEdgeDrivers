# Schlage Lock Enhancements

## Purpose
This branch adds Schlage-specific Z-Wave lock features to the stock SmartThings Z-Wave Lock driver while keeping the generic lock handlers unchanged.

## Device-card profiles
- Legacy/unmigrated Schlage locks use Schlage profiles without lockUsers or lockCredentials.
- Migrated Schlage locks use dedicated profiles that expose SmartThings lockUsers and lockCredentials.
- The driver switches profiles based on migration state; the mobile app does not infer this from lockCodes.migrated.
- The Device Network ID remains visible through heartsample19211.deviceNetworkId.

## Custom capabilities
Namespace: heartsample19211

- lockActivity: read-only last activity, user name, and user index for routines.
- deviceNetworkId: read-only device network ID.
- Schlage configuration controls: alarm, Auto Lock, Lock and Leave, Vacation Mode, Keypad Beep, and Interior Schlage Button.

Use one setter command with an enum argument for each on/off setting. For example, Auto Lock is setAutoLock(mode), where mode is autolock or off. This is required for supported device-card and Automation presentations.

## Capability installation
Run from custom_capabilities on Debian:

    sh ./create.sh

The script targets heartsample19211 and is intended to create missing capabilities and update existing proposed ones and their presentations.

## Important status
- Do not show lock-user or credential controls on legacy/unmigrated profiles.
- Do show them only on migrated Schlage profiles.
- smoothgreen26756.lockActivity may exist from the first incorrect namespace run. It is unused; do not delete it unless explicitly desired.
- Validate custom-capability updates in the SmartThings CLI before packaging and testing the driver on a hub.