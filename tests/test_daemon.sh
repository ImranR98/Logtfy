#!/bin/bash
# run.sh supervision: module discovery, start/crash notifications, restart
# backoff, disabled modules, shutdown hook, and the k8s/role helper output.

install_daemon_module() {
    local dir="$1"
    mkdir -p "$dir/modules/test_module"
    cat > "$dir/modules/test_module/logger.sh" <<'EOF'
#!/bin/bash
echo "daemon line"
exit 1
EOF
    cat > "$dir/modules/test_module/parser.sh" <<'EOF'
#!/bin/bash
printf 'Daemon Alert\n\n\n%s\n' "$1"
EOF
}

write_daemon_config() {
    local dir="$1"
    local enabled="$2"
    local initial="${3:-60}"
    local maximum="${4:-120}"
    cat > "$dir/config.json" <<EOF
{
    "ntfyConfig": {
        "configs": [
            {"id": "fake", "host": "https://127.0.0.1:1", "authHeader": null, "topicPrefix": "t_"}
        ],
        "defaultConfig": "fake",
        "fallbackConfig": null
    },
    "modulesEnabledByDefault": false,
    "crashNotificationInitialBackoffSeconds": ${initial},
    "crashNotificationMaxBackoffSeconds": ${maximum},
    "moduleCustomization": [
        {"module": "test_module", "enabled": ${enabled}, "defaultPriority": "4", "defaultTags": "test"}
    ]
}
EOF
}

write_instance_config() {
    local dir="$1"
    cat > "$dir/config.json" <<'EOF'
{
    "ntfyConfig": {
        "configs": [
            {"id": "fake", "host": "https://127.0.0.1:1", "authHeader": null, "topicPrefix": "t_"}
        ],
        "defaultConfig": "fake",
        "fallbackConfig": null
    },
    "modulesEnabledByDefault": false,
    "crashNotificationInitialBackoffSeconds": 60,
    "crashNotificationMaxBackoffSeconds": 120,
    "moduleCustomization": [
        {"module": "test_module", "moduleInstances": [
            {"name": "inst_one", "enabled": true, "loggerArg": "arg-one"},
            {"name": "inst_two", "enabled": false, "loggerArg": "arg-two"}
        ]}
    ]
}
EOF
}

install_instance_module() {
    local dir="$1"
    mkdir -p "$dir/modules/test_module"
    cat > "$dir/modules/test_module/logger.sh" <<'EOF'
#!/bin/bash
echo "logger-arg:$1"
exit 1
EOF
    cat > "$dir/modules/test_module/parser.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
}

