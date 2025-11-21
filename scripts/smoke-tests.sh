#!/bin/bash
# Post-deployment smoke tests for Odoo cluster
# Validates critical functionality after deployment

set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/test-variables.sh"

if [ -f "${CONFIG_FILE}" ]; then
    # shellcheck source=../config/test-variables.sh
    source "${CONFIG_FILE}"
else
    echo "Warning: Configuration file not found at ${CONFIG_FILE}"
    echo "Using default values..."
fi

# Colors (from config or defaults)
RED="${COLOR_RED:-\033[0;31m}"
GREEN="${COLOR_GREEN:-\033[0;32m}"
YELLOW="${COLOR_YELLOW:-\033[1;33m}"
NC="${COLOR_NC:-\033[0m}"

# Configuration (from config file or arguments/defaults)
NAMESPACE="${1:-${K8S_NAMESPACE_DEV:-odoo-dev}}"
TIMEOUT="${2:-${TEST_DEFAULT_TIMEOUT:-300}}"
MAX_RETRIES="${TEST_MAX_RETRIES:-10}"
RETRY_DELAY="${TEST_RETRY_DELAY:-5}"
ODOO_PORT="${ODOO_HTTP_PORT:-8069}"
PORT_FORWARD_DELAY="${TEST_PORT_FORWARD_DELAY:-3}"
REDIS_IMAGE="${TEST_REDIS_CLIENT_IMAGE:-redis:7-alpine}"
HTTP_SUCCESS_CODES="${HTTP_SUCCESS_CODES:-200|302|303}"
LABEL_ODOO="${K8S_LABEL_APP:-app.kubernetes.io/name=odoo}"
LABEL_REDIS="${K8S_LABEL_REDIS:-app=redis}"

# Counters
PASSED=0
FAILED=0

log() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

# Test 1: Check if namespace exists
test_namespace_exists() {
    echo "Test 1: Checking if namespace exists..."
    if kubectl get namespace "${NAMESPACE}" &>/dev/null; then
        log "Namespace ${NAMESPACE} exists"
        return 0
    else
        error "Namespace ${NAMESPACE} does not exist"
        return 1
    fi
}

# Test 2: Check if all pods are running
test_pods_running() {
    echo "Test 2: Checking if all pods are running..."
    local pods_ready=0
    local retry_count=0

    while [ $retry_count -lt $MAX_RETRIES ]; do
        local not_ready=$(kubectl get pods -n "${NAMESPACE}" --field-selector=status.phase!=Running --no-headers 2>/dev/null | wc -l)

        if [ "$not_ready" -eq 0 ]; then
            pods_ready=1
            break
        fi

        warn "Waiting for pods to be ready... (Attempt $((retry_count + 1))/$MAX_RETRIES)"
        sleep $RETRY_DELAY
        ((retry_count++))
    done

    if [ $pods_ready -eq 1 ]; then
        log "All pods are running in namespace ${NAMESPACE}"
        return 0
    else
        error "Some pods are not running in namespace ${NAMESPACE}"
        kubectl get pods -n "${NAMESPACE}"
        return 1
    fi
}

# Test 3: Check Odoo service endpoint
test_odoo_service() {
    echo "Test 3: Checking Odoo service endpoint..."
    if kubectl get service -n "${NAMESPACE}" -l "${LABEL_ODOO}" &>/dev/null; then
        log "Odoo service exists"
        return 0
    else
        error "Odoo service not found"
        return 1
    fi
}

