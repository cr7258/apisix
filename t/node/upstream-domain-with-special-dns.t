#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
BEGIN {
    $ENV{CUSTOM_DNS_SERVER} = "127.0.0.1:1053";
}

use t::APISIX 'no_plan';

repeat_each(1);
log_level('info');
no_root_location();
no_shuffle();

add_block_preprocessor(sub {
    my ($block) = @_;

    my $yaml_config = $block->yaml_config // <<_EOC_;
apisix:
    node_listen: 1984
deployment:
    role: data_plane
    role_data_plane:
        config_provider: yaml
_EOC_

    $block->set_value("yaml_config", $yaml_config);

    my $routes = <<_EOC_;
routes:
  -
    uri: /hello
    upstream_id: 1
#END
_EOC_

    $block->set_value("apisix_yaml", $block->apisix_yaml . $routes);

    if (!$block->error_log && !$block->no_error_log) {
        $block->set_value("no_error_log", "[error]");
    }
});

run_tests();

__DATA__

=== TEST 1: AAAA
--- listen_ipv6
--- apisix_yaml
upstreams:
    -
    id: 1
    nodes:
        ipv6.test.local:1980: 1
    type: roundrobin
--- request
GET /hello
--- response_body
hello world



=== TEST 2: default ttl
--- log_level: debug
--- apisix_yaml
upstreams:
    -
    id: 1
    nodes:
        ttl.test.local:1980: 1
    type: roundrobin
--- config
    location /t {
        content_by_lua_block {
            local http = require "resty.http"
            local uri = "http://127.0.0.1:" .. ngx.var.server_port .. "/hello"
            for i = 1, 3 do
                local httpc = http.new()
                local res, err = httpc:request_uri(uri, {method = "GET"})
                if not res or res.body ~= "hello world\n" then
                    ngx.say(err)
                    return
                end
            end
        }
    }
--- request
GET /t
--- error_log
"ttl":300
--- grep_error_log eval
qr/connect to 127.0.0.1:1053/
--- grep_error_log_out
connect to 127.0.0.1:1053



=== TEST 3: override ttl
--- log_level: debug
--- yaml_config
apisix:
    node_listen: 1984
    dns_resolver_valid: 900
deployment:
    role: data_plane
    role_data_plane:
        config_provider: yaml
--- apisix_yaml
upstreams:
    -
    id: 1
    nodes:
        ttl.test.local:1980: 1
    type: roundrobin
--- config
    location /t {
        content_by_lua_block {
            local http = require "resty.http"
            local uri = "http://127.0.0.1:" .. ngx.var.server_port .. "/hello"
            for i = 1, 3 do
                local httpc = http.new()
                local res, err = httpc:request_uri(uri, {method = "GET"})
                if not res or res.body ~= "hello world\n" then
                    ngx.say(err)
                    return
                end
            end
        }
    }
--- request
GET /t
--- grep_error_log eval
qr/connect to 127.0.0.1:1053/
--- grep_error_log_out
connect to 127.0.0.1:1053
--- error_log
"ttl":900



=== TEST 4: cache expire
--- log_level: debug
--- apisix_yaml
upstreams:
    -
    id: 1
    nodes:
        ttl.1s.test.local:1980: 1
    type: roundrobin
--- config
    location /t {
        content_by_lua_block {
            local http = require "resty.http"
            local uri = "http://127.0.0.1:" .. ngx.var.server_port .. "/hello"
            for i = 1, 2 do
                for j = 1, 3 do
                    local httpc = http.new()
                    local res, err = httpc:request_uri(uri, {method = "GET"})
                    if not res or res.body ~= "hello world\n" then
                        ngx.say(err)
                        return
                    end
                end

                if i < 2 then
                    ngx.sleep(1.1)
                end
            end
        }
    }
--- request
GET /t
--- grep_error_log eval
qr/connect to 127.0.0.1:1053/
--- grep_error_log_out
connect to 127.0.0.1:1053
connect to 127.0.0.1:1053



=== TEST 5: cache expire (override ttl)
--- log_level: debug
--- yaml_config
apisix:
    node_listen: 1984
    dns_resolver_valid: 1
deployment:
    role: data_plane
    role_data_plane:
        config_provider: yaml
--- apisix_yaml
upstreams:
    -
    id: 1
    nodes:
        ttl.test.local:1980: 1
    type: roundrobin
--- config
    location /t {
        content_by_lua_block {
            local http = require "resty.http"
            local uri = "http://127.0.0.1:" .. ngx.var.server_port .. "/hello"
            for i = 1, 2 do
                for j = 1, 3 do
                    local httpc = http.new()
                    local res, err = httpc:request_uri(uri, {method = "GET"})
                    if not res or res.body ~= "hello world\n" then
                        ngx.say(err)
                        return
                    end
                end

                if i < 2 then
                    ngx.sleep(1.1)
                end
            end
        }
    }
--- request
GET /t
--- grep_error_log eval
qr/connect to 127.0.0.1:1053/
--- grep_error_log_out
connect to 127.0.0.1:1053
connect to 127.0.0.1:1053
