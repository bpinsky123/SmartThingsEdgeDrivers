-- Copyright 2026 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local capabilities = require "st.capabilities"
local cc = require "st.zwave.CommandClass"
local constants = require "lock_utils.constants"
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version = 2 })
local Association = (require "st.zwave.CommandClass.Association")({ version = 1 })
local Notification = (require "st.zwave.CommandClass.Notification")({ version = 3 })

local stock_capability_handlers = require "lock_handlers.capabilities"
local tables = require "lock_utils.tables"
local lock_utils = require "lock_utils.utils"
local features = require "legacy-handlers.schlage-lock.schlage-lock-bp.features"

local SCHLAGE_LOCK_CODE_LENGTH_PARAM = { number = 16, size = 1 }

local function call_parent_handler(handlers, driver, device, event, args)
  if type(handlers) == "function" then
    handlers = { handlers }
  end

  for _, handler in ipairs(handlers or {}) do
    handler(driver, device, event, args)
  end
end

local function capability_handlers()
  local handlers = {}

  for _, capability in pairs(features.capabilities) do
    local commands = capability and features.command_params[capability.ID]
    if commands then
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

local function migrated_user_lookup(device, code_id)
  local credential_index = tonumber(code_id)
  if credential_index == nil then return nil, nil end

  local credential = tables.find_entry(device, "credentials", credential_index)
  local user_index = credential and credential.userIndex or credential_index
  local user = tables.find_entry(device, "users", user_index)
  local name = user and user.userName or (credential and credential.credentialName)

  return name, user_index
end

local function configuration_report(driver, device, cmd)
  local parent_handlers = driver.zwave_handlers[cc.CONFIGURATION]
    and driver.zwave_handlers[cc.CONFIGURATION][Configuration.REPORT]
  call_parent_handler(parent_handlers, driver, device, cmd)
  features.configuration_report(device, cmd)
end

local function notification_report(driver, device, cmd)
  local parent_handlers = driver.zwave_handlers[cc.NOTIFICATION]
    and driver.zwave_handlers[cc.NOTIFICATION][Notification.REPORT]
  call_parent_handler(parent_handlers, driver, device, cmd)

  features.activity_from_notification(device, cmd, function(code_id)
    return migrated_user_lookup(device, code_id)
  end)
end

local function refresh_handler(driver, device, command)
  if command.component ~= nil and command.component ~= "main" then return end

  -- Preserve the immediate main-card refresh, then avoid competing with the
  -- response-paced settings queue before reading migrated credentials.
  stock_capability_handlers.refresh(driver, device, command)
  features.refresh_settings(device, function(refreshed_device)
    lock_utils.sync_device_state(refreshed_device)
  end)
end

local function init(_, device)
  features.emit_device_network_id(device)
  features.refresh_settings(device)
end

local function do_configure(driver, device)
  device:send(Configuration:Get({
    parameter_number = SCHLAGE_LOCK_CODE_LENGTH_PARAM.number,
  }))
  device:send(Association:Set({
    grouping_identifier = 2,
    node_ids = { driver.environment_info.hub_zwave_id },
  }))
  features.refresh_settings(device)
end

return {
  NAME = "Schlage Lock BP Migrated",
  can_handle = require "schlage-lock.schlage-lock-bp.can_handle",
  capability_handlers = (function()
    local handlers = capability_handlers()
    handlers[capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = refresh_handler,
    }
    return handlers
  end)(),
  zwave_handlers = {
    [cc.CONFIGURATION] = {
      [Configuration.REPORT] = configuration_report,
    },
    [cc.NOTIFICATION] = {
      [Notification.REPORT] = notification_report,
    },
  },
  lifecycle_handlers = {
    init = init,
    doConfigure = do_configure,
  },
}
