#!/bin/bash
# configParser.js is the daemon's configuration brain: module/instance
# enablement, ntfy routing, topic prefixes, and crash backoff.

make_parser_dir() {
    PARSER_DIR="$(mktemp -d)"
    trap 'rm -rf "$PARSER_DIR"' EXIT
    cp "$ROOT/configParser.js" "$PARSER_DIR/configParser.js"
    cp "$ROOT/tests/fixtures/module-config.json" "$PARSER_DIR/config.json"
}

parser_action() {
    node "$PARSER_DIR/configParser.js" "$@"
}

test_module_enablement() {
    make_parser_dir
    assert_eq "$(parser_action isModuleEnabled alpha)" "true"
    assert_eq "$(parser_action isModuleEnabled beta)" "false"
    assert_eq "$(parser_action isModuleEnabled gamma)" "false"
}

test_instance_enablement() {
    make_parser_dir
    assert_eq "$(parser_action isModuleInstanceEnabled alpha one)" "true"
    assert_eq "$(parser_action isModuleInstanceEnabled alpha two)" "false"
    assert_eq "$(parser_action isModuleInstanceEnabled gamma only)" "false"
}

test_list_instances() {
    make_parser_dir
    assert_eq "$(parser_action listModuleInstances alpha)" "$(printf 'one\ntwo')"
    assert_eq "$(parser_action listModuleInstances gamma)" "only"
    assert_empty "$(parser_action listModuleInstances beta)"
}

test_crash_backoff() {
    make_parser_dir
    assert_eq "$(parser_action getCrashNotificationInitialBackoffSeconds)" "7"
    assert_eq "$(parser_action getCrashNotificationMaxBackoffSeconds)" "42"
}

test_logger_and_parser_args() {
    make_parser_dir
    assert_eq "$(parser_action getLoggerArgForModule alpha)" "container-a"
    assert_eq "$(parser_action getLoggerArgForModule alpha two)" "container-two"
    assert_eq "$(parser_action getParserArgForModule alpha one)" '{"regex":"x"}'
    assert_empty "$(parser_action getParserArgForModule beta)"
}

test_ntfy_configs() {
    make_parser_dir
    local got

    got="$(parser_action getNtfyConfigsForModule alpha one | jq -S .)"
    assert_eq "$(printf '%s' "$got" | jq -r 'length')" "2"
    assert_eq "$(printf '%s' "$got" | jq -r '.[0].host')" "https://ntfy.example"
    assert_eq "$(printf '%s' "$got" | jq -r '.[0].topic')" "pre_alpha_one"
    assert_eq "$(printf '%s' "$got" | jq -r '.[0].authHeader')" "Bearer test"
    assert_eq "$(printf '%s' "$got" | jq -r '.[1].host')" "https://fallback.example"
    assert_eq "$(printf '%s' "$got" | jq -r '.[1].topic')" "fb_alpha_one"

    # Instance settings win; the fallback still comes from the module config.
    got="$(parser_action getNtfyConfigsForModule alpha two | jq -S .)"
    assert_eq "$(printf '%s' "$got" | jq -r '.[0].host')" "https://same.example"
    assert_eq "$(printf '%s' "$got" | jq -r '.[0].topic')" "custom"
    assert_eq "$(printf '%s' "$got" | jq -r '.[1].topic')" "fb_custom"

    # Same host as main: the fallback is deduplicated.
    got="$(parser_action getNtfyConfigsForModule delta | jq -S .)"
    assert_eq "$(printf '%s' "$got" | jq -r 'length')" "2"
    assert_eq "$(printf '%s' "$got" | jq -r '.[1].host')" "https://same.example"
}

test_summary_priority_tags() {
    make_parser_dir
    local summary
    summary="$(parser_action getModuleSummaryString alpha one)"
    assert_eq "$summary" "'alpha/one' to 'https://ntfy.example/pre_alpha_one' or 'https://fallback.example/fb_alpha_one'"
    assert_eq "$(parser_action getDefaultPriorityForModule alpha one)" "4"
    assert_eq "$(parser_action getDefaultTagsForModule alpha one)" "a,b"
    assert_empty "$(parser_action getDefaultPriorityForModule beta)"
}

test_config_errors() {
    make_parser_dir
    local out

    if out="$(parser_action getNtfyConfigsForModule broken 2>&1)"; then
        fail "expected a missing ntfy config to exit non-zero"
    fi
    assert_contains "$out" "Could not determine main ntfy config"

    if out="$(parser_action notAnAction 2>&1)"; then
        fail "expected an unknown action to exit non-zero"
    fi
    assert_contains "$out" "Unknown action"
}

test_defaults() {
    DEFAULTS_DIR="$(mktemp -d)"
    trap 'rm -rf "$DEFAULTS_DIR"' EXIT
    cp "$ROOT/configParser.js" "$DEFAULTS_DIR/configParser.js"
    cat > "$DEFAULTS_DIR/config.json" <<'EOF'
{
    "ntfyConfig": {
        "configs": [
            {"id": "only", "host": "https://only.example"}
        ],
        "defaultConfig": "only"
    },
    "moduleCustomization": []
}
EOF
    assert_eq "$(node "$DEFAULTS_DIR/configParser.js" getCrashNotificationInitialBackoffSeconds)" "60"
    assert_eq "$(node "$DEFAULTS_DIR/configParser.js" getCrashNotificationMaxBackoffSeconds)" "3600"
    assert_eq "$(node "$DEFAULTS_DIR/configParser.js" isModuleEnabled anything)" "false"
}

run_test "configParser: module enablement" test_module_enablement
run_test "configParser: instance enablement" test_instance_enablement
run_test "configParser: instance listing" test_list_instances
run_test "configParser: crash backoff" test_crash_backoff
run_test "configParser: module args" test_logger_and_parser_args
run_test "configParser: ntfy routing" test_ntfy_configs
run_test "configParser: summary, priority, tags" test_summary_priority_tags
run_test "configParser: error paths" test_config_errors
run_test "configParser: defaults" test_defaults
