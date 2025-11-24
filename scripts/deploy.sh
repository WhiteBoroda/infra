#!/bin/bash
# Deployment script for Odoo cluster

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Odoo to Kubernetes cluster

OPTIONS:
    -e, --environment   Environment to deploy (dev|stage|prod)
    -n, --namespace     Kubernetes namespace (default: odoo-<environment>)
    -r, --release-name  Helm release name (default: odoo-<environment>)
    -t, --tag          Image tag (default: latest)
    -h, --help         Show this help message

EXAMPLES:
    # Deploy to dev
    $0 -e dev

    # Deploy to prod with specific tag
    $0 -e prod -t v1.2.3

    # Deploy with custom namespace
    $0 -e stage -n custom-namespace
EOF
    exit 0
}

# Default values
ENVIRONMENT=""
NAMESPACE=""
RELEASE_NAME=""
IMAGE_TAG="latest"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -r|--release-name)
            RELEASE_NAME="$2"
            shift 2
            ;;
        -t|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Validate environment
if [[ -z "$ENVIRONMENT" ]]; then
    error "Environment is required. Use -e or --environment"
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|stage|prod)$ ]]; then
    error "Invalid environment. Must be dev, stage, or prod"
fi

# Set defaults if not provided
NAMESPACE=${NAMESPACE:-"odoo-${ENVIRONMENT}"}
RELEASE_NAME=${RELEASE_NAME:-"odoo-${ENVIRONMENT}"}

log "Starting deployment..."
log "Environment: $ENVIRONMENT"
log "Namespace: $NAMESPACE"
log "Release: $RELEASE_NAME"
log "Image tag: $IMAGE_TAG"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    error "kubectl is not installed"
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    error "helm is not installed"
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    error "Cannot connect to Kubernetes cluster"
fi

# Create namespace if it doesn't exist
log "Creating namespace if not exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Check if values file exists
VALUES_FILE="k8s/overlays/${ENVIRONMENT}/values.yaml"
if [[ ! -f "$VALUES_FILE" ]]; then
    error "Values file not found: $VALUES_FILE"
fi

# Optional secrets file handling
SECRET_VALUES_FILE="k8s/overlays/${ENVIRONMENT}/values-secrets.yaml"
if [[ -n "${HELM_VALUES_SECRETS_FILE:-}" ]]; then
    log "Using custom secrets file: $HELM_VALUES_SECRETS_FILE"
    SECRET_VALUES_FILE="$HELM_VALUES_SECRETS_FILE"
fi

VALUES_ARGS=(-f "$VALUES_FILE")
if [[ -f "$SECRET_VALUES_FILE" ]]; then
    log "Using secrets override: $SECRET_VALUES_FILE"
    VALUES_ARGS+=(-f "$SECRET_VALUES_FILE")
else
    log "No values-secrets.yaml found for ${ENVIRONMENT}, expecting credentials to be provided externally"
fi

# Confirm production deployment
if [[ "$ENVIRONMENT" == "prod" ]]; then
    warn "You are about to deploy to PRODUCTION!"
    read -p "Are you sure? (yes/no): " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        error "Deployment cancelled"
    fi
fi

# Deploy with Helm
log "Deploying with Helm..."
helm upgrade --install "$RELEASE_NAME" k8s/charts/odoo/ \
    "${VALUES_ARGS[@]}" \
    --namespace "$NAMESPACE" \
    --set image.tag="$IMAGE_TAG" \
    --wait \
    --timeout 15m

# Check rollout status
log "Checking rollout status..."
for deployment in $(kubectl get deployments -n "$NAMESPACE" -l app.kubernetes.io/name=odoo -o name); do
    log "Waiting for $deployment..."
    kubectl rollout status "$deployment" -n "$NAMESPACE" --timeout=10m
done

# Display access information
log "Deployment completed successfully!"
log ""
log "Access information:"
kubectl get ingress -n "$NAMESPACE"
log ""
log "Pods status:"
kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=odoo
log ""
log "Services:"
kubectl get svc -n "$NAMESPACE"

# Display helpful commands
cat << EOF

Useful commands:
  View logs:    kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=odoo -f
  Shell access: kubectl exec -it -n $NAMESPACE <pod-name> -- /bin/bash
  Port forward: kubectl port-forward -n $NAMESPACE svc/odoo 8069:8069
  Delete:       helm uninstall $RELEASE_NAME -n $NAMESPACE

EOF
