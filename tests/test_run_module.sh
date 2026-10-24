#!/bin/bash
# runModule.sh owns the pipe between a logger and its parser, the rolling
# crash-tail file, and the notify invocation for parser output.

install_test_module() {
    local dir="$1"
    local name="$2"
    mkdir -p "$dir/modules/$name"
    cat > "$dir/modules/$name/logger.sh" <<'EOF'
#!/bin/bash
echo "line one"
echo "line two alert"
echo "line three"
EOF
    cat > "$dir/modules/$name/parser.sh" <<'EOF'
#!/bin/bash
case "$1" in
    *alert*) printf 'Test Title\n\n\nmessage: %s\n' "$1" ;;
esac
EOF
}

run_module() {
    local dir="$1"
    local name="$2"
    local tail_file="$3"
    local notify_log="$4"
    local priority="${5:-}"
    local tags="${6:-}"
    NOTIFY_LOG="$notify_log" bash "$dir/runModule.sh" "$name" "logger-arg" "parser-arg" \
        '[{"id":"fake","host":"https://127.0.0.1:1","topic":"t"}]' "$tail_file" "$priority" "$tags"
}

test_pipeline_and_notify() {
    RUN_MODULE_TMP="$(mktemp -d)"
    trap 'rm -rf "$RUN_MODULE_TMP"' EXIT
    copy_repo "$RUN_MODULE_TMP"
    install_notify_recorder "$RUN_MODULE_TMP"
    install_test_module "$RUN_MODULE_TMP" test_module

    run_module "$RUN_MODULE_TMP" test_module "$RUN_MODULE_TMP/tail.log" "$RUN_MODULE_TMP/notify.log" "4" "computer,tada"

    assert_file_contains "$RUN_MODULE_TMP/tail.log" "line one"
    assert_file_contains "$RUN_MODULE_TMP/tail.log" "line two alert"
    assert_file_contains "$RUN_MODULE_TMP/tail.log" "line three"

    local call
    call="$(jq -c . "$RUN_MODULE_TMP/notify.log")"
    assert_eq "$(printf '%s' "$call" | jq -r 'length')" "5"
    assert_eq "$(printf '%s' "$call" | jq -r '.[0]')" "test_module"
    assert_contains "$(printf '%s' "$call" | jq -r '.[1]')" "Test Title"
    assert_contains "$(printf '%s' "$call" | jq -r '.[1]')" "message: line two alert"
    assert_eq "$(printf '%s' "$call" | jq -r '.[3]')" "4"
    assert_eq "$(printf '%s' "$call" | jq -r '.[4]')" "computer,tada"
}

test_logger_failure_propagates() {
    RUN_MODULE_TMP="$(mktemp -d)"
    trap 'rm -rf "$RUN_MODULE_TMP"' EXIT
    copy_repo "$RUN_MODULE_TMP"
    install_notify_recorder "$RUN_MODULE_TMP"
    mkdir -p "$RUN_MODULE_TMP/modules/fail_module"
    cat > "$RUN_MODULE_TMP/modules/fail_module/logger.sh" <<'EOF'
#!/bin/bash
echo "before crash"
echo "stderr boom" >&2
exit 7
EOF
    cat > "$RUN_MODULE_TMP/modules/fail_module/parser.sh" <<'EOF'
#!/bin/bash
exit 0
EOF

    local rc
    set +e
    run_module "$RUN_MODULE_TMP" fail_module "$RUN_MODULE_TMP/tail.log" "$RUN_MODULE_TMP/notify.log" 2>"$RUN_MODULE_TMP/stderr.log"
    rc=$?
    set -e
    assert_eq "$rc" "7"
    assert_file_contains "$RUN_MODULE_TMP/tail.log" "before crash"
    assert_file_contains "$RUN_MODULE_TMP/tail.log" "stderr boom"
}

test_parser_failure_is_contained() {
    RUN_MODULE_TMP="$(mktemp -d)"
    trap 'rm -rf "$RUN_MODULE_TMP"' EXIT
    copy_repo "$RUN_MODULE_TMP"
    install_notify_recorder "$RUN_MODULE_TMP"
    mkdir -p "$RUN_MODULE_TMP/modules/bad_parser"
    cat > "$RUN_MODULE_TMP/modules/bad_parser/logger.sh" <<'EOF'
#!/bin/bash
echo "one line"
EOF
    cat > "$RUN_MODULE_TMP/modules/bad_parser/parser.sh" <<'EOF'
#!/bin/bash
exit 1
EOF

    run_module "$RUN_MODULE_TMP" bad_parser "$RUN_MODULE_TMP/tail.log" "$RUN_MODULE_TMP/notify.log"
    assert_file_contains "$RUN_MODULE_TMP/tail.log" "one line"
    if [ -s "$RUN_MODULE_TMP/notify.log" ]; then
        fail "a failing parser must not trigger a notification"
    fi
}

test_tail_keeps_last_ten_lines() {
    RUN_MODULE_TMP="$(mktemp -d)"
    trap 'rm -rf "$RUN_MODULE_TMP"' EXIT
    copy_repo "$RUN_MODULE_TMP"
    install_notify_recorder "$RUN_MODULE_TMP"
    mkdir -p "$RUN_MODULE_TMP/modules/many_lines"
    cat > "$RUN_MODULE_TMP/modules/many_lines/logger.sh" <<'EOF'
#!/bin/bash
for i in $(seq 1 15); do
    printf 'line-%02d\n' "$i"
done
EOF
    cat > "$RUN_MODULE_TMP/modules/many_lines/parser.sh" <<'EOF'
#!/bin/bash
exit 0
EOF

    run_module "$RUN_MODULE_TMP" many_lines "$RUN_MODULE_TMP/tail.log" "$RUN_MODULE_TMP/notify.log"
    assert_file_contains "$RUN_MODULE_TMP/tail.log" "line-15"
    assert_not_contains "$(cat "$RUN_MODULE_TMP/tail.log")" "line-05"
}

test_notify_failure_does_not_break_module() {
    RUN_MODULE_TMP="$(mktemp -d)"
    trap 'rm -rf "$RUN_MODULE_TMP"' EXIT
    copy_repo "$RUN_MODULE_TMP"
    cat > "$RUN_MODULE_TMP/notify.js" <<'EOF'
console.error('notify down')
process.exit(1)
EOF
    install_test_module "$RUN_MODULE_TMP" test_module

    run_module "$RUN_MODULE_TMP" test_module "$RUN_MODULE_TMP/tail.log" "$RUN_MODULE_TMP/notify.log" 2>"$RUN_MODULE_TMP/stderr.log"
    assert_file_contains "$RUN_MODULE_TMP/tail.log" "line two alert"
    assert_file_contains "$RUN_MODULE_TMP/stderr.log" "notify down"
}

run_test "runModule: logger -> parser -> notify" test_pipeline_and_notify
run_test "runModule: logger exit code and stderr tail" test_logger_failure_propagates
run_test "runModule: parser failure is contained" test_parser_failure_is_contained
run_test "runModule: crash tail keeps last ten lines" test_tail_keeps_last_ten_lines
run_test "runModule: notify failure does not kill the module" test_notify_failure_does_not_break_module
