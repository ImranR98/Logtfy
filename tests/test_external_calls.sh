#!/bin/bash
# External integrations are faked here: Docker CLI, journalctl, nc, and the
# Kubernetes API (curl). The daemon should make the same decisions without a
# live socket, journal, network, or cluster.

make_fake_docker() {
    local dir="$1"
    cat > "$dir/docker" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"
echo "docker-stdout $*"
echo "docker-stderr $*" >&2
EOF
    chmod +x "$dir/docker"
}

run_docker_helper() {
    local mode="$1"
    local container="$2"
    DOCKER_BIN="$FAKE_DOCKER_DIR/docker" FAKE_DOCKER_LOG="$FAKE_DOCKER_LOG" \
        bash -c 'source "$1/helpers/stream_docker_logs.sh" "$2" "$3"' _ "$ROOT" "$container" "$mode"
}

test_docker_log_modes() {
    EXTERNAL_TMP="$(mktemp -d)"
    trap 'rm -rf "$EXTERNAL_TMP"' EXIT
    FAKE_DOCKER_DIR="$EXTERNAL_TMP/bin"
    FAKE_DOCKER_LOG="$EXTERNAL_TMP/docker.log"
    mkdir -p "$FAKE_DOCKER_DIR"
    make_fake_docker "$FAKE_DOCKER_DIR"

    local out
    out="$(run_docker_helper "" demo 2>&1)"
    assert_contains "$out" "docker-stdout logs -f --since 0m demo"
    assert_not_contains "$out" "docker-stderr"

    out="$(run_docker_helper stderr2stdout demo 2>&1)"
    assert_contains "$out" "docker-stdout logs -f --since 0m demo"
    assert_contains "$out" "docker-stderr logs -f --since 0m demo"

    out="$(run_docker_helper printstderr demo 2>&1)"
    assert_contains "$out" "docker-stderr logs -f --since 0m demo"

    assert_eq "$(cat "$FAKE_DOCKER_LOG")" "$(printf 'logs -f --since 0m demo\nlogs -f --since 0m demo\nlogs -f --since 0m demo')"
}

test_docker_module_loggers() {
    EXTERNAL_TMP="$(mktemp -d)"
    trap 'rm -rf "$EXTERNAL_TMP"' EXIT
    FAKE_DOCKER_DIR="$EXTERNAL_TMP/bin"
    FAKE_DOCKER_LOG="$EXTERNAL_TMP/docker.log"
    mkdir -p "$FAKE_DOCKER_DIR"
    make_fake_docker "$FAKE_DOCKER_DIR"

    local out
    out="$(DOCKER_BIN="$FAKE_DOCKER_DIR/docker" FAKE_DOCKER_LOG="$FAKE_DOCKER_LOG" \
        bash "$ROOT/modules/authelia_logins/logger.sh" authelia 2>&1)"
    assert_contains "$out" "logs -f --since 0m authelia"

    out="$(DOCKER_BIN="$FAKE_DOCKER_DIR/docker" FAKE_DOCKER_LOG="$FAKE_DOCKER_LOG" \
        bash "$ROOT/modules/generic_logs/logger.sh" "demo printstderr" 2>&1)"
    assert_contains "$out" "docker-stderr logs -f --since 0m demo"

    local fail_out
    if fail_out="$(DOCKER_BIN="$FAKE_DOCKER_DIR/docker" FAKE_DOCKER_LOG="$FAKE_DOCKER_LOG" \
        bash "$ROOT/modules/generic_logs/logger.sh" "k8s" 2>&1)"; then
        fail "expected an empty k8s service name to exit non-zero"
    fi
    assert_contains "$fail_out" "Service name not specified"
}

test_journalctl_logger() {
    EXTERNAL_TMP="$(mktemp -d)"
    trap 'rm -rf "$EXTERNAL_TMP"' EXIT
    cat > "$EXTERNAL_TMP/journalctl" <<'EOF'
#!/bin/bash
printf '%s' "$*" > "$FAKE_JOURNAL_LOG"
echo "journal-line"
EOF
    chmod +x "$EXTERNAL_TMP/journalctl"

    local out
    out="$(JOURNALCTL_BIN="$EXTERNAL_TMP/journalctl" FAKE_JOURNAL_LOG="$EXTERNAL_TMP/journal.log" \
        bash "$ROOT/modules/ssh_logins/logger.sh" sshd 2>&1)"
    assert_contains "$out" "journal-line"
    assert_eq "$(cat "$EXTERNAL_TMP/journal.log")" "-D /var/log/journal -S now -fu sshd"
}

test_port_checker_logger() {
    EXTERNAL_TMP="$(mktemp -d)"
    trap 'rm -rf "$EXTERNAL_TMP"' EXIT
    cat > "$EXTERNAL_TMP/nc" <<'EOF'
#!/bin/bash
n=0
if [ -f "$NC_STATE" ]; then
    n="$(cat "$NC_STATE")"
fi
n=$((n + 1))
echo "$n" > "$NC_STATE"
if [ "$n" -le 1 ]; then
    exit 1
fi
exit 0
EOF
    chmod +x "$EXTERNAL_TMP/nc"

    local out rc
    set +e
    out="$(PATH="$EXTERNAL_TMP:$PATH" NC_STATE="$EXTERNAL_TMP/nc.state" \
        timeout 2 bash "$ROOT/modules/port_checker/logger.sh" "example.org 443 0.05" 2>&1)"
    rc=$?
    set -e
    assert_eq "$rc" "124"
    assert_contains "$out" "Port 443 on example.org is closed!"
    assert_contains "$out" "Port 443 on example.org is open!"
}

