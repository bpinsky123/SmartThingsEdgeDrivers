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
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local constants = require "st.zigbee.constants"

local zigbee_smoke_driver_template = {
  supported_capabilities = {
    capabilities.smokeDetector,
    capabilities.battery,
    capabilities.alarm,
    capabilities.temperatureMeasurement
  },
  sub_drivers = {
    require("frient"),
    require("aqara-gas"),
    require("aqara")
  },
  ias_zone_configuration_method = constants.IAS_ZONE_CONFIGURE_TYPE.AUTO_ENROLL_RESPONSE,
  health_check = false,
}

defaults.register_for_default_handlers(zigbee_smoke_driver_template,
  zigbee_smoke_driver_template.supported_capabilities, {native_capability_attrs_enabled = true})
local zigbee_smoke_driver = ZigbeeDriver("zigbee-smoke-detector", zigbee_smoke_driver_template)
zigbee_smoke_driver:run()