#!/bin/bash
# scripts/deploy-odoo-dev.sh
# Deploy Odoo to dev environment

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

NAMESPACE="odoo-dev"
KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config}"

log "Deploying Odoo to dev environment..."

# Check kubectl connection
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: Cannot connect to Kubernetes cluster"
    exit 1
fi

# Create namespace
log "Creating namespace $NAMESPACE..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace "$NAMESPACE" environment=dev managed-by=manual --overwrite

# Create secrets
log "Creating secrets..."
if ! kubectl get secret odoo-secrets -n "$NAMESPACE" &> /dev/null; then
    warn "Secrets not found. Run: bash scripts/create-k8s-secrets.sh $NAMESPACE dev"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Apply base resources
log "Applying base Kubernetes resources..."
kubectl apply -f k8s/base/pvc.yaml -n "$NAMESPACE"
kubectl apply -f k8s/base/service.yaml -n "$NAMESPACE"
kubectl apply -f k8s/base/configmap.yaml -n "$NAMESPACE"
kubectl apply -f k8s/base/redis-deployment.yaml -n "$NAMESPACE"

# For dev, use in-cluster PostgreSQL (simple StatefulSet)
log "Deploying PostgreSQL for dev..."
kubectl apply -f k8s/base/postgres-statefulset.yaml -n "$NAMESPACE"

# Wait for PostgreSQL to be ready
log "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=postgres -n "$NAMESPACE" --timeout=300s

# Wait for Redis to be ready
log "Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=redis -n "$NAMESPACE" --timeout=300s

# Deploy Odoo
log "Deploying Odoo..."
kubectl apply -f k8s/base/deployment.yaml -n "$NAMESPACE"

# Wait for Odoo to be ready
log "Waiting for Odoo to be ready..."
kubectl wait --for=condition=ready pod -l app=odoo -n "$NAMESPACE" --timeout=600s

# Apply ingress
log "Applying Ingress..."
kubectl apply -f k8s/base/ingress.yaml -n "$NAMESPACE"

log "Deployment complete!"
log ""
log "Access Odoo at: http://dev.hd.local (configure DNS or /etc/hosts)"
log ""
log "Useful commands:"
log "  kubectl get pods -n $NAMESPACE"
log "  kubectl logs -f -l app=odoo -n $NAMESPACE"
log "  kubectl exec -it -n $NAMESPACE deployment/odoo -- /bin/bash"
log ""
log "To delete deployment:"
log "  kubectl delete namespace $NAMESPACE"
