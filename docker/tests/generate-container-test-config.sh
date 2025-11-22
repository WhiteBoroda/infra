#!/bin/bash
# Generate container-structure-test.yaml from template with variables
# Usage: ./generate-container-test-config.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/container-structure-test.yaml.template"
OUTPUT_FILE="${SCRIPT_DIR}/container-structure-test.yaml"
CONFIG_FILE="${SCRIPT_DIR}/../../config/test-variables.sh"

# Load configuration
if [ -f "${CONFIG_FILE}" ]; then
    # shellcheck source=../../config/test-variables.sh
    source "${CONFIG_FILE}"
fi

# Set defaults for container tests
export ODOO_VERSION="${ODOO_VERSION:-17.0}"
export ODOO_HTTP_PORT="${ODOO_HTTP_PORT:-8069}"
export ODOO_LONGPOLLING_PORT="${ODOO_LONGPOLLING_PORT:-8072}"
export ODOO_CONFIG_DIR="${ODOO_CONFIG_DIR:-/etc/odoo}"
export ODOO_CONFIG_FILE="${ODOO_CONFIG_FILE:-/etc/odoo/odoo.conf}"
export ODOO_ADDONS_DIR="${ODOO_ADDONS_DIR:-/mnt/extra-addons}"
export ODOO_LOG_DIR="${ODOO_LOG_DIR:-/var/log/odoo}"
export ODOO_WORKDIR="${ODOO_WORKDIR:-/usr/lib/python3/dist-packages/odoo}"
export PYTHON_SITE_PACKAGES="${PYTHON_SITE_PACKAGES:-/usr/local/lib/python3.11/site-packages}"

echo "Generating container test configuration from template..."
echo "Template: ${TEMPLATE_FILE}"
echo "Output: ${OUTPUT_FILE}"
echo ""
echo "Using variables:"
echo "  ODOO_VERSION: ${ODOO_VERSION}"
echo "  ODOO_HTTP_PORT: ${ODOO_HTTP_PORT}"
echo "  ODOO_LONGPOLLING_PORT: ${ODOO_LONGPOLLING_PORT}"
echo "  ODOO_CONFIG_DIR: ${ODOO_CONFIG_DIR}"
echo "  ODOO_ADDONS_DIR: ${ODOO_ADDONS_DIR}"
echo ""

# Use envsubst to replace variables in template
envsubst < "${TEMPLATE_FILE}" > "${OUTPUT_FILE}"

echo "✓ Configuration generated successfully at ${OUTPUT_FILE}"
