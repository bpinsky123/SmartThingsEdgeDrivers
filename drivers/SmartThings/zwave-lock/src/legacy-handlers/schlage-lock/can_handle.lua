-- Copyright 2025 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local capabilities = require "st.capabilities"
local constants = require "lock_utils.constants"

local function is_slga_migrated(device)
  return device:get_field(constants.DRIVER_STATE.SLGA_MIGRATED) == true
    or device:get_latest_state(
      "main",
      capabilities.lockCodes.ID,
      capabilities.lockCodes.migrated.NAME
    ) == true
end

return function(opts, driver, device, cmd)
  if is_slga_migrated(device) then
    return false
  end

  if device.zwave_manufacturer_id == 0x003B then
    return true, require "legacy-handlers.schlage-lock"
  end
  return false
end
