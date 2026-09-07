-- Copyright 2026 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local SCHLAGE_FINGERPRINTS = {
  { manufacturer_id = 0x003B, product_type = 0x0001, product_id = 0x0469 }, -- BE469ZP
  { manufacturer_id = 0x003B, product_type = 0x6341, product_id = 0x5044 }, -- BE469
  { manufacturer_id = 0x003B, product_type = 0x0001, product_id = 0x0468 }, -- BE468ZP
  { manufacturer_id = 0x003B, product_type = 0x6349, product_id = 0x5044 }, -- BE468
}

return function(_, _, device, _)
  for _, fingerprint in ipairs(SCHLAGE_FINGERPRINTS) do
    if device:id_match(fingerprint.manufacturer_id, fingerprint.product_type, fingerprint.product_id) then
      return true, require("schlage-lock-bp")
    end
  end

  return false
end