test_crash_loop_and_backoff() {
    DAEMON_TMP="$(mktemp -d)"
    trap 'rm -rf "$DAEMON_TMP"' EXIT
    copy_repo "$DAEMON_TMP"
    install_notify_recorder "$DAEMON_TMP"
    rm -rf "${DAEMON_TMP:?}/modules"/*
    install_daemon_module "$DAEMON_TMP"
    write_daemon_config "$DAEMON_TMP" true

    NOTIFY_LOG="$DAEMON_TMP/notify.log" bash "$DAEMON_TMP/run.sh" > "$DAEMON_TMP/out.log" 2>&1 &
    DAEMON_PID=$!
    trap 'kill "$DAEMON_PID" 2>/dev/null || true; wait "$DAEMON_PID" 2>/dev/null || true; rm -rf "$DAEMON_TMP"' EXIT

    local _
    for _ in $(seq 1 60); do
        if grep -q "Crash notification suppressed by backoff" "$DAEMON_TMP/out.log" 2>/dev/null; then
            break
        fi
        sleep 0.5
    done
    kill -TERM "$DAEMON_PID"

    local out rc
    set +e
    wait "$DAEMON_PID"
    rc=$?
    set -e
    out="$(cat "$DAEMON_TMP/out.log")"

    assert_eq "$rc" "0"
    assert_contains "$out" "Running module: 'test_module' to 'https://127.0.0.1:1/t_test_module'"
    assert_contains "$out" "Module 'test_module' exited after"
    assert_contains "$out" "Crash notification suppressed by backoff"
    assert_contains "$out" "Restarting module 'test_module' in 5s"

    assert_file_contains "$DAEMON_TMP/notify.log" "Module Started"
    assert_file_contains "$DAEMON_TMP/notify.log" "Daemon Alert"
    assert_file_contains "$DAEMON_TMP/notify.log" "Crashed"
    assert_file_contains "$DAEMON_TMP/notify.log" "Container Kill"
}

test_backoff_cap() {
    DAEMON_TMP="$(mktemp -d)"
    trap 'rm -rf "$DAEMON_TMP"' EXIT
    copy_repo "$DAEMON_TMP"
    install_notify_recorder "$DAEMON_TMP"
    rm -rf "${DAEMON_TMP:?}/modules"/*
    install_daemon_module "$DAEMON_TMP"
    write_daemon_config "$DAEMON_TMP" true 1 2

    NOTIFY_LOG="$DAEMON_TMP/notify.log" LOGTFY_RESTART_DELAY=0.1 \
        bash "$DAEMON_TMP/run.sh" > "$DAEMON_TMP/out.log" 2>&1 &
    DAEMON_PID=$!
    trap 'kill "$DAEMON_PID" 2>/dev/null || true; wait "$DAEMON_PID" 2>/dev/null || true; rm -rf "$DAEMON_TMP"' EXIT

    local _
    for _ in $(seq 1 80); do
        if grep -q "current interval 2s" "$DAEMON_TMP/out.log" 2>/dev/null; then
            break
        fi
        sleep 0.1
    done
    kill -TERM "$DAEMON_PID"

    local out rc
    set +e
    wait "$DAEMON_PID"
    rc=$?
    set -e
    out="$(cat "$DAEMON_TMP/out.log")"

    assert_eq "$rc" "0"
    if ! grep -q "current interval 2s" "$DAEMON_TMP/out.log"; then
        tail -n 40 "$DAEMON_TMP/out.log" >&2
        fail "backoff interval never reached the configured maximum of 2s"
    fi
    assert_contains "$out" "Crash notification suppressed by backoff"
    assert_file_contains "$DAEMON_TMP/notify.log" "Crashed"
}

test_stable_resets_backoff() {
    DAEMON_TMP="$(mktemp -d)"
    trap 'rm -rf "$DAEMON_TMP"' EXIT
    copy_repo "$DAEMON_TMP"
    install_notify_recorder "$DAEMON_TMP"
    rm -rf "${DAEMON_TMP:?}/modules"/*
    mkdir -p "$DAEMON_TMP/modules/test_module"
    cat > "$DAEMON_TMP/modules/test_module/logger.sh" <<'EOF'
#!/bin/bash
sleep 2
echo "stable line"
exit 0
EOF
    cat > "$DAEMON_TMP/modules/test_module/parser.sh" <<'EOF'
#!/bin/bash
exit 0
EOF
    write_daemon_config "$DAEMON_TMP" true 60 120

    NOTIFY_LOG="$DAEMON_TMP/notify.log" LOGTFY_STABLE_THRESHOLD=1 LOGTFY_RESTART_DELAY=0.5 \
        bash "$DAEMON_TMP/run.sh" > "$DAEMON_TMP/out.log" 2>&1 &
    DAEMON_PID=$!
    trap 'kill "$DAEMON_PID" 2>/dev/null || true; wait "$DAEMON_PID" 2>/dev/null || true; rm -rf "$DAEMON_TMP"' EXIT

    local _
    for _ in $(seq 1 80); do
        if grep -q "stable line" "$DAEMON_TMP/out.log" 2>/dev/null; then
            break
        fi
        sleep 0.1
    done
    kill -TERM "$DAEMON_PID"

    local out rc
    set +e
    wait "$DAEMON_PID"
    rc=$?
    set -e
    out="$(cat "$DAEMON_TMP/out.log")"

    assert_eq "$rc" "0"
    assert_file_contains "$DAEMON_TMP/notify.log" "Stable"
    assert_file_contains "$DAEMON_TMP/notify.log" "Container Kill"
    if grep -q "Crashed" "$DAEMON_TMP/notify.log"; then
        fail "a module that stayed up past the stable threshold must not report a crash"
    fi
    assert_contains "$out" "stable line"
}

test_module_instances() {
    DAEMON_TMP="$(mktemp -d)"
    trap 'rm -rf "$DAEMON_TMP"' EXIT
    copy_repo "$DAEMON_TMP"
    install_notify_recorder "$DAEMON_TMP"
    rm -rf "${DAEMON_TMP:?}/modules"/*
    install_instance_module "$DAEMON_TMP"
    write_instance_config "$DAEMON_TMP"

    NOTIFY_LOG="$DAEMON_TMP/notify.log" LOGTFY_RESTART_DELAY=0.1 \
        bash "$DAEMON_TMP/run.sh" > "$DAEMON_TMP/out.log" 2>&1 &
    DAEMON_PID=$!
    trap 'kill "$DAEMON_PID" 2>/dev/null || true; wait "$DAEMON_PID" 2>/dev/null || true; rm -rf "$DAEMON_TMP"' EXIT

    local _
    for _ in $(seq 1 40); do
        if grep -q "logger-arg:arg-one" "$DAEMON_TMP/out.log" 2>/dev/null; then
            break
        fi
        sleep 0.1
    done
    kill -TERM "$DAEMON_PID"

    local out rc
    set +e
    wait "$DAEMON_PID"
    rc=$?
    set -e
    out="$(cat "$DAEMON_TMP/out.log")"

    assert_eq "$rc" "0"
    assert_contains "$out" "test_module/inst_one"
    assert_contains "$out" "logger-arg:arg-one"
    assert_not_contains "$out" "inst_two"
    assert_not_contains "$out" "arg-two"
    assert_file_contains "$DAEMON_TMP/notify.log" "inst_one"
    if grep -q "inst_two" "$DAEMON_TMP/notify.log"; then
        fail "a disabled module instance must not start"
    fi
}

test_disabled_modules_and_exit_hook() {
    DAEMON_TMP="$(mktemp -d)"
    trap 'rm -rf "$DAEMON_TMP"' EXIT
    copy_repo "$DAEMON_TMP"
    install_notify_recorder "$DAEMON_TMP"
    rm -rf "${DAEMON_TMP:?}/modules"/*
    install_daemon_module "$DAEMON_TMP"
    write_daemon_config "$DAEMON_TMP" false
    cat > "$DAEMON_TMP/onExit.sh" <<'EOF'
#!/bin/bash
printf 'exit hook ran\n' > "$EXIT_MARKER"
EOF

    local out rc
    set +e
    out="$(NOTIFY_LOG="$DAEMON_TMP/notify.log" EXIT_MARKER="$DAEMON_TMP/exit.marker" \
        timeout 5 bash "$DAEMON_TMP/run.sh" 2>&1)"
    rc=$?
    set -e

    assert_eq "$rc" "0"
    assert_not_contains "$out" "Running module:"
    assert_file_contains "$DAEMON_TMP/exit.marker" "exit hook ran"
}

test_run_script_helpers() {
    DAEMON_TMP="$(mktemp -d)"
    trap 'rm -rf "$DAEMON_TMP"' EXIT
    copy_repo "$DAEMON_TMP"

    local out
    out="$(bash "$DAEMON_TMP/run.sh" k8s)"
    assert_contains "$out" "kubectl apply -f -"
    assert_contains "$out" "logtfy-service-account-token"

    out="$(bash "$DAEMON_TMP/run.sh" role)"
    assert_contains "$out" "kind: ClusterRole"
    assert_contains "$out" "pod-log-reader"
}

run_test "daemon: crash loop and backoff" test_crash_loop_and_backoff
run_test "daemon: backoff cap" test_backoff_cap
run_test "daemon: stable module resets backoff" test_stable_resets_backoff
run_test "daemon: module instances" test_module_instances
run_test "daemon: disabled modules and shutdown hook" test_disabled_modules_and_exit_hook
run_test "daemon: k8s/role helper output" test_run_script_helpers
