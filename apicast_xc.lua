local xc = require 'xc/xc'
local utils = require 'xc/utils'

local _M = require 'apicast'

function _M.access()
  local request = ngx.var.request
  local service = ngx.ctx.service

  local credentials = service:extract_credentials(request)
  local parsed_creds = utils.parse_apicast_creds(credentials)

  local usage = service:extract_usage(request)
  local auth_status = xc.authrep(tostring(service.id), parsed_creds, usage)

  if auth_status.auth ~= xc.auth.ok then
    ngx.exit(403)
  end

  -- ngx.var.secret_token is set in the access() method of the APIcast default
  -- module. That means that if we do not set it here, it will never be set.
  -- Hopefully, in the future, APIcast will set the secret token in a way
  -- so that 3rd party modules do not need have to.
  ngx.var.secret_token = service.secret_token

  -- TODO: For now, exiting with 403 is good enough. However, in auth_status we
  -- have some information that can help us to have a more sophisticated error
  -- handling. if the authorization is not ok, it could be denied or unkown
  -- (meaning that there was an error accessing the cache). We could treat
  -- those cases differently.
end

-- Override methods implemented in APIcast that are not needed in XC
_M.header_filter = function() end
_M.body_filter = function() end
_M.post_action = function() end

return _M
