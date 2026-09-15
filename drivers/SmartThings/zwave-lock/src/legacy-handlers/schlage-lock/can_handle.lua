-- Copyright 2025 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local capabilities = require "st.capabilities"
local constants = require "lock_utils.constants"
local log = require "log"

local function migration_state(device)
  local persisted = device:get_field(constants.DRIVER_STATE.SLGA_MIGRATED)
  local cloud = device:get_latest_state(
    "main",
    capabilities.lockCodes.ID,
    capabilities.lockCodes.migrated.NAME
  )
  return persisted, cloud
end

return function(opts, driver, device, cmd)
  local persisted_migrated, cloud_migrated = migration_state(device)
  local migrated = persisted_migrated == true or cloud_migrated == true
  local manufacturer = device.zwave_manufacturer_id
  local is_schlage = manufacturer == 0x003B

  log.info(string.format(
    "BP diagnostic legacy Schlage selector: manufacturer=%s persistent_migrated=%s cloud_migrated=%s accepted=%s",
    manufacturer and string.format("0x%04X", manufacturer) or "nil",
    tostring(persisted_migrated),
    tostring(cloud_migrated),
    tostring(not migrated and is_schlage)
  ))

  if migrated then
    return false
  end

  if is_schlage then
    return true, require "legacy-handlers.schlage-lock"
  end
  return false
end
