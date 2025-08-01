local log = require "log"
local fields = require "fields"
local discovery_mdns = require "discovery_mdns"
local socket = require "cosock.socket"

local discovery = {
  last_try_time = {}
}

function discovery.set_device_field(driver, device)
  local device_cache_value = driver.datastore.discovery_cache[device.device_network_id]

  -- persistent fields
  if device_cache_value ~= nil then
    log.info_with({ hub_logs = true }, string.format("device found in cache. dni= %s", device.device_network_id))
    device:set_field(fields.CREDENTIAL, device_cache_value.credential, { persist = true })
    device:set_field(fields.DEVICE_IPV4, device_cache_value.ip, { persist = true })
    device:set_field(fields.DEVICE_INFO, device_cache_value.device_info, { persist = true })
  else
    log.error_with({ hub_logs = true }, string.format("device not found in cache. dni= %s", device.device_network_id))
  end

  driver.datastore.discovery_cache[device.device_network_id] = nil
end

local function update_device_discovery_cache(driver, dni, ip, device_info)
  if driver.datastore.discovery_cache[dni] == nil then
    driver.datastore.discovery_cache[dni] = {}
  end
  driver.datastore.discovery_cache[dni].ip = ip
  driver.datastore.discovery_cache[dni].device_info = device_info
end

local function try_add_device(driver, device_dni, device_ip)
  log.trace(string.format("try_add_device : dni= %s, ip= %s", device_dni, device_ip))
  local device_info = driver.discovery_helper.get_device_info(driver, device_dni, device_ip)

  update_device_discovery_cache(driver, device_dni, device_ip, device_info)
  local create_device_msg = driver.discovery_helper.get_device_create_msg(driver, device_dni, device_ip, device_info)
  if not create_device_msg then
    log.error_with({ hub_logs = true }, string.format("Failed to get device info. dni= %s, ip= %s", device_dni, device_ip))
    return "device info not found"
  end

  local credential = driver.discovery_helper.get_credential(driver, device_dni, device_ip)

  if not credential then
    if driver.datastore.discovery_cache[device_dni] and driver.datastore.discovery_cache[device_dni].credential then
      log.info(string.format("use stored credential. This may have expired. dni= %s, ip= %s", device_dni, device_ip))
    else
      log.error_with({ hub_logs = true }, string.format("Failed to get credential. The device appears to have already generated a credential. In that case, a device reset is needed to generate a new credential. dni= %s, ip= %s", device_dni, device_ip))
      return "credential not found"
    end
  else
    log.info(string.format("success to get credential. dni= %s, ip= %s", device_dni, device_ip))
    driver.datastore.discovery_cache[device_dni].credential = credential
  end

  log.info_with({ hub_logs = true }, string.format("try_create_device. dni= %s, ip= %s", device_dni, device_ip))

  local success, ret = pcall(driver.try_create_device, driver, create_device_msg)
  if success then
    discovery.last_try_time[device_dni] = os.time()
  else
    log.error_with({ hub_logs = true }, string.format("Failed to try_create_device. dni= %s, %s", device_dni, ret))
  end
  return nil
end

function discovery.device_added(driver, device)
  log.info_with({ hub_logs = true }, string.format("device_added. dni= %s", device.device_network_id))
  discovery.set_device_field(driver, device)
  discovery.last_try_time[device.device_network_id] = nil
  driver.lifecycle_handlers.init(driver, device)
end

function discovery.find_ip_table(driver)
  return discovery_mdns.find_ip_table_by_mdns(driver)
end

local function discovery_device(driver)
  local unknown_discovered_devices = {}
  local known_discovered_devices = {}
  local known_devices = {}

  for _, device in pairs(driver:get_devices()) do
    known_devices[device.device_network_id] = device
  end

  local ip_table = discovery.find_ip_table(driver)

  for dni, ip in pairs(ip_table) do
    if not known_devices[dni] then
      unknown_discovered_devices[dni] = ip
    else
      known_discovered_devices[dni] = ip
    end
  end

  for dni, ip in pairs(known_discovered_devices) do
    log.trace(string.format("known dni= %s, ip= %s", dni, ip))
  end

  for dni, ip in pairs(unknown_discovered_devices) do
    log.trace(string.format("unknown dni= %s, ip= %s", dni, ip))
    local is_already_added = false
    for _, device in pairs(driver:get_devices()) do
      if device.device_network_id == dni then
        is_already_added = true
        break
      end
    end
    if not is_already_added then
      local time_since_last_try = os.time() - (discovery.last_try_time[dni] or 0)
      if (not discovery.last_try_time[dni]) or (time_since_last_try > 10) then
        try_add_device(driver, dni, ip)
      else
        log.trace(string.format("skip adding device because it was tried recently. dni= %s, ip= %s, since %s sec", dni, ip, time_since_last_try))
      end
    end
  end
end

function discovery.do_network_discovery(driver, _, should_continue)
  log.info_with({ hub_logs = true }, string.format("discovery start for Aqara FP2"))
  discovery.last_try_time = {}
  while should_continue() do
    discovery_device(driver)
    socket.sleep(1)
  end
end

return discovery
