#!/bin/bash
# Bash line coverage is not measured: there is no portable, maintained
# line-coverage tool for shell scripts that works with the tests' temp-copy
# fixtures and spawned processes without adding a Ruby/kcov runtime. Instead,
# enforce module-level coverage: every module must have both scripts and be
# referenced by the test suite. A new module without tests fails the gate.
test_module_coverage_manifest() {
    local dir module helper missing=0

    for dir in "$ROOT"/modules/*; do
        [ -d "$dir" ] || continue
        module="$(basename "$dir")"
        for script in logger.sh parser.sh; do
            if [ ! -f "$dir/$script" ]; then
                echo "module '$module' is missing $script" >&2
                missing=1
            elif ! bash -n "$dir/$script"; then
                echo "module '$module/$script' has a syntax error" >&2
                missing=1
            fi
        done
        if ! grep -Rqs --include='*.sh' -- "$module" "$ROOT/tests"; then
            echo "module '$module' is not referenced by any test" >&2
            missing=1
        fi
    done

    for helper in \
        configParser.js \
        notify.js \
        run.sh \
        runModule.sh \
        helpers/stream_docker_logs.sh \
        k8s/stream_service_logs.sh; do
        if ! grep -Rqs -- "$helper" "$ROOT/tests"; then
            echo "core file '$helper' is not referenced by any test" >&2
            missing=1
        fi
    done

    [ "$missing" -eq 0 ]
}

test_ci_gate_contract() {
    local workflow="$ROOT/.github/workflows/ci.yml"

    assert_file_contains "$workflow" "shellcheck --severity=warning"
    assert_file_contains "$workflow" "bash tests/run-tests.sh"
    assert_file_contains "$workflow" "Reject skipped tests"
    assert_file_contains "$workflow" "Smoke production image"
    assert_file_contains "$workflow" "needs: test"
}

run_test "coverage: every module has tested logger/parser" test_module_coverage_manifest
run_test "coverage: CI gate contract" test_ci_gate_contract
