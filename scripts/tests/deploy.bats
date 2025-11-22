#!/usr/bin/env bats
# BATS tests for deploy.sh script

# Setup - runs before each test
setup() {
    # Load the script path
    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    DEPLOY_SCRIPT="${SCRIPT_DIR}/deploy.sh"

    # Load test configuration
    CONFIG_FILE="${SCRIPT_DIR}/../config/test-variables.sh"
    if [ -f "${CONFIG_FILE}" ]; then
        # shellcheck source=../../config/test-variables.sh
        source "${CONFIG_FILE}"
    fi

    # Mock helm and kubectl for testing
    export PATH="${BATS_TEST_DIRNAME}/mocks:${PATH}"
}

# Test: Script exists and is executable
@test "deploy.sh exists and is executable" {
    [ -f "${DEPLOY_SCRIPT}" ]
    [ -x "${DEPLOY_SCRIPT}" ]
}

# Test: Help message displays correctly
@test "deploy.sh shows help with -h flag" {
    run bash "${DEPLOY_SCRIPT}" -h
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "Usage:" ]]
    [[ "${output}" =~ "OPTIONS:" ]]
}

# Test: Help message displays with --help flag
@test "deploy.sh shows help with --help flag" {
    run bash "${DEPLOY_SCRIPT}" --help
    [ "$status" -eq 0 ]
    [[ "${output}" =~ "Deploy Odoo to Kubernetes cluster" ]]
}

# Test: Script fails without environment argument
@test "deploy.sh fails without environment argument" {
    run bash "${DEPLOY_SCRIPT}"
    [ "$status" -ne 0 ]
}

# Test: Script validates environment values
@test "deploy.sh validates environment parameter" {
    run bash "${DEPLOY_SCRIPT}" -e invalid_env
    [ "$status" -ne 0 ]
    [[ "${output}" =~ "ERROR" ]] || [[ "${output}" =~ "Invalid" ]]
}

# Test: Script accepts valid dev environment
@test "deploy.sh accepts dev environment" {
    # Skip actual deployment, just test argument parsing
    run bash -c "source ${DEPLOY_SCRIPT} 2>&1 | head -5" -e dev
    # We expect it to at least parse the argument without immediate error
    # This test will need mocking for full validation
    skip "Requires kubectl/helm mocking"
}

# Test: Script accepts valid stage environment
@test "deploy.sh accepts stage environment" {
    skip "Requires kubectl/helm mocking"
}

# Test: Script accepts valid prod environment
@test "deploy.sh accepts prod environment" {
    skip "Requires kubectl/helm mocking"
}

# Test: Check for required commands (basic syntax check)
@test "deploy.sh has valid bash syntax" {
    run bash -n "${DEPLOY_SCRIPT}"
    [ "$status" -eq 0 ]
}

# Test: Script contains necessary functions
@test "deploy.sh defines required functions" {
    run grep -q "^log()" "${DEPLOY_SCRIPT}"
    [ "$status" -eq 0 ]

    run grep -q "^error()" "${DEPLOY_SCRIPT}"
    [ "$status" -eq 0 ]

    run grep -q "^usage()" "${DEPLOY_SCRIPT}"
    [ "$status" -eq 0 ]
}

# Test: Script uses set -e for error handling
@test "deploy.sh uses strict error handling" {
    run grep -q "set -euo pipefail" "${DEPLOY_SCRIPT}"
    [ "$status" -eq 0 ]
}

# Test: Script has proper shebang
@test "deploy.sh has correct shebang" {
    run head -n 1 "${DEPLOY_SCRIPT}"
    [[ "${output}" =~ "#!/bin/bash" ]]
}
