-- Copyright 2026 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0


local SCHLAGE_MFR = 0x003B
local LEGACY_SCHLAGE_FINGERPRINTS = {
  { product_type = 0x0001, product_id = 0x0469 }, -- BE469ZP
  { product_type = 0x6341, product_id = 0x5044 }, -- BE469
  { product_type = 0x0001, product_id = 0x0468 }, -- BE468ZP
  { product_type = 0x6349, product_id = 0x5044 }, -- BE468
}

return function(opts, driver, device, cmd)
  local consts = require("lock_utils.constants")
  local slga_migrated = device:get_field(consts.DRIVER_STATE.SLGA_MIGRATED)

  if slga_migrated and device.zwave_manufacturer_id == SCHLAGE_MFR then
    return true, require("schlage-lock")
  end

  for _, fingerprint in ipairs(LEGACY_SCHLAGE_FINGERPRINTS) do
    if device:id_match(SCHLAGE_MFR, fingerprint.product_type, fingerprint.product_id) then
      return true, require("schlage-lock")
    end
  end

  return false
end
