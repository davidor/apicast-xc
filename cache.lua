local redis_pool = require 'redis_pool'

local _M = { }

local function get_auth_hash_key(service_id, app_id)
  return 'auth:'..service_id..':'..app_id
end

local function get_report_hash_key(service_id, app_id)
  return 'report:'..service_id..':'..app_id
end

local SET_REPORT_KEYS = 'report_keys'

-- Returns true when executed correctly. False otherwise.
local function report_and_update_reported_set(service_id, app_id, usage_method, usage_val, redis)
  -- Use redis multi to ensure that the 2 commands are executed atomically so
  -- noone can observe an inconsistent state between their execution.

  local res_multi, _ = redis:multi()
  if not res_multi then
    return false
  end

  local report_hash_key = get_report_hash_key(service_id, app_id)
  local res_hincrby, _ = redis:hincrby(report_hash_key, usage_method, usage_val)
  if not res_hincrby then
    redis:discard()
    return false
  end

  local res_sadd, _ = redis:sadd(SET_REPORT_KEYS, report_hash_key)
  if not res_sadd then
    redis:discard()
    return false
  end

  local res_exec, _ = redis:exec()
  return res_exec
end

function _M.authorize(service_id, app_id, usage_method)
  local redis, ok = redis_pool.acquire()

  if not ok then
    return nil, false
  end

  local auth_hash_key = get_auth_hash_key(service_id, app_id)
  local cached_auth, _ = redis:hget(auth_hash_key, usage_method)

  redis_pool.release(redis)

  -- note: cached_auth == nil indicates that an error happened, whereas
  -- cached_auth == ngx.null indicates that the key does not exist.
  if cached_auth == nil then
    return nil, false
  end

  local auth
  if cached_auth == '0' then
    auth = false
  elseif cached_auth == '1' then
    auth = true
  end

  return auth, true
end

-- Returns true if the report succeeds, false otherwise.
function _M.report(service_id, app_id, usage_method, usage_val)
  local redis, ok = redis_pool.acquire()
  if not ok then
    return false
  end

  local res_report = report_and_update_reported_set(
    service_id, app_id, usage_method, usage_val, redis)

  redis_pool.release(redis)

  return res_report
end

return _M
