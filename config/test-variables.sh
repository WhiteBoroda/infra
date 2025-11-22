#!/bin/bash
# Centralized test configuration variables
# Source this file in your test scripts: source config/test-variables.sh

# ============================================
# Test Execution Configuration
# ============================================

# Retry and timeout settings
export TEST_MAX_RETRIES="${TEST_MAX_RETRIES:-10}"
export TEST_RETRY_DELAY="${TEST_RETRY_DELAY:-5}"
export TEST_DEFAULT_TIMEOUT="${TEST_DEFAULT_TIMEOUT:-300}"
export TEST_POD_READY_TIMEOUT="${TEST_POD_READY_TIMEOUT:-600}"
export TEST_PORT_FORWARD_DELAY="${TEST_PORT_FORWARD_DELAY:-3}"

# ============================================
# Application Configuration
# ============================================

# Odoo settings
export ODOO_APP_NAME="${ODOO_APP_NAME:-odoo}"
export ODOO_HTTP_PORT="${ODOO_HTTP_PORT:-8069}"
export ODOO_LONGPOLLING_PORT="${ODOO_LONGPOLLING_PORT:-8072}"
export ODOO_VERSION="${ODOO_VERSION:-17.0}"
export ODOO_IMAGE="${ODOO_IMAGE:-odoo:17.0}"

# PostgreSQL settings
export POSTGRES_VERSION="${POSTGRES_VERSION:-15}"
export POSTGRES_IMAGE="${POSTGRES_IMAGE:-postgres:15}"
export POSTGRES_DEFAULT_PORT="${POSTGRES_DEFAULT_PORT:-5432}"

# Redis settings
export REDIS_VERSION="${REDIS_VERSION:-7}"
export REDIS_IMAGE="${REDIS_IMAGE:-redis:7-alpine}"
export REDIS_DEFAULT_PORT="${REDIS_DEFAULT_PORT:-6379}"

# ============================================
# Kubernetes Configuration
# ============================================

# Namespace defaults
export K8S_NAMESPACE_DEV="${K8S_NAMESPACE_DEV:-odoo-dev}"
export K8S_NAMESPACE_STAGE="${K8S_NAMESPACE_STAGE:-odoo-stage}"
export K8S_NAMESPACE_PROD="${K8S_NAMESPACE_PROD:-odoo-prod}"
export K8S_NAMESPACE_TEST="${K8S_NAMESPACE_TEST:-test-odoo}"

# Kubernetes label selectors
export K8S_LABEL_APP="${K8S_LABEL_APP:-app.kubernetes.io/name=odoo}"
export K8S_LABEL_REDIS="${K8S_LABEL_REDIS:-app=redis}"
export K8S_LABEL_POSTGRES="${K8S_LABEL_POSTGRES:-app=postgresql}"

# Kubernetes resource names
export K8S_SERVICE_NAME_PREFIX="${K8S_SERVICE_NAME_PREFIX:-odoo}"

# ============================================
# HTTP Testing Configuration
# ============================================

# Expected HTTP status codes for health checks
export HTTP_SUCCESS_CODES="${HTTP_SUCCESS_CODES:-200|302|303}"
export HTTP_TIMEOUT="${HTTP_TIMEOUT:-10}"

# Test endpoints
export ODOO_HEALTH_ENDPOINT="${ODOO_HEALTH_ENDPOINT:-/web/database/selector}"
export ODOO_LOGIN_ENDPOINT="${ODOO_LOGIN_ENDPOINT:-/web/login}"

# ============================================
# Docker/Container Configuration
# ============================================

# Test container images
export TEST_BUSYBOX_IMAGE="${TEST_BUSYBOX_IMAGE:-busybox:latest}"
export TEST_CURL_IMAGE="${TEST_CURL_IMAGE:-curlimages/curl:latest}"
export TEST_POSTGRES_CLIENT_IMAGE="${TEST_POSTGRES_CLIENT_IMAGE:-postgres:15}"
export TEST_REDIS_CLIENT_IMAGE="${TEST_REDIS_CLIENT_IMAGE:-redis:7-alpine}"

# ============================================
# Ansible/Molecule Configuration
# ============================================

# Molecule test container image
export MOLECULE_TEST_IMAGE="${MOLECULE_TEST_IMAGE:-geerlingguy/docker-ubuntu2204-ansible:latest}"
export MOLECULE_DRIVER="${MOLECULE_DRIVER:-docker}"

