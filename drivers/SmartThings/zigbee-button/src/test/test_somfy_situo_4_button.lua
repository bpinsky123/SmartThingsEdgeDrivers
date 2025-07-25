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

-- Mock out globals
local capabilities = require "st.capabilities"
local clusters = require "st.zigbee.zcl.clusters"
local mgmt_bind_response = require "st.zigbee.zdo.mgmt_bind_response"
local t_utils = require "integration_test.utils"
local test = require "integration_test"
local zigbee_test_utils = require "integration_test.zigbee_test_utils"

local PowerConfiguration = clusters.PowerConfiguration
local WindowCovering = clusters.WindowCovering

local button_attr = capabilities.button.button

local mock_device = test.mock_device.build_test_zigbee_device(
    {
      profile = t_utils.get_profile_definition("twelve-buttons.yml"),
      zigbee_endpoints = {
        [1] = {
          id = 1,
          manufacturer = "SOMFY",
          model = "Situo 4 Zigbee",
          server_clusters = {0x0019}
        }
      }
    }
)

zigbee_test_utils.prepare_zigbee_env_info()
local function test_init()
  test.mock_device.add_test_device(mock_device)end

test.set_test_init_function(test_init)
test.register_coroutine_test(
    "Configure should configure all necessary attributes",
    function()

      test.socket.device_lifecycle:__queue_receive({ mock_device.id, "doConfigure" })
      test.socket.zigbee:__set_channel_ordering("relaxed")
      test.socket.zigbee:__expect_send(
        {
          mock_device.id,
          PowerConfiguration.attributes.BatteryPercentageRemaining:read(mock_device):to_endpoint(0xE8)
        }
      )
      test.socket.zigbee:__expect_send(
        {
          mock_device.id,
          PowerConfiguration.attributes.BatteryPercentageRemaining:configure_reporting(mock_device, 30, 21600, 1):to_endpoint(0xE8)
        }
      )
      test.socket.zigbee:__expect_send(
        {
          mock_device.id,
          zigbee_test_utils.build_bind_request(mock_device,
                                               zigbee_test_utils.mock_hub_eui,
                                               WindowCovering.ID, 1)
        }
      )
      test.socket.zigbee:__expect_send(
        {
          mock_device.id,
          zigbee_test_utils.build_bind_request(mock_device,
                                               zigbee_test_utils.mock_hub_eui,
                                               WindowCovering.ID, 2)
        }
      )
      test.socket.zigbee:__expect_send(
        {
          mock_device.id,
          zigbee_test_utils.build_bind_request(mock_device,
                                               zigbee_test_utils.mock_hub_eui,
                                               WindowCovering.ID, 3)
        }
      )
      test.socket.zigbee:__expect_send(
        {
          mock_device.id,
          zigbee_test_utils.build_bind_request(mock_device,
                                               zigbee_test_utils.mock_hub_eui,
                                               WindowCovering.ID, 4)
        }
      )

      test.socket.zigbee:__expect_send(
        {
          mock_device.id,
          zigbee_test_utils.build_mgmt_bind_request(mock_device,
                                                    zigbee_test_utils.mock_hub_eui)
        }
      )
      mock_device:expect_metadata_update({ provisioning_state = "PROVISIONED" })
    end
)

