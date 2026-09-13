local constants = require "lock_utils.constants"

local FINGERPRINTS = {
  { mfr = 0x003B, prod = 0x0001, model = 0x0468 },
  { mfr = 0x003B, prod = 0x0001, model = 0x0469 },
  { mfr = 0x003B, prod = 0x6341, model = 0x5044 },
  { mfr = 0x003B, prod = 0x6349, model = 0x5044 },
}

return function(_, _, device)
  if device:get_field(constants.DRIVER_STATE.SLGA_MIGRATED) ~= true then
    return false
  end

  for _, fingerprint in ipairs(FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      return true, require "schlage-lock.schlage-lock-bp"
    end
  end

  return false
end