# ============================================
# CI/CD Configuration
# ============================================

# Helm configuration
export HELM_VERSION="${HELM_VERSION:-3.13.0}"
export HELM_TIMEOUT_DEV="${HELM_TIMEOUT_DEV:-10m}"
export HELM_TIMEOUT_STAGE="${HELM_TIMEOUT_STAGE:-15m}"
export HELM_TIMEOUT_PROD="${HELM_TIMEOUT_PROD:-20m}"

# Kubectl version
export KUBECTL_VERSION="${KUBECTL_VERSION:-1.28.0}"

# ============================================
# Test Artifacts Configuration
# ============================================

# Report directories
export TEST_REPORTS_DIR="${TEST_REPORTS_DIR:-./test-reports}"
export TEST_COVERAGE_DIR="${TEST_COVERAGE_DIR:-./coverage}"
export TEST_ARTIFACTS_DIR="${TEST_ARTIFACTS_DIR:-./artifacts}"

# ============================================
# Color Configuration (for terminal output)
# ============================================

export COLOR_RED="${COLOR_RED:-\033[0;31m}"
export COLOR_GREEN="${COLOR_GREEN:-\033[0;32m}"
export COLOR_YELLOW="${COLOR_YELLOW:-\033[1;33m}"
export COLOR_BLUE="${COLOR_BLUE:-\033[0;34m}"
export COLOR_NC="${COLOR_NC:-\033[0m}"

# ============================================
# Path Configuration
# ============================================

# Project paths
export PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export SCRIPTS_DIR="${SCRIPTS_DIR:-${PROJECT_ROOT}/scripts}"
export CONFIG_DIR="${CONFIG_DIR:-${PROJECT_ROOT}/config}"
export K8S_DIR="${K8S_DIR:-${PROJECT_ROOT}/k8s}"
export ANSIBLE_DIR="${ANSIBLE_DIR:-${PROJECT_ROOT}/ansible}"
export TERRAFORM_DIR="${TERRAFORM_DIR:-${PROJECT_ROOT}/terraform}"

# ============================================
# Functions
# ============================================

# Function to validate required variables
validate_test_environment() {
    local required_vars=(
        "TEST_MAX_RETRIES"
        "TEST_RETRY_DELAY"
        "ODOO_HTTP_PORT"
        "K8S_NAMESPACE_DEV"
    )

    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "ERROR: Missing required environment variables: ${missing_vars[*]}"
        return 1
    fi

    return 0
}

# Function to print current test configuration
print_test_config() {
    echo "=========================================="
    echo "Test Configuration"
    echo "=========================================="
    echo "Test Retries: ${TEST_MAX_RETRIES}"
    echo "Retry Delay: ${TEST_RETRY_DELAY}s"
    echo "Test Timeout: ${TEST_DEFAULT_TIMEOUT}s"
    echo "Odoo Port: ${ODOO_HTTP_PORT}"
    echo "Odoo Version: ${ODOO_VERSION}"
    echo "PostgreSQL Version: ${POSTGRES_VERSION}"
    echo "Redis Version: ${REDIS_VERSION}"
    echo "Namespace (Dev): ${K8S_NAMESPACE_DEV}"
    echo "Namespace (Stage): ${K8S_NAMESPACE_STAGE}"
    echo "Namespace (Prod): ${K8S_NAMESPACE_PROD}"
    echo "=========================================="
}

# Export functions
export -f validate_test_environment
export -f print_test_config

# Container paths and configuration
export ODOO_CONFIG_DIR="${ODOO_CONFIG_DIR:-/etc/odoo}"
export ODOO_CONFIG_FILE="${ODOO_CONFIG_FILE:-/etc/odoo/odoo.conf}"
export ODOO_ADDONS_DIR="${ODOO_ADDONS_DIR:-/mnt/extra-addons}"
export ODOO_LOG_DIR="${ODOO_LOG_DIR:-/var/log/odoo}"
export ODOO_WORKDIR="${ODOO_WORKDIR:-/usr/lib/python3/dist-packages/odoo}"
export PYTHON_SITE_PACKAGES="${PYTHON_SITE_PACKAGES:-/usr/local/lib/python3.11/site-packages}"
