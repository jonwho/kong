package t::Util;

use strict;
use warnings;
use Cwd qw(cwd);

our $cwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_package_path \'$cwd/?/init.lua;;\';

    init_by_lua_block {
        local log = ngx.log
        local ERR = ngx.ERR

        -- local verbose = true
        local verbose = false
        local outfile = "$Test::Nginx::Util::ErrLogFile"
        -- local outfile = "/tmp/v.log"
        if verbose then
            local dump = require "jit.dump"
            dump.on(nil, outfile)
        else
            local v = require "jit.v"
            v.on(outfile)
        end

        require "resty.core"
        -- jit.opt.start("hotloop=1")
        -- jit.opt.start("loopunroll=1000000")
        -- jit.off()


        local checks = require "kong.sdk.private.checks"
        local phases = checks.phases


        local function monkey_patch_upvalue(f, name, val)
            for i = 1, math.huge do
                local up, upv = debug.getupvalue(f, i)
                if not up then
                    return
                end
                if up == name then
                    debug.setupvalue(f, i, val)
                    return upv
                end
            end
        end


        function phase_check_functions(phase)
            local SDK = require "kong.sdk"
            local sdk = SDK.new()
            local mod = sdk
            for part in phase_check_module:gmatch("[^.]+") do
                mod = mod[part]
            end

            ngx.ctx.kong_phase = phase

            for fname, fn in pairs(mod) do
                if type(fn) == "function" then
                    local msg = "in " .. checks.phases[phase]:lower() .. ", " ..
                                fname .. " expected "

                    -- Run function with phase checked disabled
                    local saved = monkey_patch_upvalue(fn, "check_phase", function() end)

                    local fdata = phase_check_data[fname]
                    assert(fdata, "function " .. fname ..
                                  " has no phase checking data")
                    local expected = fdata[checks.phases[phase]:lower()]

                    local forced_false = expected == "forced false"
                    if forced_false then
                        expected = true
                    end

                    local ok1, err1 = pcall(fn, unpack(fdata.args))

                    if ok1 ~= expected then
                        log(ERR, msg, tostring(expected),
                                 " when phase check is disabled")
                    end

                    if not forced_false and ok1 == false and not err1:match("API disabled in the ") then
                        log(ERR, msg, "an OpenResty error but got ", (err1:gsub(",", ";")))
                    end

                    -- Re-enable phase checking and compare results
                    monkey_patch_upvalue(fn, "check_phase", saved)

                    if forced_false then
                        ok1, err1 = false, ""
                        expected = false
                    end


                    local ok2, err2 = pcall(fn, unpack(fdata.args))

                    if ok1 then
                        -- succeeded without phase checking,
                        -- phase checking should not block it.
                        if not ok2 then
                            log(ERR, msg, "true when phase check is enabled")
                        end
                    else
                        if ok2 then
                            log(ERR, msg, "false when phase check is enabled")
                        end

                        -- if failed with OpenResty phase error
                        if err1:match("API disabled in the ") then
                            -- should replace with a Kong error
                            if not err2:match("function cannot be called") then
                                log(ERR, msg, "a Kong-generated error")
                            end
                        end
                    end
                    --]]

                end
            end
        end

    }
_EOC_

1;
