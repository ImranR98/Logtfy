#!/bin/bash
# Guard the Renovate policy: this repo does not automerge; the Infra
# renovate-daily job merges only after the required test check succeeds.
test_renovate_policy() {
    local cfg="$ROOT/renovate.json"

    assert_eq "$(jq -r '[.. | objects | select(has("automerge"))] | length' "$cfg")" "0"
    assert_eq "$(jq -r '[.. | objects | select(has("platformAutomerge"))] | length' "$cfg")" "0"
    assert_eq "$(jq -r '[.. | objects | select(has("automergeType"))] | length' "$cfg")" "0"
    assert_eq "$(jq -r '[.. | objects | select(has("automergeStrategy"))] | length' "$cfg")" "0"

    assert_eq "$(jq -r '.osvVulnerabilityAlerts' "$cfg")" "true"
    assert_eq "$(jq -r '.dependencyDashboard' "$cfg")" "true"
    assert_eq "$(jq -r '.rangeStrategy' "$cfg")" "replace"
    assert_eq "$(jq -r '.minimumReleaseAge' "$cfg")" "3 days"
    assert_eq "$(jq -r '.separateMajorMinor' "$cfg")" "true"
    assert_eq "$(jq -r '.extends | index("security:minimumReleaseAgeNpm") != null' "$cfg")" "true"
    assert_eq "$(jq -r '.extends | index("helpers:pinGitHubActionDigests") != null' "$cfg")" "true"
}

run_test "policy: Renovate defers merges to the Infra daily helper" test_renovate_policy
