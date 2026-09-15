-- Copyright 2025 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local capabilities = require "st.capabilities"
local constants = require "lock_utils.constants"
local log = require "log"

local DIAGNOSTIC_LOGGED = "bp_diag_legacy_schlage_selector_logged"

local function migration_state(device)
  local persisted = device:get_field(constants.DRIVER_STATE.SLGA_MIGRATED)
  local cloud = device:get_latest_state(
    "main",
    capabilities.lockCodes.ID,
    capabilities.lockCodes.migrated.NAME
  )
  return persisted, cloud
end

local function bp_fingerprint_profile(device)
  if device:id_match(0x003B, 0x0001, 0x0469) then return "bp-schlage-be469" end
  if device:id_match(0x003B, 0x6341, 0x5044) then return "bp-schlage-be469" end
  if device:id_match(0x003B, 0x0001, 0x0468) then return "bp-schlage-be468" end
  if device:id_match(0x003B, 0x6349, 0x5044) then return "bp-schlage-be468" end
end

return function(opts, driver, device, cmd)
  local persisted_migrated, cloud_migrated = migration_state(device)
  local migrated = persisted_migrated == true or cloud_migrated == true
  local manufacturer = device.zwave_manufacturer_id
  local is_schlage = manufacturer == 0x003B
  local fingerprint_profile = bp_fingerprint_profile(device)
  local accepted = not migrated and is_schlage

  if not device:get_field(DIAGNOSTIC_LOGGED) then
    device:set_field(DIAGNOSTIC_LOGGED, true)
    log.info(string.format(
      "BP diagnostic legacy route: manufacturer=%s persistent_migrated=%s cloud_migrated=%s bp_fingerprint=%s accepted=%s profile=%s",
      manufacturer and string.format("0x%04X", manufacturer) or "nil",
      tostring(persisted_migrated),
      tostring(cloud_migrated),
      tostring(fingerprint_profile),
      tostring(accepted),
      tostring(device.profile.name)
    ))
  end

  if migrated then
    return false
  end

  if is_schlage then
    return true, require "legacy-handlers.schlage-lock"
  end
  return false
end
