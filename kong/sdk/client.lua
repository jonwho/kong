local checks = require("kong.sdk.private.checks")

local ngx = ngx
local tonumber = tonumber
local check_phase = checks.check_phase
local ALL_PHASES = checks.phases.ALL_PHASES


local function new(self)
  local _CLIENT = {}


  function _CLIENT.get_ip()
    check_phase(ALL_PHASES)

    return ngx.var.realip_remote_addr or ngx.var.remote_addr
  end


  function _CLIENT.get_forwarded_ip()
    check_phase(ALL_PHASES)

    return ngx.var.remote_addr
  end


  function _CLIENT.get_port()
    check_phase(ALL_PHASES)

    return tonumber(ngx.var.realip_remote_port or ngx.var.remote_port)
  end


  function _CLIENT.get_forwarded_port()
    check_phase(ALL_PHASES)

    return tonumber(ngx.var.remote_port)
  end


  return _CLIENT
end


return {
  new = new,
}
