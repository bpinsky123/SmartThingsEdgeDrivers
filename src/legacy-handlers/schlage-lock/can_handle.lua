-- Copyright 2025 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local capabilities = require "st.capabilities"
local constants = require "lock_utils.constants"

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

  if migrated then
    return false
  end

  if is_schlage then
    return true, require "legacy-handlers.schlage-lock"
  end
  return false
end
