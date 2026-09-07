local capabilities = require "st.capabilities"
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version = 2 })
local Notification = (require "st.zwave.CommandClass.Notification")({ version = 3 })
local log = require "log"
local M = {}

M.capabilities = {
  alarm = capabilities["heartsample19211.schlageLockAlarm"],
  auto_lock = capabilities["heartsample19211.autoLock"],
  lock_and_leave = capabilities["heartsample19211.lockAndLeave"],
  vacation_mode = capabilities["heartsample19211.vacationMode"],
  keypad_beep = capabilities["heartsample19211.keypadBeep"],
  interior_button = capabilities["heartsample19211.interiorSchlageButton"],
  activity = capabilities["heartsample19211.lockActivity"],
  device_network_id = capabilities["heartsample19211.deviceNetworkId"],
}

local params = {
  [3] = { cap = M.capabilities.keypad_beep, attr = "keypadBeep", map = {[0] = "off", [-1] = "beep"} },
  [4] = { cap = M.capabilities.vacation_mode, attr = "vacationMode", map = {[0] = "off", [-1] = "vacation"} },
  [5] = { cap = M.capabilities.lock_and_leave, attr = "lockAndLeave", map = {[0] = "off", [-1] = "lockandleave"} },
  [7] = { cap = M.capabilities.alarm, attr = "alarmMode", map = {[0] = "off", [1] = "activity", [2] = "tamper", [3] = "forcedentry"} },
  [8] = { cap = M.capabilities.alarm, attr = "activitySensitivity", map = {[1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5} },
  [9] = { cap = M.capabilities.alarm, attr = "tamperSensitivity", map = {[1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5} },
  [10] = { cap = M.capabilities.alarm, attr = "forcedEntrySensitivity", map = {[1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 5} },
  [11] = { cap = M.capabilities.interior_button, attr = "interiorButton", map = {[0] = "disable", [-1] = "enable"} },
  [15] = { cap = M.capabilities.auto_lock, attr = "autoLock", map = {[0] = "off", [-1] = "autolock"} },
}

local function setting_component(device)
  local components = device.profile.components
  if components.settings then return components.settings end
  for _, component in ipairs(components) do
    if component.id == "settings" then return component end
  end
end

function M.emit_device_network_id(device)
  local component = setting_component(device)
  local cap = M.capabilities.device_network_id
  if component and device:supports_capability_by_id(cap.ID, component.id) then
    device:emit_component_event(component, cap.deviceNetworkId(tostring(device.device_network_id)))
  end
end

function M.configuration_report(device, cmd)
  local setting = params[cmd.args.parameter_number]
  local value = setting and setting.map[cmd.args.configuration_value]
  local component = setting and setting_component(device)
  if value ~= nil and component and device:supports_capability_by_id(setting.cap.ID, component.id) then
    device:emit_component_event(component, setting.cap[setting.attr](value))
  end
end

function M.refresh_settings(device)
  for parameter, setting in pairs(params) do
    local component = setting_component(device)
    if component and device:supports_capability_by_id(setting.cap.ID, component.id) then
      device:send(Configuration:Get({ parameter_number = parameter }))
    end
  end
end

local command_params = {
  ["heartsample19211.schlageLockAlarm"] = {
    off = { parameter = 7, value = 0 },
    activity = { parameter = 7, value = 1 },
    tamper = { parameter = 7, value = 2 },
    forcedentry = { parameter = 7, value = 3 },
    setAlarmMode = { parameter = 7, argument = "mode", values = {off = 0, activity = 1, tamper = 2, forcedentry = 3} },
    setActivitySensitivity = { parameter = 8, argument = "sensitivity" },
    setTamperSensitivity = { parameter = 9, argument = "sensitivity" },
    setForcedSensitivity = { parameter = 10, argument = "sensitivity" },
  },
  ["heartsample19211.autoLock"] = { autolock = { parameter = 15, value = -1 }, off = { parameter = 15, value = 0 }, setAutoLock = { parameter = 15, argument = "mode", values = {autolock = -1, off = 0} } },
  ["heartsample19211.lockAndLeave"] = { lockandleave = { parameter = 5, value = -1 }, off = { parameter = 5, value = 0 }, setLockAndLeave = { parameter = 5, argument = "mode", values = {lockandleave = -1, off = 0} } },
  ["heartsample19211.vacationMode"] = { vacation = { parameter = 4, value = -1 }, off = { parameter = 4, value = 0 }, setVacationMode = { parameter = 4, argument = "mode", values = {vacation = -1, off = 0} } },
  ["heartsample19211.keypadBeep"] = { beep = { parameter = 3, value = -1 }, off = { parameter = 3, value = 0 }, setKeypadBeep = { parameter = 3, argument = "mode", values = {beep = -1, off = 0} } },
  ["heartsample19211.interiorSchlageButton"] = { enable = { parameter = 11, value = -1 }, disable = { parameter = 11, value = 0 }, setInteriorButton = { parameter = 11, argument = "mode", values = {enable = -1, disable = 0} } },
}

M.command_params = command_params

function M.setting_command(_, device, cmd)
  local spec = command_params[cmd.capability] and command_params[cmd.capability][cmd.command]
  if not spec then
    log.warn(string.format("No Schlage setting mapping for %s.%s", cmd.capability, cmd.command))
    return
  end
  local value = spec.value or (spec.values and spec.values[cmd.args[spec.argument]]) or cmd.args[spec.argument]
  log.info(string.format("Setting Schlage configuration parameter %d to %s", spec.parameter, tostring(value)))
  device:send(Configuration:Set({ parameter_number = spec.parameter, configuration_value = value, size = 1 }))
end

function M.emit_activity(device, activity, message, user_name, user_index)
  local cap = M.capabilities.activity
  if not device:supports_capability(cap) then return end
  device:emit_event(cap.activity(activity))
  device:emit_event(cap.message(message))
  device:emit_event(cap.userName(user_name or ""))
  device:emit_event(cap.userIndex(user_index or 0))
end

function M.activity_from_notification(device, cmd, user_lookup)
  if cmd.args.notification_type ~= Notification.notification_type.ACCESS_CONTROL then return end
  local event = cmd.args.event
  local access = Notification.event.access_control
  local activity_map = {
    [access.KEYPAD_LOCK_OPERATION] = { "keypadLocked", "Locked with keypad" },
    [access.KEYPAD_UNLOCK_OPERATION] = { "keypadUnlocked", "Unlocked with keypad" },
    [access.MANUAL_LOCK_OPERATION] = { "manualLocked", "Locked manually" },
    [access.MANUAL_UNLOCK_OPERATION] = { "manualUnlocked", "Unlocked manually" },
    [access.RF_LOCK_OPERATION] = { "remoteLocked", "Locked remotely" },
    [access.RF_UNLOCK_OPERATION] = { "remoteUnlocked", "Unlocked remotely" },
    [access.AUTO_LOCK_LOCKED_OPERATION] = { "autoLocked", "Auto-locked" },
    [access.LOCK_JAMMED] = { "lockJammed", "Lock jammed" },
  }
  local detail = activity_map[event]
  if not detail then return end
  if event == access.KEYPAD_LOCK_OPERATION or event == access.KEYPAD_UNLOCK_OPERATION then
    local parameter = cmd.args.event_parameter
    local code_id = cmd.args.v1_alarm_level
    if parameter and #parameter > 0 then
      local bytes = {parameter:byte(1, -1)}
      code_id = #bytes == 1 and bytes[1] or bytes[3]
    end
    local user_name, user_index = user_lookup(tonumber(code_id))
    if user_name and user_name ~= "" then detail[2] = detail[2] .. " by " .. user_name end
    M.emit_activity(device, detail[1], detail[2], user_name, user_index or tonumber(code_id))
  else
    M.emit_activity(device, detail[1], detail[2])
  end
end

return M
