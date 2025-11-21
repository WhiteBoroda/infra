# Test Configuration

This directory contains centralized configuration for all test scripts and tools.

## Files

### test-variables.sh

Centralized bash configuration file containing all test-related variables.

**Usage in scripts:**
```bash
# Load configuration
CONFIG_FILE="${SCRIPT_DIR}/../config/test-variables.sh"
if [ -f "${CONFIG_FILE}" ]; then
    source "${CONFIG_FILE}"
fi
```

**Customization:**
You can override any variable by setting it in your environment before running tests:

```bash
# Override test retries
export TEST_MAX_RETRIES=20

# Override Odoo version
export ODOO_VERSION="16.0"

# Run tests
./scripts/smoke-tests.sh odoo-dev
```

## Variable Categories

### Test Execution Configuration
- `TEST_MAX_RETRIES` - Maximum number of retries for tests (default: 10)
- `TEST_RETRY_DELAY` - Delay between retries in seconds (default: 5)
- `TEST_DEFAULT_TIMEOUT` - Default test timeout in seconds (default: 300)
- `TEST_POD_READY_TIMEOUT` - Pod readiness timeout (default: 600)
- `TEST_PORT_FORWARD_DELAY` - Delay after port-forward (default: 3)

### Application Configuration
- `ODOO_APP_NAME` - Odoo application name (default: odoo)
- `ODOO_HTTP_PORT` - Odoo HTTP port (default: 8069)
- `ODOO_LONGPOLLING_PORT` - Odoo longpolling port (default: 8072)
- `ODOO_VERSION` - Odoo version (default: 17.0)
- `ODOO_IMAGE` - Odoo Docker image (default: odoo:17.0)
- `POSTGRES_VERSION` - PostgreSQL version (default: 15)
- `REDIS_VERSION` - Redis version (default: 7)

### Kubernetes Configuration
- `K8S_NAMESPACE_DEV` - Dev namespace (default: odoo-dev)
- `K8S_NAMESPACE_STAGE` - Stage namespace (default: odoo-stage)
- `K8S_NAMESPACE_PROD` - Prod namespace (default: odoo-prod)
- `K8S_LABEL_APP` - Odoo label selector (default: app.kubernetes.io/name=odoo)
- `K8S_LABEL_REDIS` - Redis label selector (default: app=redis)

### Docker/Container Configuration
- `TEST_BUSYBOX_IMAGE` - Busybox image for tests (default: busybox:latest)
- `TEST_REDIS_CLIENT_IMAGE` - Redis client image (default: redis:7-alpine)
- `TEST_POSTGRES_CLIENT_IMAGE` - PostgreSQL client image (default: postgres:15)
- `ODOO_CONFIG_DIR` - Odoo config directory (default: /etc/odoo)
- `ODOO_ADDONS_DIR` - Odoo addons directory (default: /mnt/extra-addons)

### CI/CD Configuration
- `HELM_VERSION` - Helm version (default: 3.13.0)
- `KUBECTL_VERSION` - Kubectl version (default: 1.28.0)
- `HELM_TIMEOUT_DEV` - Dev deployment timeout (default: 10m)
- `HELM_TIMEOUT_STAGE` - Stage deployment timeout (default: 15m)
- `HELM_TIMEOUT_PROD` - Prod deployment timeout (default: 20m)

## Helper Functions

### validate_test_environment()
Validates that required test environment variables are set.

```bash
source config/test-variables.sh
validate_test_environment
```

### print_test_config()
Prints current test configuration to console.

```bash
source config/test-variables.sh
print_test_config
```

## Integration with Test Tools

### Smoke Tests
`scripts/smoke-tests.sh` automatically loads this configuration.

### BATS Tests
BATS test files in `scripts/tests/` load this configuration in their `setup()` function.

### Molecule Tests
Molecule configurations support environment variables:
- `MOLECULE_DRIVER` - Molecule driver (default: docker)
- `MOLECULE_TEST_IMAGE` - Test container image
- `MOLECULE_INSTANCE_NAME` - Test instance name
- `MOLECULE_ANSIBLE_USER` - Ansible user (default: root)

### Container Structure Tests
Use `docker/tests/generate-container-test-config.sh` to generate configuration from template with current variables.

### Helm Tests
Helm test templates use values from `k8s/charts/odoo/values.yaml` under the `tests:` section.

## Environment-Specific Configuration

For environment-specific overrides, create environment files:

```bash
# config/test-variables-dev.sh
export K8S_NAMESPACE_DEV="my-custom-dev"
export TEST_MAX_RETRIES=5

# Source in your script
source config/test-variables.sh
source config/test-variables-dev.sh
```

## Best Practices

1. **Never hardcode values** - Always use variables from this configuration
2. **Provide defaults** - Use `${VAR:-default}` pattern for all variables
3. **Document changes** - Update this README when adding new variables
4. **Environment isolation** - Use separate namespaces for different environments
5. **Version consistency** - Keep versions in sync across all components

## Examples

### Running tests with custom configuration

```bash
# Set custom values
export TEST_MAX_RETRIES=15
export ODOO_VERSION="16.0"
export K8S_NAMESPACE_DEV="odoo-dev-custom"

# Run smoke tests
./scripts/smoke-tests.sh

# Run BATS tests
cd scripts && bats tests/

# Generate container test config
./docker/tests/generate-container-test-config.sh
```

### Using in new test scripts

```bash
#!/bin/bash
set -euo pipefail

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/test-variables.sh"

if [ -f "${CONFIG_FILE}" ]; then
    source "${CONFIG_FILE}"
fi

# Use variables
echo "Testing Odoo ${ODOO_VERSION}"
echo "Namespace: ${K8S_NAMESPACE_DEV}"
echo "Max retries: ${TEST_MAX_RETRIES}"

# Your test logic here
```

## Troubleshooting

### Variables not being loaded

Check that you're sourcing the file correctly:
```bash
source config/test-variables.sh
echo "Loaded: ${ODOO_VERSION}"
```

### Override not working

Ensure you're exporting the variable:
```bash
export ODOO_VERSION="16.0"  # Correct
ODOO_VERSION="16.0"         # Won't work for child processes
```

### Path issues

Use absolute paths or resolve relative to script directory:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/test-variables.sh"
```
