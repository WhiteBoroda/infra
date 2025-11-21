#!/usr/bin/env bats
# BATS tests for setup-infrastructure.sh script

setup() {
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    SETUP_SCRIPT="${SCRIPT_DIR}/setup-infrastructure.sh"
}

@test "setup-infrastructure.sh exists and is executable" {
    [ -f "${SETUP_SCRIPT}" ]
    [ -x "${SETUP_SCRIPT}" ]
}

@test "setup-infrastructure.sh has valid bash syntax" {
    run bash -n "${SETUP_SCRIPT}"
    [ "$status" -eq 0 ]
}

@test "setup-infrastructure.sh has correct shebang" {
    run head -n 1 "${SETUP_SCRIPT}"
    [[ "${output}" =~ "#!/bin/bash" ]]
}

@test "setup-infrastructure.sh uses error handling" {
    run grep -E "set -[euo]" "${SETUP_SCRIPT}"
    [ "$status" -eq 0 ]
}

@test "setup-infrastructure.sh contains main stages" {
    # Check for key infrastructure setup stages
    run grep -i "terraform" "${SETUP_SCRIPT}"
    [ "$status" -eq 0 ]

    run grep -i "ansible" "${SETUP_SCRIPT}"
    [ "$status" -eq 0 ]
}
