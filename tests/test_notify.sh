#!/bin/bash
# notify.js is tested against a local HTTPS ntfy stand-in: payload formatting,
# priority/tag defaults, auth headers, and main -> fallback routing.

start_ntfy_server() {
    NOTIFY_TMP="$(mktemp -d)"
    NOTIFY_PORT_FILE="$NOTIFY_TMP/port"
    NOTIFY_REQUEST_LOG="$NOTIFY_TMP/requests.log"
    : > "$NOTIFY_REQUEST_LOG"

    openssl req -x509 -newkey rsa:2048 -nodes \
        -keyout "$NOTIFY_TMP/key.pem" \
        -out "$NOTIFY_TMP/cert.pem" \
        -days 1 \
        -subj "/CN=127.0.0.1" \
        -addext "subjectAltName=IP:127.0.0.1" >/dev/null 2>&1

    TLS_KEY="$NOTIFY_TMP/key.pem" \
        TLS_CERT="$NOTIFY_TMP/cert.pem" \
        REQUEST_LOG="$NOTIFY_REQUEST_LOG" \
        PORT_FILE="$NOTIFY_PORT_FILE" \
        node "$ROOT/tests/fixtures/fake-ntfy-server.js" &
    NOTIFY_SERVER_PID=$!

    trap 'kill "$NOTIFY_SERVER_PID" 2>/dev/null || true; wait "$NOTIFY_SERVER_PID" 2>/dev/null || true; rm -rf "$NOTIFY_TMP"' EXIT

    local _
    for _ in $(seq 1 100); do
        if [ -s "$NOTIFY_PORT_FILE" ]; then
            break
        fi
        sleep 0.05
    done
    if [ ! -s "$NOTIFY_PORT_FILE" ]; then
        fail "fake ntfy server did not start"
    fi
    NOTIFY_PORT="$(cat "$NOTIFY_PORT_FILE")"
    NOTIFY_HOST="https://127.0.0.1:${NOTIFY_PORT}"
}

notify_run() {
    local parser_output="$1"
    local configs="$2"
    local default_priority="${3:-}"
    local default_tags="${4:-}"
    NODE_TLS_REJECT_UNAUTHORIZED=0 node "$ROOT/notify.js" test_module \
        "$parser_output" "$configs" "$default_priority" "$default_tags"
}

test_notification_payload() {
    start_ntfy_server
    local configs out call
    configs="$(jq -cn --arg host "$NOTIFY_HOST" '[{id:"local",host:$host,topic:"pre_topic",authHeader:"Bearer abc"}]')"

    out="$(notify_run "$(printf 'Title\n4\ntag1,tag2\nhello\nworld')" "$configs" 2>&1)"
    assert_contains "$out" "ok"

    call="$(jq -c . "$NOTIFY_REQUEST_LOG")"
    assert_eq "$(printf '%s' "$call" | jq -r '.method')" "POST"
    assert_eq "$(printf '%s' "$call" | jq -r '.url')" "/pre_topic"
    assert_eq "$(printf '%s' "$call" | jq -r '.headers.title')" "Title"
    assert_eq "$(printf '%s' "$call" | jq -r '.headers.priority')" "4"
    assert_eq "$(printf '%s' "$call" | jq -r '.headers.tags')" "tag1,tag2"
    assert_eq "$(printf '%s' "$call" | jq -r '.headers.authorization')" "Bearer abc"
    assert_eq "$(printf '%s' "$call" | jq -r '.body')" "$(printf 'hello\nworld')"
}

test_defaults() {
    start_ntfy_server
    local configs call
    configs="$(jq -cn --arg host "$NOTIFY_HOST" '[{id:"local",host:$host,topic:"topic"}]')"

    notify_run "Title" "$configs" "3" "computer,tada" >/dev/null 2>&1
    call="$(jq -c . "$NOTIFY_REQUEST_LOG")"
    assert_eq "$(printf '%s' "$call" | jq -r '.headers.priority')" "3"
    assert_eq "$(printf '%s' "$call" | jq -r '.headers.tags')" "computer,tada"
    assert_eq "$(printf '%s' "$call" | jq -r '.body')" "No message specified."
}

