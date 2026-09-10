-- Copyright 2026 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local capabilities = require "st.capabilities"
local constants = require "st.zwave.constants"
local cc = require "st.zwave.CommandClass"
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version = 2 })
local Association = (require "st.zwave.CommandClass.Association")({ version = 1 })
local Battery = (require "st.zwave.CommandClass.Battery")({ version = 1 })
local Notification = (require "st.zwave.CommandClass.Notification")({ version = 3 })
local UserCode = (require "st.zwave.CommandClass.UserCode")({ version = 1 })
local LockCodesDefaults = require "st.zwave.defaults.lockCodes"
local features = require "legacy-handlers.schlage-lock.schlage-lock-bp.features"
local stock_capability_handlers = require "lock_handlers.capabilities"
local log = require "log"

-- Bootstrap uses two signals: infoChanged means that the BP profile is active;
-- Battery REPORT means the stock main-card refresh has completed.
local BOOTSTRAP_REQUIRED = "bp_bootstrap_required"
local BP_PROFILE_READY = "bp_profile_ready"
local STOCK_BATTERY_RECEIVED = "bp_stock_battery_received"
local BOOTSTRAP_STARTED = "bp_bootstrap_started"
local CODE_INIT_PENDING = "bp_legacy_code_init_pending"
local CODE_LENGTH_PENDING = "bp_legacy_code_length_pending"
local SETTINGS_AFTER_BATTERY = "bp_settings_after_battery"
local CODE_INIT_TIMEOUT_SECONDS = 20
local PROFILE_READY_RETRY_COUNT = "bp_profile_ready_retry_count"
local PROFILE_READY_RETRY_SECONDS = 1
local PROFILE_READY_MAX_RETRIES = 12

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
        if command then mapped_commands[command.NAME] = features.setting_command end
      end
      handlers[capability.ID] = mapped_commands
    end
  end
  return handlers
end

local function call_parent_handler(handlers, driver, device, event, args)
  if type(handlers) == "function" then handlers = { handlers } end
  for _, handler in ipairs(handlers or {}) do
    handler(driver, device, event, args)
  end
end

local function supports_legacy_code_initialization(device)
  return device:supports_capability(capabilities.lockCodes)
    and device:get_latest_state(
      "main", capabilities.lockCodes.ID, capabilities.lockCodes.migrated.NAME) ~= true
end

local function start_legacy_code_scan(device)
  device:set_field(CODE_INIT_PENDING, true)
  device:send(UserCode:UsersNumberGet({}))

  device.thread:call_with_delay(CODE_INIT_TIMEOUT_SECONDS, function()
    if device:get_field(CODE_INIT_PENDING) then
      device:set_field(CODE_INIT_PENDING, nil)
      log.warn("BP legacy code initialization timed out; no automatic retry")
    end
  end)
end

local function begin_legacy_code_initialization(_, device)
  if not supports_legacy_code_initialization(device) then return end
  if device:get_field(CODE_INIT_PENDING)
      or device:get_field(CODE_LENGTH_PENDING) then
    return
  end

  local code_length = device:get_latest_state(
    "main", capabilities.lockCodes.ID, capabilities.lockCodes.codeLength.NAME)

  if code_length == nil then
    device:set_field(CODE_LENGTH_PENDING, true)
    device:send(Configuration:Get({ parameter_number = 16 }))
    return
  end

  start_legacy_code_scan(device)
end

-- The only BP bootstrap entry point.  It may be called by infoChanged and
-- Battery REPORT, but starts precisely once after both signals are true.
local function try_start_bootstrap(driver, device)
  if not device:get_field(BOOTSTRAP_REQUIRED)
      or not device:get_field(BP_PROFILE_READY)
      or not device:get_field(STOCK_BATTERY_RECEIVED)
      or device:get_field(BOOTSTRAP_STARTED) then
    return false
  end

  local started = features.refresh_settings(device, function(refreshed_device)
    refreshed_device:set_field(BOOTSTRAP_REQUIRED, nil)
    refreshed_device:set_field(BOOTSTRAP_STARTED, nil)
    begin_legacy_code_initialization(driver, refreshed_device)
  end)
  if started then
    device:set_field(BOOTSTRAP_STARTED, true)
    log.info("BP bootstrap: starting paced Schlage settings refresh")
  end
  return started
