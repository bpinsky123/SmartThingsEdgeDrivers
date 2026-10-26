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
local SLGA_MIGRATION_ID = "smoothgreen26756.slgaMigrationToggle"
local CODE_SCAN_STATUS_POLL_SECONDS = 1
local CODE_SCAN_STATUS_POLL_MAX_ATTEMPTS = 90
local PROFILE_READY_RETRY_COUNT = "bp_migrated_profile_ready_retry_count"
local PROFILE_READY_RETRY_SCHEDULED = "bp_migrated_profile_ready_retry_scheduled"
local SETTINGS_STARTED = "bp_migrated_settings_started"
local PROFILE_READY_RETRY_SECONDS = 1
local PROFILE_READY_MAX_RETRIES = 12

local FINGERPRINTS = {
  { mfr = 0x003B, prod = 0x0001, model = 0x0469, profile = "bp-schlage-be469-migrated-v1" },
  { mfr = 0x003B, prod = 0x6341, model = 0x5044, profile = "bp-schlage-be469-migrated-v1" },
  { mfr = 0x003B, prod = 0x0001, model = 0x0468, profile = "bp-schlage-be468-migrated-v1" },
  { mfr = 0x003B, prod = 0x6349, model = 0x5044, profile = "bp-schlage-be468-migrated-v1" },
}

local function matching_fingerprint(device)
  for _, fingerprint in ipairs(FINGERPRINTS) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then
      return fingerprint
    end
  end
end

local function start_settings_when_profile_ready(device)
  if device:get_field(SETTINGS_STARTED) then
    return true
  end

  -- The profile update is asynchronous. The shared settings queue returns
  -- true only after its BP capability set is actually available.
  features.emit_device_network_id(device)
  if features.refresh_settings(device) then
    device:set_field(PROFILE_READY_RETRY_COUNT, nil)
    device:set_field(PROFILE_READY_RETRY_SCHEDULED, nil)
    device:set_field(SETTINGS_STARTED, true)
    return true
  end

  local retries = device:get_field(PROFILE_READY_RETRY_COUNT) or 0
  if retries >= PROFILE_READY_MAX_RETRIES then
    return false
  end

  if not device:get_field(PROFILE_READY_RETRY_SCHEDULED) then
    device:set_field(PROFILE_READY_RETRY_SCHEDULED, true)
    device:set_field(PROFILE_READY_RETRY_COUNT, retries + 1)
    device.thread:call_with_delay(PROFILE_READY_RETRY_SECONDS, function()
      device:set_field(PROFILE_READY_RETRY_SCHEDULED, nil)
      start_settings_when_profile_ready(device)
    end)
  end

  return false
end

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

local function watch_code_scan_status(device, attempt)
  attempt = attempt or 0

  if device:get_field(constants.DRIVER_STATE.COMMAND_IN_PROGRESS) ~= constants.SYNC.CODES_FROM_LOCK then
    features.emit_driver_status(device, "Ready")
    return
  end

  if attempt >= CODE_SCAN_STATUS_POLL_MAX_ATTEMPTS then
    features.emit_driver_status(device, "Code refresh incomplete")
    return
  end

  device.thread:call_with_delay(CODE_SCAN_STATUS_POLL_SECONDS, function()
    watch_code_scan_status(device, attempt + 1)
  end)
end

local function refresh_handler(driver, device, command)
  if command.component ~= nil and command.component ~= "main" then return end

  -- Preserve the immediate main-card refresh, then avoid competing with the
  -- response-paced settings queue before reading migrated credentials.
  stock_capability_handlers.refresh(driver, device, command)
  features.refresh_settings(device, function(refreshed_device)
    if refreshed_device.preferences.refreshCodes then
      features.emit_driver_status(refreshed_device, "Retrieving lock codes")
      lock_utils.sync_device_state(refreshed_device)
      watch_code_scan_status(refreshed_device)
    end
  end)
end

local function init(_, device)
  if device:supports_capability_by_id(SLGA_MIGRATION_ID, "main") then
    device:emit_event(capabilities[SLGA_MIGRATION_ID].status(
      "migrated", { visibility = { displayed = false } }
    ))
  end
  device:set_field(SETTINGS_STARTED, nil)
  device:set_field(PROFILE_READY_RETRY_COUNT, nil)
  device:set_field(PROFILE_READY_RETRY_SCHEDULED, nil)

  local fingerprint = matching_fingerprint(device)
  if fingerprint and device.profile.name ~= fingerprint.profile then
    device:try_update_metadata({ profile = fingerprint.profile })
  end

  start_settings_when_profile_ready(device)
end

local function info_changed(driver, device, event, args)
  call_parent_handler(driver.lifecycle_handlers.infoChanged, driver, device, event, args)
  start_settings_when_profile_ready(device)
end

local function do_configure(driver, device)
  device:send(Association:Set({
    grouping_identifier = 1,
    node_ids = { driver.environment_info.hub_zwave_id },
  }))
  device:send(Configuration:Get({
    parameter_number = SCHLAGE_LOCK_CODE_LENGTH_PARAM.number,
  }))
  start_settings_when_profile_ready(device)
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
    infoChanged = info_changed,
    doConfigure = do_configure,
  },
}
