#!/bin/bash
# Guard the Renovate policy: app repos extend the shared Infra preset and do
# not override automerge locally. The preset owns the non-major automerge and
# major dashboard-approval rules.
test_renovate_policy() {
    local cfg="$ROOT/renovate.json"

    assert_eq "$(jq -r '.extends | index("github>ImranR98/Infra//renovate-preset") != null' "$cfg")" "true"
    assert_eq "$(jq -r '[.. | objects | select(has("automerge"))] | length' "$cfg")" "0"
    assert_eq "$(jq -r '[.. | objects | select(has("platformAutomerge"))] | length' "$cfg")" "0"
}

run_test "policy: Renovate extends the shared preset" test_renovate_policy