test.register_coroutine_test(
    "Test cases for 12 Buttons",
    function()

      test.socket.zigbee:__queue_receive({ mock_device.id, zigbee_test_utils.build_custom_command_id(mock_device, WindowCovering.ID, WindowCovering.server.commands.UpOrOpen.ID, 0x0000, "\x00", 0x01) })
      test.socket.capability:__expect_send(
          mock_device:generate_test_message("button1", (button_attr.pushed({ state_change = true })))
      )

      test.socket.zigbee:__queue_receive({ mock_device.id, zigbee_test_utils.build_custom_command_id(mock_device, WindowCovering.ID, WindowCovering.server.commands.UpOrOpen.ID, 0x0000, "\x00", 0x02) })
      test.socket.capability:__expect_send(
          mock_device:generate_test_message("button4", (button_attr.pushed({ state_change = true })))
      )

      test.socket.zigbee:__queue_receive({ mock_device.id, zigbee_test_utils.build_custom_command_id(mock_device, WindowCovering.ID, WindowCovering.server.commands.UpOrOpen.ID, 0x0000, "\x00", 0x03) })
      test.socket.capability:__expect_send(
          mock_device:generate_test_message("button7", (button_attr.pushed({ state_change = true })))
      )

      test.socket.zigbee:__queue_receive({ mock_device.id, zigbee_test_utils.build_custom_command_id(mock_device, WindowCovering.ID, WindowCovering.server.commands.UpOrOpen.ID, 0x0000, "\x00", 0x04) })
      test.socket.capability:__expect_send(
          mock_device:generate_test_message("button10", (button_attr.pushed({ state_change = true })))
      )

      test.socket.zigbee:__queue_receive({ mock_device.id, zigbee_test_utils.build_custom_command_id(mock_device, WindowCovering.ID, WindowCovering.server.commands.DownOrClose.ID, 0x0000, "\x00", 0x01) })
      test.socket.capability:__expect_send(
          mock_device:generate_test_message("button3", (button_attr.pushed({ state_change = true })))
      )

      test.socket.zigbee:__queue_receive({ mock_device.id, zigbee_test_utils.build_custom_command_id(mock_device, WindowCovering.ID, WindowCovering.server.commands.DownOrClose.ID, 0x0000, "\x00", 0x02) })
      test.socket.capability:__expect_send(
          mock_device:generate_test_message("button6", (button_attr.pushed({ state_change = true })))
      )

      test.socket.zigbee:__queue_receive({ mock_device.id, zigbee_test_utils.build_custom_command_id(mock_device, WindowCovering.ID, WindowCovering.server.commands.DownOrClose.ID, 0x0000, "\x00", 0x03) })
      test.socket.capability:__expect_send(
          mock_device:generate_test_message("button9", (button_attr.pushed({ state_change = true })))
      )

      test.socket.zigbee:__queue_receive({ mock_device.id, zigbee_test_utils.build_custom_command_id(mock_device, WindowCovering.ID, WindowCovering.server.commands.DownOrClose.ID, 0x0000, "\x00", 0x04) })
      test.socket.capability:__expect_send(
          mock_device:generate_test_message("button12", (button_attr.pushed({ state_change = true })))
      )

      test.socket.zigbee:__queue_receive({ mock_device.id, zigbee_test_utils.build_custom_command_id(mock_device, WindowCovering.ID, WindowCovering.server.commands.Stop.ID, 0x0000, "\x00", 0x01) })
      test.socket.capability:__expect_send(
          mock_device:generate_test_message("button2", (button_attr.pushed({ state_change = true })))
      )

      test.socket.zigbee:__queue_receive({ mock_device.id, zigbee_test_utils.build_custom_command_id(mock_device, WindowCovering.ID, WindowCovering.server.commands.Stop.ID, 0x0000, "\x00", 0x02) })
      test.socket.capability:__expect_send(
          mock_device:generate_test_message("button5", (button_attr.pushed({ state_change = true })))
      )

      test.socket.zigbee:__queue_receive({ mock_device.id, zigbee_test_utils.build_custom_command_id(mock_device, WindowCovering.ID, WindowCovering.server.commands.Stop.ID, 0x0000, "\x00", 0x03) })
      test.socket.capability:__expect_send(
          mock_device:generate_test_message("button8", (button_attr.pushed({ state_change = true })))
      )

      test.socket.zigbee:__queue_receive({ mock_device.id, zigbee_test_utils.build_custom_command_id(mock_device, WindowCovering.ID, WindowCovering.server.commands.Stop.ID, 0x0000, "\x00", 0x04) })
      test.socket.capability:__expect_send(
          mock_device:generate_test_message("button11", (button_attr.pushed({ state_change = true })))
      )
    end
)

test.register_coroutine_test(
    "ZDO Message handler and adding hub to group",
    function()
      local binding_table = mgmt_bind_response.BindingTableListRecord("\x6A\x9D\xC0\xFE\xFF\x5E\xCF\xD0", 0x01, 0x0006, 0x01, 0xB9F2)
      local response = mgmt_bind_response.MgmtBindResponse({
        status = 0x00,
        total_binding_table_entry_count = 0x01,
        start_index = 0x00,
        binding_table_list_count = 0x01,
        binding_table_entries = { binding_table }
      })
      test.socket.zigbee:__queue_receive(
        {
          mock_device.id,
          zigbee_test_utils.build_zdo_mgmt_bind_response(mock_device, response)
        }
      )
      test.socket.zigbee:__expect_add_hub_to_group(0xB9F2)
    end
)

test.register_coroutine_test(
  "added lifecycle event",
  function()
    test.socket.capability:__set_channel_ordering("relaxed")
    test.socket.capability:__expect_send(
      mock_device:generate_test_message(
        "main",
        capabilities.button.supportedButtonValues({ "pushed" }, { visibility = { displayed = false } })
      )
    )
    test.socket.capability:__expect_send(
      mock_device:generate_test_message(
        "main",
        capabilities.button.numberOfButtons({ value = 12 }, { visibility = { displayed = false } })
      )
    )
    for button_name, _ in pairs(mock_device.profile.components) do
      if button_name ~= "main" then
        test.socket.capability:__expect_send(
          mock_device:generate_test_message(
            button_name,
            capabilities.button.supportedButtonValues({ "pushed" }, { visibility = { displayed = false } })
          )
        )
        test.socket.capability:__expect_send(
          mock_device:generate_test_message(
            button_name,
            capabilities.button.numberOfButtons({ value = 1 }, { visibility = { displayed = false } })
          )
        )
      end
    end
    test.socket.capability:__expect_send({
      mock_device.id,
      {
        capability_id = "button", component_id = "main",
        attribute_id = "button", state = { value = "pushed" }
      }
    })

    test.socket.device_lifecycle:__queue_receive({ mock_device.id, "added" })
    test.wait_for_events()
    end
)


test.run_registered_tests()
