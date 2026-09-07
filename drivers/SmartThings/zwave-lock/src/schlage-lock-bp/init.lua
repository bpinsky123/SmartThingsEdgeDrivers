-- Copyright 2026 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

-- This subdriver copies the stock migrated Schlage handler locally, then adds
-- BP-specific capabilities to that copy.  It never changes root defaults.
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version = 2 })
local Notification = (require "st.zwave.CommandClass.Notification")({ version = 3 })
local CommandClass = require "st.zwave.CommandClass"
local constants = require "st.zwave.constants"
local features = require "schlage-lock-bp.features"
local stock = require "schlage-lock"

local function copy_table(source)
  local copy = {}
  for key, value in pairs(source or {}) do copy[key] = value end
  return copy
end

local bp = copy_table(stock)
bp.NAME = "Schlage Lock BP"
bp.can_handle = require "schlage-lock-bp.can_handle"

bp.capability_handlers = {}
for capability_id, handlers in pairs(stock.capability_handlers or {}) do
  bp.capability_handlers[capability_id] = copy_table(handlers)
end
for capability_id, commands in pairs(features.command_specs) do
  bp.capability_handlers[capability_id] = bp.capability_handlers[capability_id] or {}
  for command_name, _ in pairs(commands) do
    bp.capability_handlers[capability_id][command_name] = features.setting_command
  end
end

bp.zwave_handlers = {}
for command_class, handlers in pairs(stock.zwave_handlers or {}) do
  bp.zwave_handlers[command_class] = copy_table(handlers)
end

bp.zwave_handlers[CommandClass.CONFIGURATION] = bp.zwave_handlers[CommandClass.CONFIGURATION] or {}
local stock_configuration_report = bp.zwave_handlers[CommandClass.CONFIGURATION][Configuration.REPORT]
bp.zwave_handlers[CommandClass.CONFIGURATION][Configuration.REPORT] = function(driver, device, cmd)
  if stock_configuration_report then stock_configuration_report(driver, device, cmd) end
  features.configuration_report(driver, device, cmd)
end

bp.zwave_handlers[CommandClass.NOTIFICATION] = bp.zwave_handlers[CommandClass.NOTIFICATION] or {}
local stock_notification_report = bp.zwave_handlers[CommandClass.NOTIFICATION][Notification.REPORT]
bp.zwave_handlers[CommandClass.NOTIFICATION][Notification.REPORT] = function(driver, device, cmd)
  if stock_notification_report then stock_notification_report(driver, device, cmd) end
  features.activity_from_notification(driver, device, cmd, function(code_id)
    local code_state = device:get_field(constants.CODE_STATE) or {}
    return code_state["setName" .. tostring(code_id)], code_id
  end)
end

bp.lifecycle_handlers = copy_table(stock.lifecycle_handlers)
local stock_added = bp.lifecycle_handlers.added
bp.lifecycle_handlers.added = function(driver, device)
  if stock_added then stock_added(driver, device) end
  features.emit_device_network_id(device)
  features.refresh_settings(driver, device)
end

local stock_configure = bp.lifecycle_handlers.doConfigure
bp.lifecycle_handlers.doConfigure = function(driver, device)
  if stock_configure then stock_configure(driver, device) end
  features.emit_device_network_id(device)
  features.refresh_settings(driver, device)
end

return bp
