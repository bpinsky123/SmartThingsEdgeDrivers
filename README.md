# Z-Wave Lock BP Beta — Schlage BE468 / BE469

Z-Wave Lock BP Beta is a community SmartThings Edge driver for legacy Schlage BE468 and BE469 Z-Wave locks.

It builds on the original Schlage-specific feature work by [@philh30](https://community.smartthings.com/u/philh30) in the [Z-Wave Lock PH driver](https://community.smartthings.com/t/st-edge-z-wave-lock-ph/255998), while incorporating the current SmartThings Z-Wave Lock driver and adding clearer lock activity, named keypad activity, and more reliable initialization and refresh handling.

This is a beta release. It has been tested with Schlage BE468/BE469 hardware, but feedback from owners of other Schlage Z-Wave variants is welcome.

## Features

- Standard SmartThings lock, battery, refresh, tamper, and lock-code support
- Schlage configuration controls: Auto-lock, keypad beep, Lock & Leave, vacation mode, interior Schlage button, and alarm mode/sensitivity settings
- Lock activity reporting for manual, keypad, remote, and auto-lock operations, plus lock jams
- Named keypad activity when SmartThings has a name for the code slot, such as `Unlocked with keypad by Test 1`
- Device Network ID shown in Settings for troubleshooting
- Optional code/credential refresh during a pull-down refresh
- A recovery query for affected newer Schlage firmware that may fail to report an Auto-lock setting change

## Before switching drivers: save code-slot names

Lock PINs cannot be read from the lock, and lock-code names are maintained by the current SmartThings driver rather than stored on the lock itself.

Before switching from another driver, save the current `lockCodes` value. This gives you a record of existing slot names in case the new driver initially displays generic names such as `Code 1`.

Using the SmartThings CLI:

```bash
smartthings devices:status <DEVICE_ID> --json
```

Find and save `main → lockCodes → lockCodes`.

You can also save the names from the [SmartThings Advanced Web App](https://my.smartthings.com/): open the device, select **Status**, then find `main → lockCodes → lockCodes` and copy its JSON value.

Keep this as a private reference. It contains code-slot names only, not PINs. After switching drivers, rename slots if necessary using Smart Lock Guest Access (SLGA), or the `lockCodes` `nameSlot` command in the SmartThings Advanced Web App or SmartThings CLI.

## Installation

1. Join [h0ckeysk8er’s Test Drivers](https://bestow-regional.api.smartthings.com/invite/Boj0ADZQJ7MA).
2. Select **Enroll**.
3. Under **Available Drivers**, install **Z-Wave Lock BP Beta** on the hub containing the lock.
4. For an already paired lock, open it in the SmartThings app and select **Menu → Driver → Select different driver → Z-Wave Lock BP Beta**.

A driver switch normally does not require excluding or re-pairing the lock.

## First initialization and refresh

After selecting the driver, it reads the Schlage configuration parameters so the Settings controls can populate. Allow a little time after the driver switch or package update.

A pull-down refresh reads lock state, battery, and Schlage feature settings. If **Refresh lock codes and credentials** is enabled, it also queries code slots. This takes longer because each slot is queried individually.

## Important notes

- This driver reports the state and notifications sent by the lock. A `Lock jammed` event can indicate a mechanical/calibration issue, weak batteries, mounting or strike-plate alignment, or lock hardware trouble; it does not necessarily indicate a driver problem. The driver reports the lock state as `Unknown` after a jam notification, which may disable Lock/Unlock controls in the SmartThings mobile app until the lock reports a known state.
- The lock cannot disclose existing PIN values. A code refresh can determine slot occupancy, but names are maintained locally by SmartThings.
- Switching among unrelated drivers may cause locally maintained code-slot names to fall back to generic names such as `Code 1`.
- This channel also contains **Z-Wave Lock BP Migration Test**, intended only for advanced testing of SmartThings’ evolving lock-code migration behavior. Normal users should install **Z-Wave Lock BP Beta**. DM [@h0ckeysk8er](https://community.smartthings.com/u/h0ckeysk8er) if interested in testing the migration version.

## Capturing logs for an issue

For driver issues, include a focused log capture showing the complete action and the lock’s response.

1. Download and install the [SmartThings CLI](https://github.com/SmartThingsCommunity/smartthings-cli/releases).
2. Start capture before reproducing the problem:

   ```bash
   smartthings edge:drivers:logcat 798203cd-dd17-4785-b3ba-5dd68ac90c22
   ```

   The CLI prompts you to select a hub if you have more than one.
3. With logging running, perform the failing action once—for example, change Auto-lock, pull down to refresh, use a keypad code, or lock/unlock from the app.
4. Wait for the lock response or timeout, then press `Ctrl+C` to stop logging.
5. Provide the complete log section beginning immediately before the action and ending after the response or timeout.

Remove or replace any PINs before posting a log.

## Feedback requested

Please include:

- Lock model and firmware version, if known
- Hub model
- Whether the lock was newly paired or switched from another driver
- The action that failed
- A focused SmartThings CLI log capture using the instructions above

Source and issue tracking: [SmartThingsEdgeDrivers — Z-Wave Lock](https://github.com/bpinsky123/SmartThingsEdgeDrivers/tree/schlage-lock-clean/drivers/SmartThings/zwave-lock).
