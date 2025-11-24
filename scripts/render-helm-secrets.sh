#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <environment>"
  echo "Supported environments: dev, stage, prod"
  exit 1
fi

ENVIRONMENT="$1"
OVERLAY_DIR="k8s/overlays/${ENVIRONMENT}"
DEFAULT_SECRET_FILE="${OVERLAY_DIR}/values-secrets.yaml"
CI_SECRET_FILE="${OVERLAY_DIR}/values-secrets.ci.yaml"

if [[ ! -d "$OVERLAY_DIR" ]]; then
  echo "Unknown environment '${ENVIRONMENT}'. Expected directory ${OVERLAY_DIR}." >&2
  exit 1
fi

# If a user-managed secret file exists locally, prefer it.
if [[ -f "$DEFAULT_SECRET_FILE" ]]; then
  echo "$DEFAULT_SECRET_FILE"
  exit 0
fi

ENV_UPPER=$(echo "$ENVIRONMENT" | tr '[:lower:]' '[:upper:]')
B64_SECRET_VAR="${ENV_UPPER}_VALUES_SECRETS_B64"
B64_SECRET_VALUE="${!B64_SECRET_VAR:-}"

if [[ -z "$B64_SECRET_VALUE" ]]; then
  cat >&2 <<EOF
Required environment variables are missing.
Provide either ${DEFAULT_SECRET_FILE} or export the following variable with base64-encoded secrets:
  ${B64_SECRET_VAR}
EOF
  exit 1
fi

echo "$B64_SECRET_VALUE" | base64 -d > "$CI_SECRET_FILE"

echo "$CI_SECRET_FILE"

