use strict;
use warnings FATAL => 'all';
use Test::Nginx::Socket::Lua;
use t::Util;

$ENV{TEST_NGINX_HTML_DIR} ||= html_dir();

plan tests => repeat_each() * (blocks() * 2);

run_tests();

__DATA__

=== TEST 1: verify phase checking in kong.service.request
--- http_config eval
qq{
    $t::Util::HttpConfig

    server {
        listen unix:$ENV{TEST_NGINX_HTML_DIR}/nginx.sock;

        location / {
            return 200;
        }
    }

    init_worker_by_lua_block {

        local checks = require "kong.sdk.private.checks"
        phases = checks.phases

        phase_check_module = "ip"
        phase_check_data = {
            is_trusted = {
                args            = { "127.0.0.1" },
                init_worker     = true,
                ssl_certificate = true,
                rewrite         = true,
                access          = true,
                header_filter   = true,
                body_filter     = true,
                log             = true,
            },
        }

        phase_check_functions(checks.phases.INIT_WORKER)
    }

    #ssl_certificate_by_lua_block {
    #    phase_check_functions(phases.SSL_CERTIFICATE)
    #}
}
--- config
    location /t {
        proxy_pass http://unix:$TEST_NGINX_HTML_DIR/nginx.sock;
        set $upstream_uri '/t';
        set $upstream_scheme 'http';

        rewrite_by_lua_block {
            phase_check_functions(phases.REWRITE)
        }

        access_by_lua_block {
            phase_check_functions(phases.ACCESS)
        }

        header_filter_by_lua_block {
            phase_check_functions(phases.HEADER_FILTER)
        }

        body_filter_by_lua_block {
            phase_check_functions(phases.BODY_FILTER)
        }

        log_by_lua_block {
            phase_check_functions(phases.LOG)
        }
    }
--- request
GET /t
--- no_error_log
[error]