test_k8s_stream() {
    EXTERNAL_TMP="$(mktemp -d)"
    trap 'rm -rf "$EXTERNAL_TMP"' EXIT
    copy_repo "$EXTERNAL_TMP"
    mkdir -p "$EXTERNAL_TMP/bin"
    echo "test-token" > "$EXTERNAL_TMP/k8s/token"
    echo "test-ca" > "$EXTERNAL_TMP/k8s/ca.crt"

    cat > "$EXTERNAL_TMP/bin/curl" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "$FAKE_CURL_LOG"
case "$*" in
    *"/pods?labelSelector="*)
        sleep 0.01
        echo '{"items":[{"metadata":{"name":"pod-a"}}]}'
        ;;
    *"/log?follow=true"*)
        sleep 0.2
        echo "streamed log line"
        ;;
    *)
        echo "unexpected curl invocation: $*" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$EXTERNAL_TMP/bin/curl"

    local out rc
    set +e
    out="$(PATH="$EXTERNAL_TMP/bin:$PATH" FAKE_CURL_LOG="$EXTERNAL_TMP/curl.log" \
        KUBE_API_SERVER="https://kube.test" \
        timeout 2 bash "$EXTERNAL_TMP/k8s/stream_service_logs.sh" "myservice myns" 2>&1)"
    rc=$?
    set -e
    assert_eq "$rc" "124"
    assert_contains "$out" "streamed log line"
    assert_file_contains "$EXTERNAL_TMP/curl.log" "namespaces/myns/pods?labelSelector=app.kubernetes.io/name=myservice"
    assert_file_contains "$EXTERNAL_TMP/curl.log" "pods/pod-a/log?follow=true&sinceSeconds=3"
}

test_k8s_no_pods() {
    EXTERNAL_TMP="$(mktemp -d)"
    trap 'rm -rf "$EXTERNAL_TMP"' EXIT
    copy_repo "$EXTERNAL_TMP"
    mkdir -p "$EXTERNAL_TMP/bin"
    echo "test-token" > "$EXTERNAL_TMP/k8s/token"
    echo "test-ca" > "$EXTERNAL_TMP/k8s/ca.crt"
    cat > "$EXTERNAL_TMP/bin/curl" <<'EOF'
#!/bin/bash
echo '{"items":[]}'
EOF
    chmod +x "$EXTERNAL_TMP/bin/curl"

    local out rc
    set +e
    out="$(PATH="$EXTERNAL_TMP/bin:$PATH" KUBE_API_SERVER="https://kube.test" \
        timeout 2 bash "$EXTERNAL_TMP/k8s/stream_service_logs.sh" "missing default" 2>&1)"
    rc=$?
    set -e
    assert_eq "$rc" "124"
    assert_contains "$out" "No pods found for 'missing' in namespace 'default'"
}

test_k8s_prefilter() {
    EXTERNAL_TMP="$(mktemp -d)"
    trap 'rm -rf "$EXTERNAL_TMP"' EXIT
    copy_repo "$EXTERNAL_TMP"
    mkdir -p "$EXTERNAL_TMP/bin"
    echo "test-token" > "$EXTERNAL_TMP/k8s/token"
    echo "test-ca" > "$EXTERNAL_TMP/k8s/ca.crt"
    cat > "$EXTERNAL_TMP/bin/curl" <<'EOF'
#!/bin/bash
case "$*" in
    *"/pods?labelSelector="*)
        echo '{"items":[{"metadata":{"name":"pod-a"}}]}'
        ;;
    *"/log?follow=true"*)
        sleep 0.2
        echo "keep error line"
        echo "drop info line"
        ;;
    *)
        exit 1
        ;;
esac
EOF
    chmod +x "$EXTERNAL_TMP/bin/curl"

    local out rc
    set +e
    out="$(PATH="$EXTERNAL_TMP/bin:$PATH" KUBE_API_SERVER="https://kube.test" \
        timeout 2 bash "$EXTERNAL_TMP/modules/traefik_accesslogs_custom_k8s/logger.sh" "myns traefik" "error" 2>&1)"
    rc=$?
    set -e
    assert_eq "$rc" "124"
    assert_contains "$out" "keep error line"
    assert_not_contains "$out" "drop info line"
}

run_test "external: docker log modes" test_docker_log_modes
run_test "external: docker module loggers" test_docker_module_loggers
run_test "external: journalctl logger" test_journalctl_logger
run_test "external: port checker logger" test_port_checker_logger
run_test "external: kubernetes stream" test_k8s_stream
run_test "external: kubernetes no pods" test_k8s_no_pods
run_test "external: kubernetes prefilter" test_k8s_prefilter
