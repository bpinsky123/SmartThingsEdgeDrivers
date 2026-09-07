-- Copyright 2026 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local capabilities = require "st.capabilities"
local cc = require "st.zwave.CommandClass"
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version = 2 })
local Association = (require "st.zwave.CommandClass.Association")({ version = 1 })
local Notification = (require "st.zwave.CommandClass.Notification")({ version = 3 })
local LockCodesDefaults = require "st.zwave.defaults.lockCodes"
local features = require "legacy-handlers.schlage-lock.schlage-lock-bp.features"

local FINGERPRINTS = {
  { mfr = 0x003B, prod = 0x0001, model = 0x0469, profile = "schlage-be469" },
  { mfr = 0x003B, prod = 0x6341, model = 0x5044, profile = "schlage-be469" },
  { mfr = 0x003B, prod = 0x0001, model = 0x0468, profile = "schlage-be468" },
  { mfr = 0x003B, prod = 0x6349, model = 0x5044, profile = "schlage-be468" },
}

local function matching_fingerprint(device)
  for _, fingerprint in ipairs(FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      return fingerprint
    end
  end
end

local function can_handle(_, _, device)
  return matching_fingerprint(device) ~= nil
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

local function configuration_report(_, device, cmd)
  if cmd.args.parameter_number == 16 then
    local current = device:get_latest_state(
      "main", capabilities.lockCodes.ID, capabilities.lockCodes.codeLength.NAME)
    local reported = cmd.args.configuration_value
    if current ~= nil and current ~= reported then
      LockCodesDefaults.zwave_handlers[cc.NOTIFICATION][Notification.REPORT](_, device,
        Notification:Report({
          notification_type = Notification.notification_type.ACCESS_CONTROL,
          event = Notification.event.access_control.ALL_USER_CODES_DELETED,
        }))
    end
    device:emit_event(capabilities.lockCodes.codeLength(reported))
    return
  end
  features.configuration_report(device, cmd)
end

local function init(_, device)
  local fingerprint = matching_fingerprint(device)
  if fingerprint then
    device:try_update_metadata({ profile = fingerprint.profile })
  end
  features.emit_device_network_id(device)
end

local function do_configure(driver, device)
  device:send(Configuration:Get({ parameter_number = 16 }))
  device:send(Association:Set({
    grouping_identifier = 2,
    node_ids = { driver.environment_info.hub_zwave_id },
  }))
  features.refresh_settings(device)
end

return {
  NAME = "Schlage Lock BP",
  can_handle = can_handle,
  capability_handlers = capability_handlers(),
  zwave_handlers = {
    [cc.CONFIGURATION] = {
      [Configuration.REPORT] = configuration_report,
    },
  },
  lifecycle_handlers = {
    init = init,
    doConfigure = do_configure,
  },
}
