#!/bin/bash
# Parser decision/filter tests. Each parser is fed realistic log lines and its
# notification payload (or silence) is asserted.

parser_output() {
    local module="$1"
    local line="$2"
    local extra="${3:-}"
    bash "$ROOT/modules/$module/parser.sh" "$line" "$extra"
}

test_ssh_logins() {
    local line out
    line='Jan  1 00:00:00 host sshd[123]: Accepted publickey for alice from 203.0.113.5 port 4242 ssh2: ED25519 SHA256:abc'
    out="$(parser_output ssh_logins "$line")"
    assert_contains "$out" "SSH login to"
    assert_contains "$out" "alice from 203.0.113.5 port 4242 at "
    assert_empty "$(parser_output ssh_logins 'Jan  1 00:00:00 host sshd[123]: Failed password for root from 203.0.113.5 port 22 ssh2')"
}

test_authelia_logins() {
    local line out
    line="time=\"2026-01-01T00:00:00Z\" level=info msg=\"Successful 1FA authentication attempt by user 'alice'\" method=POST path=/api/firstfactor remote_ip=203.0.113.5"
    out="$(parser_output authelia_logins "$line")"
    assert_contains "$out" "Successful Login"
    assert_contains "$out" "Successful 1FA authentication attempt by user 'alice' from 203.0.113.5 at 2026-01-01T00:00:00Z"
    assert_empty "$(parser_output authelia_logins 'time="2026-01-01T00:00:00Z" level=info msg="Unsuccessful authentication attempt" remote_ip=203.0.113.5')"
}

test_generic_logs() {
    local out extra
    extra='{"regex":"ERROR","title":"App error","message":"Matched:"}'
    out="$(parser_output generic_logs 'level=ERROR boom' "$extra")"
    assert_contains "$out" "App error"
    assert_contains "$out" "Matched:"
    assert_contains "$out" "level=ERROR boom"
    assert_empty "$(parser_output generic_logs 'level=INFO ok' "$extra")"

    extra='{"regex":"","title":"","message":""}'
    out="$(parser_output generic_logs 'anything at all' "$extra")"
    assert_contains "$out" "Logtfy Alert"
    assert_contains "$out" "anything at all"

    assert_empty "$(parser_output generic_logs 'anything' '')"
}

test_mock_module() {
    local out
    out="$(parser_output mock_module 'Mock log 10')"
    assert_contains "$out" "Mock log number 10 is divisible by 5"
    assert_empty "$(parser_output mock_module 'Mock log 7')"
}

test_port_checker() {
    local out
    out="$(parser_output port_checker 'Port 443 on example.org is closed!')"
    assert_contains "$out" "Port Checker on"
    assert_contains "$out" "Port 443 on example.org is closed!"
    assert_empty "$(parser_output port_checker 'nothing to report')"
}

test_syncthing_connections() {
    local connect disconnect out
    connect='[ABCDEF] 2026/01/01 12:00:00 INFO: Device ABCDEF client is "syncthing v1.27.0" at "1.2.3.4:1234"'
    disconnect='[ABCDEF] 2026/01/01 12:00:00 INFO: Lost primary connection to ABCDEF "syncthing v1.27.0" at 1.2.3.4:1234: read: connection reset by peer'

    out="$(parser_output syncthing_connections "$connect")"
    assert_contains "$out" "Device Connected"
    assert_contains "$out" "ABCDEF (1.2.3.4:1234) at 12:00:00 on 2026/01/01"
    assert_empty "$(parser_output syncthing_connections "$connect" 'OTHER,ABCDEF')"

    out="$(parser_output syncthing_connections "$disconnect")"
    assert_contains "$out" "Device Disconnected"
    assert_contains "$out" "ABCDEF at 12:00:00 on 2026/01/01"
}

test_traefik_accesslogs() {
    STATE_DIR="$(mktemp -d)"
    trap 'rm -rf "$STATE_DIR"' EXIT
    local line other out

    line="{\"time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"ClientHost\":\"203.0.113.5\",\"RequestAddr\":\"example.com\"}"
    out="$(LOGTFY_STATE_DIR="$STATE_DIR" parser_output traefik_accesslogs "$line")"
    assert_contains "$out" "New Client IP (within 24H)"
    assert_contains "$out" "203.0.113.5 requested example.com"
    assert_empty "$(LOGTFY_STATE_DIR="$STATE_DIR" parser_output traefik_accesslogs "$line")"

    other="{\"time\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"ClientHost\":\"203.0.113.6\",\"RequestAddr\":\"example.org\"}"
    out="$(LOGTFY_STATE_DIR="$STATE_DIR" parser_output traefik_accesslogs "$other")"
    assert_contains "$out" "203.0.113.6 requested example.org"
}

