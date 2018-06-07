local bit = require("bit")


local checks = {}


local tostring = tostring
local ipairs = ipairs
local lshift = bit.lshift
local pairs = pairs
local error = error
local tobit = bit.tobit
local band = bit.band
local type = type
local fmt = string.format
local ngx = ngx


checks.phases = {
  INIT_WORKER      = tobit(0x00000001),
  SSL_CERTIFICATE  = tobit(0x00000002),
  REWRITE          = tobit(0x00000004),
  ACCESS           = tobit(0x00000008),
  HEADER_FILTER    = tobit(0x00000010),
  BODY_FILTER      = tobit(0x00000020),
  LOG              = tobit(0x00000040),
  ALL_PHASES       = tobit(0xffffffff),
}


for k,v in pairs(checks.phases) do
  checks.phases[v] = k
end


local function accepted_phases(accepted)
  local names = {}
  local n = 1
  for _ = 1, 32 do
    if band(accepted, n) ~= 0 then
      table.insert(names, checks.phases[n]:lower())
    end
    n = lshift(n, 1)
  end
  if #accepted == 1 then
    return fmt("the %s phase", accepted[1])
  else
    return "the following phases: " .. table.concat(accepted, ", ")
  end
end


function checks.check_phase(accepted)
  local phase = ngx.ctx.kong_phase
  if band(phase, accepted) ~= 0 then
    return true
  end

  error(fmt("function cannot be called in %s phase, only in %s",
            checks.phases[phase]:lower(), accepted_phases(accepted), 3))
end


function checks.normalize_multi_header(value)
  local tvalue = type(value)

  if tvalue == "string" then
    return value == "" and " " or value
  end

  if tvalue == "table" then
    local new_value = {}
    for i, v in ipairs(value) do
      new_value[i] = v == "" and " " or v
    end
    return new_value
  end

  -- header is number or boolean
  return tostring(value)
end


function checks.normalize_header(value)
  local tvalue = type(value)

  if tvalue == "string" then
    return value == "" and " " or value
  end

  -- header is number or boolean
  return tostring(value)
end


function checks.validate_header(name, value)
  local tname = type(name)
  if tname ~= "string" then
    error(fmt("invalid header name %q: got %s, " ..
                        "expected string", name, tname), 3)
  end

  local tvalue = type(value)
  if tvalue ~= "string" then
    if tvalue == "number" or tvalue == "boolean" then
      value = tostring(value)
    else
      error(fmt("invalid header value for %q: got %s, expected " ..
                          "string, number or boolean", name, tvalue), 3)
    end
  end
  return value
end


function checks.validate_headers(headers)
  if type(headers) ~= "table" then
    error("headers must be a table", 3)
  end

  for k, v in pairs(headers) do
    local tk = type(k)
    if tk ~= "string" then
      error(fmt("invalid header name %q: got %s, " ..
                          "expected string", k, tk), 3)
    end

    local tv = type(v)

    if tv ~= "string" then
      if tv == "table" then

        for _, vv in ipairs(v) do
          local tvv = type(vv)
          if tvv ~= "string" then
            error(fmt("invalid header value in array %q: got %s, " ..
                                "expected string", k, tvv), 3)
          end
        end

      elseif tv ~= "number" and tv ~= "boolean" then

        error(fmt("invalid header value for %q: got %s, " ..
                            "expected string, number, boolean or " ..
                            "array of strings", k, tv), 3)
      end
    end
  end
end


return checks
