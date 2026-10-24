#!/bin/bash
# Guard the security-relevant Renovate policy: non-major updates may
# auto-merge only when the required test check exists; majors never may.
test_automerge_policy() {
    local cfg="$ROOT/renovate.json"

    assert_eq "$(jq -r '.automerge' "$cfg")" "false"
    assert_eq "$(jq -r '.separateMajorMinor' "$cfg")" "true"

    assert_eq "$(jq -r '[.packageRules[] | select(.automerge == true)] | length' "$cfg")" "1"
    assert_eq "$(jq -r '[.packageRules[] | select(.automerge == true) | .platformAutomerge] | unique | .[0]' "$cfg")" "true"
    assert_eq "$(jq -r '[.packageRules[] | select(.automerge == true) | .automergeType] | unique | .[0]' "$cfg")" "pr"
    assert_eq "$(jq -r '[.packageRules[] | select(.automerge == true) | .automergeStrategy] | unique | .[0]' "$cfg")" "squash"
    assert_eq "$(jq -r '[.packageRules[] | select(.automerge == true) | .ignoreTests] | unique | .[0]' "$cfg")" "false"
    assert_eq "$(jq -r '[.packageRules[] | select(.automerge == true) | .matchUpdateTypes[]] | sort | join(",")' "$cfg")" "digest,minor,patch,pin,pinDigest"

    assert_eq "$(jq -r '[.packageRules[] | select(.matchUpdateTypes? and (.matchUpdateTypes | index("major"))) | .automerge] | unique | .[0]' "$cfg")" "false"
    assert_eq "$(jq -r '[.packageRules[] | select(.matchUpdateTypes? and (.matchUpdateTypes | index("major"))) | .platformAutomerge] | unique | .[0]' "$cfg")" "false"
}

run_test "policy: Renovate non-major automerge, majors manual" test_automerge_policy
