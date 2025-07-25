-- Copyright 2022 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local capabilities = require "st.capabilities"
--- @type st.zwave.CommandClass
local cc = require "st.zwave.CommandClass"
--- @type st.zwave.Driver
local ZwaveDriver = require "st.zwave.driver"
--- @type st.zwave.defaults
local defaults = require "st.zwave.defaults"
--- @type st.zwave.CommandClass.Basic
local Basic = (require "st.zwave.CommandClass.Basic")({ version=1 })
--- @type st.zwave.CommandClass.WakeUp
local WakeUp = (require "st.zwave.CommandClass.WakeUp")({ version = 1 })

local preferences = require "preferences"
local configurations = require "configurations"

local function lazy_load_if_possible(sub_driver_name)
  -- gets the current lua libs api version
  local version = require "version"

  -- version 9 will include the lazy loading functions
  if version.api >= 9 then
    return ZwaveDriver.lazy_load_sub_driver(require(sub_driver_name))
  else
    return require(sub_driver_name)
  end

end

--- Handle preference changes
---
--- @param driver st.zwave.Driver
--- @param device st.zwave.Device
--- @param event table
--- @param args
local function info_changed(self, device, event, args)
  if not device:is_cc_supported(cc.WAKE_UP) then
    preferences.update_preferences(self, device, args)
  end
end

local function device_init(self, device)
  device:set_update_preferences_fn(preferences.update_preferences)
end

--- These are non-standard uses of the basic set command, but some devices (mainly aeotec)
--- do use them, so we're including these here but not in the defaults.
local function basic_set_handler(driver, device, cmd)
  if device:supports_capability_by_id(capabilities.contactSensor.ID) then
    if cmd.args.value > 0 then
      device:emit_event_for_endpoint(cmd.src_channel, capabilities.contactSensor.contact.open())
    else
      device:emit_event_for_endpoint(cmd.src_channel, capabilities.contactSensor.contact.closed())
    end
  elseif device:supports_capability_by_id(capabilities.motionSensor.ID) then
    if cmd.args.value > 0 then
      device:emit_event_for_endpoint(cmd.src_channel, capabilities.motionSensor.motion.active())
    else
      device:emit_event_for_endpoint(cmd.src_channel, capabilities.motionSensor.motion.inactive())
    end
  end
end

local function wakeup_notification(driver, device, cmd)
  --Note sending WakeUpIntervalGet the first time a device wakes up will happen by default in Lua libs 0.49.x and higher
  --This is done to help the hub correctly set the checkInterval for migrated devices.
  if not device:get_field("__wakeup_interval_get_sent") then
    device:send(WakeUp:IntervalGetV1({}))
    device:set_field("__wakeup_interval_get_sent", true)
  end
  device:refresh()
end

local function do_configure(driver, device)
  configurations.initial_configuration(driver, device)
  device:refresh()
  if not device:is_cc_supported(cc.WAKE_UP) then
    preferences.update_preferences(driver, device)
  end
end

local initial_events_map = {
  [capabilities.tamperAlert.ID] = capabilities.tamperAlert.tamper.clear(),
  [capabilities.waterSensor.ID] = capabilities.waterSensor.water.dry(),
  [capabilities.moldHealthConcern.ID] = capabilities.moldHealthConcern.moldHealthConcern.good(),
  [capabilities.contactSensor.ID] = capabilities.contactSensor.contact.closed(),
  [capabilities.smokeDetector.ID] = capabilities.smokeDetector.smoke.clear(),
  [capabilities.motionSensor.ID] = capabilities.motionSensor.motion.inactive()
}

local function added_handler(self, device)
  for id, event in pairs(initial_events_map) do
    if device:supports_capability_by_id(id) then
      device:emit_event(event)
    end
  end
end

local driver_template = {
  supported_capabilities = {
    capabilities.waterSensor,
    capabilities.colorControl,
    capabilities.contactSensor,
    capabilities.motionSensor,
    capabilities.relativeHumidityMeasurement,
    capabilities.illuminanceMeasurement,
    capabilities.battery,
    capabilities.tamperAlert,
    capabilities.temperatureAlarm,
    capabilities.temperatureMeasurement,
    capabilities.switch,
    capabilities.moldHealthConcern,
    capabilities.dewPoint,
    capabilities.ultravioletIndex,
    capabilities.accelerationSensor,
    capabilities.atmosphericPressureMeasurement,
    capabilities.threeAxis,
    capabilities.bodyWeightMeasurement,
    capabilities.voltageMeasurement,
    capabilities.energyMeter,
    capabilities.powerMeter,
    capabilities.smokeDetector
  },
  sub_drivers = {
    lazy_load_if_possible("zooz-4-in-1-sensor"),
    lazy_load_if_possible("vision-motion-detector"),
    lazy_load_if_possible("fibaro-flood-sensor"),
    lazy_load_if_possible("aeotec-water-sensor"),
    lazy_load_if_possible("glentronics-water-leak-sensor"),
    lazy_load_if_possible("homeseer-multi-sensor"),
    lazy_load_if_possible("fibaro-door-window-sensor"),
    lazy_load_if_possible("sensative-strip"),
    lazy_load_if_possible("enerwave-motion-sensor"),
    lazy_load_if_possible("aeotec-multisensor"),
    lazy_load_if_possible("zwave-water-leak-sensor"),
    lazy_load_if_possible("everspring-motion-light-sensor"),
    lazy_load_if_possible("ezmultipli-multipurpose-sensor"),
    lazy_load_if_possible("fibaro-motion-sensor"),
    lazy_load_if_possible("v1-contact-event"),
    lazy_load_if_possible("timed-tamper-clear"),
    lazy_load_if_possible("wakeup-no-poll"),
    lazy_load_if_possible("apiv6_bugfix")
  },
  lifecycle_handlers = {
    added = added_handler,
    init = device_init,
    infoChanged = info_changed,
    doConfigure = do_configure
  },
  zwave_handlers = {
    [cc.BASIC] = {
      [Basic.SET] = basic_set_handler
    },
    [cc.WAKE_UP] = {
      [WakeUp.NOTIFICATION] = wakeup_notification
    }
  },
}

defaults.register_for_default_handlers(driver_template, driver_template.supported_capabilities)
--- @type st.zwave.Driver
local sensor = ZwaveDriver("zwave_sensor", driver_template)
sensor:run()
