#!/bin/bash
# scripts/create-k8s-secrets.sh
# Create Kubernetes secrets for Odoo deployment

set -euo pipefail

NAMESPACE="${1:-odoo-dev}"
ENV="${2:-dev}"

echo "Creating Kubernetes secrets for namespace: $NAMESPACE (environment: $ENV)"

# Check if namespace exists
if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
    echo "Creating namespace $NAMESPACE..."
    kubectl create namespace "$NAMESPACE"
    kubectl label namespace "$NAMESPACE" environment="$ENV" managed-by=manual
fi

# Prompt for passwords
echo ""
echo "Enter passwords for Odoo secrets:"
read -sp "Database password: " DB_PASSWORD
echo ""
read -sp "Admin password: " ADMIN_PASSWORD
echo ""

# Create secret
kubectl create secret generic odoo-secrets \
  --from-literal=db-user=odoo \
  --from-literal=db-password="$DB_PASSWORD" \
  --from-literal=admin-password="$ADMIN_PASSWORD" \
  --namespace="$NAMESPACE" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✓ Secrets created in namespace $NAMESPACE"

# Create GitLab registry secret (if needed)
read -p "Create GitLab registry secret? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    read -p "GitLab username: " GITLAB_USER
    read -sp "GitLab token/password: " GITLAB_TOKEN
    echo ""
    
    kubectl create secret docker-registry gitlab-registry \
      --docker-server=registry.gitlab.hd.local \
      --docker-username="$GITLAB_USER" \
      --docker-password="$GITLAB_TOKEN" \
      --namespace="$NAMESPACE" \
      --dry-run=client -o yaml | kubectl apply -f -
    
    echo "✓ GitLab registry secret created"
fi

echo ""
echo "Secrets created successfully!"
echo ""
echo "To view secrets:"
echo "  kubectl get secrets -n $NAMESPACE"
echo ""
echo "To delete secrets:"
echo "  kubectl delete secret odoo-secrets -n $NAMESPACE"
