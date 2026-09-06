local M = {}

local PROFILE_FIELD = "schlage_profile"

local migrated_profiles = {
  [0x6349] = {[0x5044] = "schlage-be468-migrated"},
  [0x0001] = {[0x0468] = "schlage-be468-migrated", [0x0469] = "schlage-be469-migrated"},
  [0x6341] = {[0x5044] = "schlage-be469-migrated"},
}

function M.migrated(device)
  if device.zwave_manufacturer_id ~= 0x003B then return nil end
  local products = migrated_profiles[device.zwave_product_type]
  return products and products[device.zwave_product_id]
end

--- Ensure a migrated Schlage lock has the profile that exposes lockUsers and
--- lockCredentials.  The field prevents an unnecessary metadata update on
--- every driver restart, while allowing existing migrated devices to be
--- repaired after this driver version is installed.
function M.update_migrated_profile(device)
  local profile = M.migrated(device)
  if profile and device:get_field(PROFILE_FIELD) ~= profile then
    device:try_update_metadata({ profile = profile })
    device:set_field(PROFILE_FIELD, profile, { persist = true })
  end
end

return M
