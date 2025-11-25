#!/bin/bash
# scripts/setup-gitlab-runner-k3s.sh
# Configure GitLab Runner to access k3s cluster

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log "Setting up GitLab Runner access to k3s cluster..."

# Get k3s kubeconfig from master
log "Fetching kubeconfig from k3s master..."
K3S_MASTER="10.12.14.15"
KUBECONFIG_CONTENT=$(ssh yv@${K3S_MASTER} "sudo cat /etc/rancher/k3s/k3s.yaml" | sed "s/127.0.0.1/${K3S_MASTER}/g")

# Base64 encode for GitLab CI variable
KUBECONFIG_BASE64=$(echo "$KUBECONFIG_CONTENT" | base64 -w 0)

log "Kubeconfig retrieved and encoded"
log ""
log "Add this to GitLab CI/CD Variables (Settings > CI/CD > Variables):"
log ""
echo "Variable name: KUBECONFIG_CONTENT"
echo "Value (base64 encoded):"
echo "$KUBECONFIG_BASE64"
log ""
log "Variable settings:"
log "  - Type: Variable"
log "  - Protected: Yes (recommended)"
log "  - Masked: No (too long to mask)"
log "  - Expand variable reference: No"
log ""

# Create service account for GitLab Runner
log "Creating Kubernetes ServiceAccount for GitLab Runner..."

kubectl apply -f - <<EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: gitlab-runner
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: gitlab-runner
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: gitlab-runner
  namespace: kube-system
EOF

log "✓ ServiceAccount created"
log ""
log "Next steps:"
log "1. Add KUBECONFIG_CONTENT variable to GitLab project"
log "2. Add other required CI/CD variables (see docs/gitlab-ci-variables.md)"
log "3. Test pipeline on a feature branch"
