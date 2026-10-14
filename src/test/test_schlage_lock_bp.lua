-- Copyright 2026 SmartThings, Inc.
-- Licensed under the Apache License, Version 2.0

local test = require "integration_test"
local capabilities = require "st.capabilities"
local json = require "dkjson"
local t_utils = require "integration_test.utils"

local mock_device = test.mock_device.build_test_zwave_device({
  profile = t_utils.get_profile_definition("schlage-be469.yml"),
  zwave_endpoints = {
    {
      command_classes = {
        { value = 0x62 }, -- Door Lock
        { value = 0x63 }, -- User Code
        { value = 0x71 }, -- Notification
      },
    },
  },
  zwave_manufacturer_id = 0x003B,
  zwave_product_type = 0x0001,
  zwave_product_id = 0x0469,
})

test.set_test_init_function(function()
  test.mock_device.add_test_device(mock_device)
  mock_device:expect_metadata_update({ profile = "bp-schlage-be469" })
end)

test.register_message_test(
  "BP nameSlot rebuilds the local label map without writing a PIN",
  {
    {
      channel = "capability",
      direction = "receive",
      message = {
        mock_device.id,
        {
          capability = capabilities.lockCodes.ID,
          command = capabilities.lockCodes.commands.nameSlot.NAME,
          args = { 1, "Front Door PIN" },
        },
      },
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message(
        "main",
        capabilities.lockCodes.lockCodes(
          json.encode({ ["1"] = "Front Door PIN" }),
          { visibility = { displayed = false } }
        )
      ),
    },
    {
      channel = "capability",
      direction = "send",
      message = mock_device:generate_test_message(
        "main",
        capabilities.lockCodes.codeChanged("1 renamed", { state_change = true })
      ),
    },
  },
  {
    min_api_version = 14,
  }
)

test.run_registered_tests()
