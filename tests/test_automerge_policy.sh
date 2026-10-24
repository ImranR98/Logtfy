#!/bin/bash
# Guard the security-relevant Renovate policy: every update, including
# majors, may auto-merge only after the required test check passes.
test_automerge_policy() {
    local cfg="$ROOT/renovate.json"

    assert_eq "$(jq -r '.automerge' "$cfg")" "false"
    assert_eq "$(jq -r '.separateMajorMinor' "$cfg")" "true"

    assert_eq "$(jq -r '[.packageRules[] | select(.automerge == true)] | length' "$cfg")" "2"
    assert_eq "$(jq -r '[.packageRules[] | select(.automerge == true) | .platformAutomerge] | unique | .[0]' "$cfg")" "true"
    assert_eq "$(jq -r '[.packageRules[] | select(.automerge == true) | .automergeType] | unique | .[0]' "$cfg")" "pr"
    assert_eq "$(jq -r '[.packageRules[] | select(.automerge == true) | .automergeStrategy] | unique | .[0]' "$cfg")" "squash"
    assert_eq "$(jq -r '[.packageRules[] | select(.automerge == true) | .ignoreTests] | unique | .[0]' "$cfg")" "false"
    assert_eq "$(jq -r '[.packageRules[] | select(.automerge == true) | .matchUpdateTypes[]] | sort | unique | join(",")' "$cfg")" "digest,major,minor,patch,pin,pinDigest"

    assert_eq "$(jq -r '[.packageRules[] | select(.matchUpdateTypes? and (.matchUpdateTypes | index("major"))) | .automerge] | unique | .[0]' "$cfg")" "true"
    assert_eq "$(jq -r '[.packageRules[] | select(.matchUpdateTypes? and (.matchUpdateTypes | index("major"))) | .platformAutomerge] | unique | .[0]' "$cfg")" "true"
}

run_test "policy: Renovate automerge all tested updates, including majors" test_automerge_policy
