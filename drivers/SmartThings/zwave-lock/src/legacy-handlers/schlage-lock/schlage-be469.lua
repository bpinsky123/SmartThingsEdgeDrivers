local cc = require "st.zwave.CommandClass"
local Configuration = (require "st.zwave.CommandClass.Configuration")({ version = 2 })
local schlage_features = require "schlage-lock.features"

local fingerprints = {
  { mfr = 0x003B, prod = 0x0001, model = 0x0469 },
  { mfr = 0x003B, prod = 0x6341, model = 0x5044 },
  { mfr = 0x003B, prod = 0x0001, model = 0x0468 },
  { mfr = 0x003B, prod = 0x6349, model = 0x5044 },
}

local function can_handle(_, _, device)
  for _, fingerprint in ipairs(fingerprints) do
    if device:id_match(fingerprint.mfr, fingerprint.prod, fingerprint.model) then return true end
  end
  return false
end

local function configuration_report(_, device, cmd)
  schlage_features.configuration_report(device, cmd)
end

local function refresh_settings(_, device)
  schlage_features.emit_device_network_id(device)
  schlage_features.refresh_settings(device)
end

local setting = schlage_features.setting_command
local caps = schlage_features.capabilities

return {
  NAME = "Schlage BE469",
  can_handle = can_handle,
  capability_handlers = {
    [caps.alarm.ID] = { off = setting, activity = setting, tamper = setting, forcedentry = setting, setAlarmMode = setting, setActivitySensitivity = setting, setTamperSensitivity = setting, setForcedSensitivity = setting },
    [caps.auto_lock.ID] = { autolock = setting, off = setting, setAutoLock = setting },
    [caps.lock_and_leave.ID] = { lockandleave = setting, off = setting, setLockAndLeave = setting },
    [caps.vacation_mode.ID] = { vacation = setting, off = setting, setVacationMode = setting },
    [caps.keypad_beep.ID] = { beep = setting, off = setting, setKeypadBeep = setting },
    [caps.interior_button.ID] = { enable = setting, disable = setting, setInteriorButton = setting },
  },
  zwave_handlers = {
    [cc.CONFIGURATION] = { [Configuration.REPORT] = configuration_report },
  },
  lifecycle_handlers = {
    added = refresh_settings,
    doConfigure = refresh_settings,
  },
}