end

local function refresh_handler(driver, device, command)
  if command.component == nil or command.component == "main" then
    stock_capability_handlers.refresh(driver, device, command)

    if device:get_field(BOOTSTRAP_REQUIRED) then
      -- Stock refresh owns the initial Battery GET.  Battery REPORT will
      -- release the bootstrap helper after the BP profile is ready.
      device:set_field(STOCK_BATTERY_RECEIVED, nil)
    else
      -- Later app pull-down refreshes retain the same stock-first ordering.
      device:set_field(SETTINGS_AFTER_BATTERY, true)
      if device.preferences.refreshCodes
          and not device:get_field(CODE_INIT_PENDING)
          and not device:get_field(CODE_LENGTH_PENDING) then
        LockCodesDefaults.get_refresh_commands(driver, device, "main", 0)
      end
    end
    return
  end

  -- Future settings-component refreshes can refresh BP settings directly.
  features.refresh_settings(device)
end

local function configuration_report(driver, device, cmd)
  if cmd.args.parameter_number == 16 then
    local current = device:get_latest_state(
      "main", capabilities.lockCodes.ID, capabilities.lockCodes.codeLength.NAME)
    local reported = cmd.args.configuration_value

    if current ~= nil and current ~= reported then
      LockCodesDefaults.zwave_handlers[cc.NOTIFICATION][Notification.REPORT](driver, device,
        Notification:Report({
          notification_type = Notification.notification_type.ACCESS_CONTROL,
          event = Notification.event.access_control.ALL_USER_CODES_DELETED,
        }))
    end

    device:emit_event(capabilities.lockCodes.codeLength(reported))

    if device:get_field(CODE_LENGTH_PENDING) then
      device:set_field(CODE_LENGTH_PENDING, nil)
      start_legacy_code_scan(device)
    end
    return
  end

  features.configuration_report(device, cmd)
end

local function init(_, device)
  local fingerprint = matching_fingerprint(device)
  if fingerprint and device.profile.name ~= fingerprint.profile then
    device:try_update_metadata({ profile = fingerprint.profile })
  end
end

local function legacy_user_lookup(device, code_id)
  local slot = tonumber(code_id)
  if slot == nil then return nil, nil end

  local lock_codes = device:get_field(constants.LOCK_CODES)
  local name
  if type(lock_codes) == "table" then
    name = lock_codes[tostring(slot)] or lock_codes[slot]
  end
  if name == nil or name == "" then
    name = LockCodesDefaults.get_code_name(device, slot)
  end
  if (name == nil or name == "") and slot == 0 then name = "Master Code" end
  return name, slot
end

local function notification_report(driver, device, cmd)
  local parent_handlers = driver.zwave_handlers[cc.NOTIFICATION]
    and driver.zwave_handlers[cc.NOTIFICATION][Notification.REPORT]
  call_parent_handler(parent_handlers, driver, device, cmd)
  features.activity_from_notification(device, cmd, legacy_user_lookup)
end

local function battery_report(driver, device, cmd)
  local parent_handlers = driver.zwave_handlers[cc.BATTERY]
    and driver.zwave_handlers[cc.BATTERY][Battery.REPORT]
  call_parent_handler(parent_handlers, driver, device, cmd)

  if device:get_field(BOOTSTRAP_REQUIRED) then
    device:set_field(STOCK_BATTERY_RECEIVED, true)
    try_start_bootstrap(driver, device)
    return
  end

  if device:get_field(SETTINGS_AFTER_BATTERY) then
    device:set_field(SETTINGS_AFTER_BATTERY, nil)
    features.refresh_settings(device)
  end
end

local function users_number_report(driver, device, cmd)
  local legacy_handler = LockCodesDefaults.zwave_handlers[cc.USER_CODE]
    and LockCodesDefaults.zwave_handlers[cc.USER_CODE][UserCode.USERS_NUMBER_REPORT]

  if type(legacy_handler) ~= "function" then
    log.error("BP cannot initialize legacy codes: default users-number handler is unavailable")
    return
  end

  -- Preserve normal legacy behavior, including lockCodes.maxCodes.
  legacy_handler(driver, device, cmd)

  -- Only BP's post-settings bootstrap begins a complete code scan.
  if not device:get_field(CODE_INIT_PENDING) then return end

  device:set_field(CODE_INIT_PENDING, nil)
  driver:inject_capability_command(device, {
    capability = capabilities.lockCodes.ID,
    command = capabilities.lockCodes.commands.reloadAllCodes.NAME,
    args = {},
  })