test_traefik_geoblock() {
    STATE_DIR="$(mktemp -d)"
    trap 'rm -rf "$STATE_DIR"' EXIT
    local stamp line other out

    stamp="$(date -u '+%Y/%m/%d %H:%M:%S')"
    line="INFO: GeoBlock: ${stamp} my-geoblock@file: request allowed [203.0.113.9] for country [US]"
    out="$(LOGTFY_STATE_DIR="$STATE_DIR" parser_output traefik_geoblock_allowed_requests "$line")"
    assert_contains "$out" "New Allowed Client IP (within 24H)"
    assert_contains "$out" "[203.0.113.9] from [US]"
    assert_empty "$(LOGTFY_STATE_DIR="$STATE_DIR" parser_output traefik_geoblock_allowed_requests "$line")"

    other="INFO: GeoBlock: ${stamp} my-geoblock@file: request allowed [203.0.113.10] for country [DE]"
    out="$(LOGTFY_STATE_DIR="$STATE_DIR" parser_output traefik_geoblock_allowed_requests "$other")"
    assert_contains "$out" "[203.0.113.10] from [DE]"
}

test_traefik_accesslogs_custom() {
    local out
    out="$(parser_output traefik_accesslogs_custom \
        '{"ClientAddr":"203.0.113.5","StartUTC":"2026-01-01T00:00:00Z","RequestMethod":"GET","RequestHost":"example.com","RequestPath":"/x","DownstreamStatus":200}' \
        '200')"
    assert_contains "$out" "Traefik Access Alert"
    assert_contains "$out" "From (203.0.113.5) at 2026-01-01T00:00:00Z: GET example.com/x -> 200"

    out="$(parser_output traefik_accesslogs_custom \
        '203.0.113.5 - - [01/Jan/2026:00:00:00 +0000] "GET /y HTTP/1.1" 403 0' \
        '403')"
    assert_contains "$out" "From (203.0.113.5) at 01/Jan/2026:00:00:00:"

    assert_empty "$(parser_output traefik_accesslogs_custom '203.0.113.5 - - [01/Jan/2026:00:00:00 +0000] "GET /y HTTP/1.1" 200 0' '403')"

    local fail_out
    if fail_out="$(parser_output traefik_accesslogs_custom 'anything' '' 2>&1)"; then
        fail "expected a missing filter pattern to exit non-zero"
    fi
    assert_contains "$fail_out" "NO PATTERN PROVIDED!"
}

test_watchtower_updates() {
    local out
    out="$(parser_output watchtower_updates 'time="2026-01-01T00:00:00Z" level=info msg="Found new image" container=foo')"
    assert_contains "$out" "Updating Image"
    assert_contains "$out" "Found new image: container=foo at 2026-01-01T00:00:00Z"

    out="$(parser_output watchtower_updates 'time=2026-01-01T00:00:00Z level=info msg="Found new image" container=bar new=sha256:abc')"
    assert_contains "$out" "Found new image: container=bar new=sha256:abc at 2026-01-01T00:00:00Z"

    assert_empty "$(parser_output watchtower_updates 'time=2026-01-01T00:00:00Z level=info msg="Session done"')"
}

test_k8s_parser_delegation() {
    local out
    out="$(parser_output traefik_accesslogs_custom_k8s \
        '{"ClientAddr":"203.0.113.5","StartUTC":"2026-01-01T00:00:00Z","RequestMethod":"GET","RequestHost":"example.com","RequestPath":"/x","DownstreamStatus":200}' \
        '200')"
    assert_contains "$out" "GET example.com/x -> 200"
}

run_test "parser: ssh logins" test_ssh_logins
run_test "parser: authelia logins" test_authelia_logins
run_test "parser: generic regex filtering" test_generic_logs
run_test "parser: mock module" test_mock_module
run_test "parser: port checker" test_port_checker
run_test "parser: syncthing connect/disconnect filter" test_syncthing_connections
run_test "parser: traefik access-log dedupe" test_traefik_accesslogs
run_test "parser: traefik geoblock dedupe" test_traefik_geoblock
run_test "parser: traefik custom access log" test_traefik_accesslogs_custom
run_test "parser: watchtower log formats" test_watchtower_updates
run_test "parser: k8s delegation" test_k8s_parser_delegation