test_fallback() {
    start_ntfy_server
    local configs out call
    configs="$(jq -cn --arg host "$NOTIFY_HOST" '[
        {id:"down",host:"https://127.0.0.1:1",topic:"bad"},
        {id:"local",host:$host,topic:"good"}
    ]')"

    out="$(notify_run "Title" "$configs" 2>&1)"
    assert_contains "$out" "Could not post notification"
    assert_contains "$out" "ok"
    assert_eq "$(wc -l < "$NOTIFY_REQUEST_LOG")" "1"
    call="$(jq -c . "$NOTIFY_REQUEST_LOG")"
    assert_eq "$(printf '%s' "$call" | jq -r '.url')" "/good"
}

test_http_error_fallback() {
    start_ntfy_server
    local configs out
    configs="$(jq -cn --arg host "$NOTIFY_HOST" '[
        {id:"bad",host:$host,topic:"fail500"},
        {id:"good",host:$host,topic:"good"}
    ]')"

    out="$(notify_run "Title" "$configs" 2>&1)"
    assert_contains "$out" "Could not post notification"
    assert_contains "$out" "ok"
    assert_eq "$(wc -l < "$NOTIFY_REQUEST_LOG")" "2"
    assert_contains "$(sed -n '1p' "$NOTIFY_REQUEST_LOG")" '"url":"/fail500"'
    assert_contains "$(sed -n '2p' "$NOTIFY_REQUEST_LOG")" '"url":"/good"'
}

test_http_error_all_fail() {
    start_ntfy_server
    local out rc
    set +e
    out="$(notify_run "Title" "[{\"id\":\"bad\",\"host\":\"$NOTIFY_HOST\",\"topic\":\"fail500\"}]" 2>&1)"
    rc=$?
    set -e
    assert_eq "$rc" "1"
    assert_contains "$out" "ERROR: Could not post notification"
    assert_contains "$out" "status code: 500"
}

test_invalid_or_empty_configs() {
    local out rc
    set +e
    out="$(notify_run "Title" 'not-json' 2>&1)"
    rc=$?
    set -e
    assert_eq "$rc" "1"
    assert_contains "$out" "SyntaxError"

    set +e
    out="$(notify_run "Title" '[]' 2>&1)"
    rc=$?
    set -e
    assert_eq "$rc" "1"
    assert_contains "$out" "ERROR: Could not post notification"
}

test_default_title() {
    start_ntfy_server
    local configs call
    configs="$(jq -cn --arg host "$NOTIFY_HOST" '[{id:"local",host:$host,topic:"defaults"}]')"
    notify_run "" "$configs" >/dev/null 2>&1
    call="$(jq -c . "$NOTIFY_REQUEST_LOG")"
    assert_eq "$(printf '%s' "$call" | jq -r '.headers.title')" "Logtfy Alert"
    assert_eq "$(printf '%s' "$call" | jq -r '.body')" "No message specified."
}

test_all_fail() {
    local out rc
    set +e
    out="$(notify_run "Title" '[{"id":"down","host":"https://127.0.0.1:1","topic":"bad"}]' 2>&1)"
    rc=$?
    set -e
    assert_eq "$rc" "1"
    assert_contains "$out" "ERROR: Could not post notification for module 'test_module'"
}

run_test "notify: payload, headers, auth" test_notification_payload
run_test "notify: priority/tag/message defaults" test_defaults
run_test "notify: HTTP error falls back" test_http_error_fallback
run_test "notify: HTTP error on all endpoints" test_http_error_all_fail
run_test "notify: invalid/empty configs" test_invalid_or_empty_configs
run_test "notify: default title" test_default_title
run_test "notify: fallback routing" test_fallback
run_test "notify: all endpoints fail" test_all_fail
