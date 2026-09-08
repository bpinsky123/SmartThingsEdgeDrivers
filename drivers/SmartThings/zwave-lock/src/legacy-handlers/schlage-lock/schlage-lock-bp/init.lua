-- Copyright 2026 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local capabilities = require "st.capabilities"
local constants = require "st.zwave.constants"
local cc = require "st.zwave.CommandClass"
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version = 2 })
local Association = (require "st.zwave.CommandClass.Association")({ version = 1 })
local DoorLock = (require "st.zwave.CommandClass.DoorLock")({ version = 1 })
local Notification = (require "st.zwave.CommandClass.Notification")({ version = 3 })
local LockCodesDefaults = require "st.zwave.defaults.lockCodes"
local features = require "legacy-handlers.schlage-lock.schlage-lock-bp.features"
local stock_capability_handlers = require "lock_handlers.capabilities"
local SETTINGS_REFRESH_ISSUED = "bp_settings_refresh_issued"
local log = require "log"

local FINGERPRINTS = {
  { mfr = 0x003B, prod = 0x0001, model = 0x0469, profile = "bp-schlage-be469-legacy" },
  { mfr = 0x003B, prod = 0x6341, model = 0x5044, profile = "bp-schlage-be469-legacy" },
  { mfr = 0x003B, prod = 0x0001, model = 0x0468, profile = "bp-schlage-be468-legacy" },
  { mfr = 0x003B, prod = 0x6349, model = 0x5044, profile = "bp-schlage-be468-legacy" },
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

local function refresh_handler(driver, device, command)
  if command.component == "main" then
    -- Fast stock refresh for the primary device card state.
    stock_capability_handlers.refresh(driver, device, command)

    if device.preferences.refreshCodes then
      LockCodesDefaults.get_refresh_commands(driver, device, "main", 0)
    end
  end

  -- Start the deduplicated, response-paced Schlage configuration scan.
  features.refresh_settings(device)
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

  if fingerprint and device.profile.name ~= fingerprint.profile then
    device:try_update_metadata({ profile = fingerprint.profile })
  end

 features.emit_device_network_id(device)
end

local function call_parent_handler(handlers, driver, device, event, args)
  if type(handlers) == "function" then
    handlers = { handlers }
  end

  for _, handler in ipairs(handlers or {}) do
    hlocal function legacy_user_lookup(device, code_id)
  local slot = tonumber(code_id)
  if slot == nil then return nil, nil end

  local lock_codes = device:get_field(constants.LOCK_CODES)
  if type(lock_codes) ~= "table" then lock_codes = {} end

  local name = lock_codes[slot] or lock_codes[tostring(slot)]
  if (name == nil or name == "") and slot == 0 then
    name = "Master Code"
  end
  return name, slot
end


local function notification_report(driver, device, cmd)
  -- Preserve every stock notification side effect before adding BP activity.
  local parent_handlers = driver.zwave_handlers[cc.NOTIFICATION]
    and driver.zwave_handlers[cc.NOTIFICATION][Notification.REPORT]
  call_parent_handler(parent_handlers, driver, device, cmd)

  features.activity_from_notification(device, cmd, legacy_user_lookup)
end
.
    return nil, tonumber(code_id)
  end)
end

local function bp_added_handler(driver, device, event, args)
  -- Keep BP profile selection and Device Network ID reporting.
  init(driver, device)

  -- Preserve stock initialization: initial refresh, battery/lock state,
  -- lock-code setup, tamper clear, and stock DNi handling.
  call_parent_handler(driver.lifecycle_handlers.added, driver, device, event, args)
end

local function do_configure(driver, device)
  device:send(Configuration:Get({ parameter_number = 16 }))
  device:send(Association:Set({
    grouping_identifier = 2,
    node_ids = { driver.environment_info.hub_zwave_id },
  }))
  features.refresh_settings(device)
end

local function driver_switched(driver, device)
  init(driver, device)
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })
end

local function info_changed(driver, device, event, args)
  call_parent_handler(driver.lifecycle_handlers.infoChanged, driver, device, event, args)

  if device:supports_capability(capabilities.tamperAlert) then
    device:emit_event(capabilities.tamperAlert.tamper.clear())
  end

local activity = features.capabilities.activity

if device:supports_capability(activity) then
  local current = device:get_latest_state(
    "main", activity.ID, activity.activity.NAME)

  if current == nil then
    features.emit_activity(
      device,
      "unknown",
      "No lock activity yet",
      "",
      0
    )
  end
end

  if device:get_field(SETTINGS_REFRESH_ISSUED) then
    return
  end

  features.emit_device_network_id(device)

  if features.refresh_settings(device) then
    device:set_field(SETTINGS_REFRESH_ISSUED, true)
    log.info("BP infoChanged: started paced Schlage settings refresh")
  end
end

return {
  NAME = "Schlage Lock BP",
  can_handle = can_handle,
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
    added = bp_added_handler,
--    added = init,
    driverSwitched = driver_switched,
    infoChanged = info_changed,
    doConfigure = do_configure,
  },
}
