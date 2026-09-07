-- Copyright 2026 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local capabilities = require "st.capabilities"
local cc = require "st.zwave.CommandClass"
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version = 2 })
local features = require "legacy-handlers.schlage-lock.schlage-lock-bp.features"

local FINGERPRINTS = {
  { mfr = 0x003B, prod = 0x0001, model = 0x0469 },
  { mfr = 0x003B, prod = 0x6341, model = 0x5044 },
  { mfr = 0x003B, prod = 0x0001, model = 0x0468 },
  { mfr = 0x003B, prod = 0x6349, model = 0x5044 },
}

local function can_handle(_, _, device)
  for _, fingerprint in ipairs(FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      return true
    end
  end
  return false
end

local function capability_handlers()
  local handlers = {}
  for capability_id, commands in pairs(features.command_params) do
    local capability = capabilities[capability_id]
    if capability then
      local mapped_commands = {}
      for command_name in pairs(commands) do
        local command = capability.commands[command_name]
        if command then
          mapped_commands[command.NAME] = features.setting_command
        end
      end
      handlers[capability.ID] = mapped_commands
    end
  end
  return handlers
end

return {
  NAME = "Schlage Lock BP",
  can_handle = can_handle,
  capability_handlers = capability_handlers(),
  zwave_handlers = {
    [cc.CONFIGURATION] = {
      [Configuration.REPORT] = function(_, device, cmd)
        features.configuration_report(device, cmd)
      end,
    },
  },
}
