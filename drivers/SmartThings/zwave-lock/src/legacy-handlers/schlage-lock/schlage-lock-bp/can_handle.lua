-- Copyright 2026 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local FINGERPRINTS = {
  { mfr = 0x003B, prod = 0x0001, model = 0x0469 },
  { mfr = 0x003B, prod = 0x6341, model = 0x5044 },
  { mfr = 0x003B, prod = 0x0001, model = 0x0468 },
  { mfr = 0x003B, prod = 0x6349, model = 0x5044 },
}

return function(_, _, device)
  for _, fingerprint in ipairs(FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      return true, require "legacy-handlers.schlage-lock.schlage-lock-bp"
    end
  end

  return false
end