end

local function bp_added_handler(driver, device, event, args)
  init(driver, device)
  device:set_field(BOOTSTRAP_REQUIRED, true)
  device:set_field(BP_PROFILE_READY, nil)
  device:set_field(STOCK_BATTERY_RECEIVED, nil)
  device:set_field(BOOTSTRAP_STARTED, nil)
  call_parent_handler(driver.lifecycle_handlers.added, driver, device, event, args)
end

local function driver_switched(driver, device)
  init(driver, device)
  device:set_field(BOOTSTRAP_REQUIRED, true)
  device:set_field(BP_PROFILE_READY, nil)
  device:set_field(STOCK_BATTERY_RECEIVED, nil)
  device:set_field(BOOTSTRAP_STARTED, nil)
  device:try_update_metadata({ provisioning_state = "PROVISIONED" })
end

local function settings_component(device)
  local components = device.profile.components
  if components.settings then return components.settings end
  for _, component in ipairs(components) do
    if component.id == "settings" then return component end
  end
end

local function bp_settings_profile_is_ready(device)
  local component = settings_component(device)
  local auto_lock = features.capabilities.auto_lock
  return component ~= nil
    and device:supports_capability_by_id(auto_lock.ID, component.id)
end

local function mark_profile_ready_and_try_bootstrap(driver, device)
  if not bp_settings_profile_is_ready(device) then
    local retries = device:get_field(PROFILE_READY_RETRY_COUNT) or 0
    if retries >= PROFILE_READY_MAX_RETRIES then
      log.warn("BP bootstrap: BP settings component did not become active")
      return false
    end

    device:set_field(PROFILE_READY_RETRY_COUNT, retries + 1)
    device.thread:call_with_delay(PROFILE_READY_RETRY_SECONDS, function()
      mark_profile_ready_and_try_bootstrap(driver, device)
    end)
    return false
  end

  device:set_field(PROFILE_READY_RETRY_COUNT, nil)
  if not device:get_field(BP_PROFILE_READY) then
    if device:supports_capability(capabilities.tamperAlert) then
      device:emit_event(capabilities.tamperAlert.tamper.clear())
    end

    local activity = features.capabilities.activity
    if device:supports_capability(activity) then
      local current = device:get_latest_state("main", activity.ID, activity.activity.NAME)
      if current == nil then
        features.emit_activity(device, "unknown", "No lock activity yet", "", 0)
      end
    end

    features.emit_device_network_id(device)
    device:set_field(BP_PROFILE_READY, true)
  end

  return try_start_bootstrap(driver, device)
end

local function info_changed(driver, device, event, args)
  call_parent_handler(driver.lifecycle_handlers.infoChanged, driver, device, event, args)
  mark_profile_ready_and_try_bootstrap(driver, device)
end

local function do_configure(driver, device)
  device:send(Configuration:Get({ parameter_number = 16 }))
  device:send(Association:Set({
    grouping_identifier = 2,
    node_ids = { driver.environment_info.hub_zwave_id },
  }))

  -- Bootstrap owns the initial BP scan.  A later configure runs a normal
  -- settings refresh without initiating a second lock-code scan.
  if not device:get_field(BOOTSTRAP_REQUIRED) then
    features.refresh_settings(device)
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
    [cc.BATTERY] = { [Battery.REPORT] = battery_report },
    [cc.CONFIGURATION] = { [Configuration.REPORT] = configuration_report },
    [cc.NOTIFICATION] = { [Notification.REPORT] = notification_report },
    [cc.USER_CODE] = { [UserCode.USERS_NUMBER_REPORT] = users_number_report },
  },
  lifecycle_handlers = {
    init = init,
    added = bp_added_handler,
    driverSwitched = driver_switched,
    infoChanged = info_changed,
    doConfigure = do_configure,
  },
}