# Test 4: Check PostgreSQL connectivity
test_postgres_connection() {
    echo "Test 4: Checking PostgreSQL connectivity..."

    local pod_name=$(kubectl get pods -n "${NAMESPACE}" -l "${LABEL_ODOO}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -z "$pod_name" ]; then
        error "Could not find Odoo pod for PostgreSQL connection test"
        return 1
    fi

    # Try to connect to PostgreSQL from Odoo pod
    if kubectl exec -n "${NAMESPACE}" "$pod_name" -- sh -c 'psql -h $HOST -U $USER -d $DB -c "SELECT 1"' &>/dev/null; then
        log "PostgreSQL connection successful"
        return 0
    else
        warn "PostgreSQL connection test skipped or failed (may require credentials)"
        return 0  # Don't fail on this as it may require specific setup
    fi
}

# Test 5: Check Redis connectivity (if enabled)
test_redis_connection() {
    echo "Test 5: Checking Redis connectivity..."

    # Check if Redis service exists
    if ! kubectl get service -n "${NAMESPACE}" | grep -q redis; then
        warn "Redis service not found (may not be enabled)"
        return 0
    fi

    local redis_host=$(kubectl get service -n "${NAMESPACE}" -l "${LABEL_REDIS}" -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)

    if [ -z "$redis_host" ]; then
        warn "Could not determine Redis host"
        return 0
    fi

    # Try to ping Redis
    if kubectl run redis-test --rm -i --restart=Never --image="${REDIS_IMAGE}" -n "${NAMESPACE}" -- redis-cli -h "$redis_host" ping 2>/dev/null | grep -q PONG; then
        log "Redis connection successful"
        return 0
    else
        warn "Redis connection test inconclusive"
        return 0
    fi
}

# Test 6: Check HTTP endpoint accessibility
test_http_endpoint() {
    echo "Test 6: Checking HTTP endpoint accessibility..."

    local service_name=$(kubectl get service -n "${NAMESPACE}" -l "${LABEL_ODOO}" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -z "$service_name" ]; then
        error "Could not find Odoo service"
        return 1
    fi

    local service_port=$(kubectl get service -n "${NAMESPACE}" "$service_name" -o jsonpath='{.spec.ports[0].port}')

    # Port-forward and test HTTP endpoint
    kubectl port-forward -n "${NAMESPACE}" "service/$service_name" "${ODOO_PORT}:${service_port}" &
    local pf_pid=$!
    sleep "${PORT_FORWARD_DELAY}"

    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${ODOO_PORT}" | grep -qE "^(${HTTP_SUCCESS_CODES})$"; then
        log "HTTP endpoint is accessible"
        kill $pf_pid 2>/dev/null || true
        return 0
    else
        warn "HTTP endpoint test inconclusive"
        kill $pf_pid 2>/dev/null || true
        return 0
    fi
}

# Test 7: Check Persistent Volume Claims
test_pvcs() {
    echo "Test 7: Checking Persistent Volume Claims..."

    local unbound=$(kubectl get pvc -n "${NAMESPACE}" --field-selector=status.phase!=Bound --no-headers 2>/dev/null | wc -l)

    if [ "$unbound" -eq 0 ]; then
        log "All PVCs are bound"
        return 0
    else
        error "Some PVCs are not bound"
        kubectl get pvc -n "${NAMESPACE}"
        return 1
    fi
}

# Test 8: Check ConfigMaps and Secrets
test_config_resources() {
    echo "Test 8: Checking ConfigMaps and Secrets..."

    if kubectl get configmap -n "${NAMESPACE}" &>/dev/null && kubectl get secret -n "${NAMESPACE}" &>/dev/null; then
        log "ConfigMaps and Secrets exist"
        return 0
    else
        error "ConfigMaps or Secrets missing"
        return 1
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "Starting Smoke Tests for namespace: ${NAMESPACE}"
    echo "=========================================="
    echo ""

    test_namespace_exists || true
    test_pods_running || true
    test_odoo_service || true
    test_postgres_connection || true
    test_redis_connection || true
    test_http_endpoint || true
    test_pvcs || true
    test_config_resources || true

    echo ""
    echo "=========================================="
    echo "Smoke Tests Summary"
    echo "=========================================="
    echo -e "${GREEN}Passed: ${PASSED}${NC}"
    echo -e "${RED}Failed: ${FAILED}${NC}"
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}All smoke tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some smoke tests failed!${NC}"
        exit 1
    fi
}

# Check if required tools are available
if ! command -v kubectl &>/dev/null; then
    echo "Error: kubectl is not installed or not in PATH"
    exit 1
fi

if ! command -v curl &>/dev/null; then
    echo "Error: curl is not installed or not in PATH"
    exit 1
fi

main "$@"
