#!/bin/bash
# Setup complete infrastructure from scratch

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

header() {
    echo -e "\n${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}\n"
}

# Check prerequisites
check_prerequisites() {
    header "Checking prerequisites"

    local missing=0

    for cmd in terraform ansible kubectl helm; do
        if command -v "$cmd" &> /dev/null; then
            log "$cmd is installed"
        else
            error "$cmd is not installed"
            missing=1
        fi
    done

    if [[ $missing -eq 1 ]]; then
        error "Please install missing tools"
    fi
}

# Setup Terraform
setup_terraform() {
    header "Setting up Terraform"

    cd terraform

    if [[ ! -f terraform.tfvars ]]; then
        warn "terraform.tfvars not found"
        log "Creating from example..."
        if [[ -f terraform.tfvars.example ]]; then
            cp terraform.tfvars.example terraform.tfvars
            warn "Please edit terraform.tfvars with your Proxmox credentials"
            read -p "Press enter when ready..."
        else
            error "terraform.tfvars.example not found"
        fi
    fi

    log "Initializing Terraform..."
    terraform init

    log "Planning infrastructure..."
    terraform plan

    read -p "Apply this plan? (yes/no): " -r
    if [[ $REPLY =~ ^yes$ ]]; then
        log "Applying infrastructure..."
        terraform apply
    else
        error "Terraform apply cancelled"
    fi

    cd ..
}

# Setup Ansible
setup_ansible() {
    header "Setting up with Ansible"

    cd ansible

    log "Testing connectivity..."
    if ! ansible all -i inventory.ini -m ping; then
        error "Cannot connect to hosts. Check inventory.ini and SSH keys"
    fi

    log "Running Ansible playbook..."
    ansible-playbook -i inventory.ini playbook.yml

    cd ..
}

# Setup kubectl
setup_kubectl() {
    header "Setting up kubectl"

    if [[ -f /tmp/k3s.yaml ]]; then
        log "Copying kubeconfig..."
        mkdir -p ~/.kube
        cp /tmp/k3s.yaml ~/.kube/config
        sed -i 's/127.0.0.1/192.168.0.20/g' ~/.kube/config
        chmod 600 ~/.kube/config
    else
        warn "Kubeconfig not found in /tmp/k3s.yaml"
        log "Copying from k3s master..."
        scp ubuntu@192.168.0.20:/home/ubuntu/.kube/config ~/.kube/config
        sed -i 's/127.0.0.1/192.168.0.20/g' ~/.kube/config
    fi

    log "Testing kubectl..."
    kubectl get nodes
}

# Deploy monitoring
deploy_monitoring() {
    header "Deploying monitoring stack"

    log "Creating monitoring namespace..."
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

    log "Adding Helm repos..."
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm repo update

    log "Installing Prometheus stack..."
    helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
        -f k8s/base/monitoring/prometheus-values.yaml \
        --namespace monitoring \
        --wait \
        --timeout 10m

    log "Applying Prometheus rules..."
    kubectl apply -f k8s/base/monitoring/prometheus-rules.yaml

    log "Monitoring stack deployed!"
    log "Access Grafana: kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80"
}

# Deploy Odoo dev
deploy_odoo_dev() {
    header "Deploying Odoo development environment"

    log "Creating namespace..."
    kubectl create namespace odoo-dev --dry-run=client -o yaml | kubectl apply -f -

    log "Deploying Odoo..."
    helm upgrade --install odoo-dev k8s/charts/odoo/ \
        -f k8s/overlays/dev/values.yaml \
        --namespace odoo-dev \
        --wait \
        --timeout 10m

    log "Odoo dev deployed!"
    kubectl get all -n odoo-dev
}

# Main
main() {
    header "Odoo Infrastructure Setup"

    log "This script will:"
    log "1. Check prerequisites"
    log "2. Create VMs with Terraform"
    log "3. Configure servers with Ansible"
    log "4. Setup kubectl"
    log "5. Deploy monitoring"
    log "6. Deploy Odoo dev environment"
    echo ""
    read -p "Continue? (yes/no): " -r

    if [[ ! $REPLY =~ ^yes$ ]]; then
        error "Setup cancelled"
    fi

    check_prerequisites
    setup_terraform

    # Wait for VMs to be ready
    log "Waiting 60s for VMs to fully boot..."
    sleep 60

    setup_ansible
    setup_kubectl
    deploy_monitoring
    deploy_odoo_dev

    header "Setup Complete!"

    cat << EOF

Your Odoo cluster is ready!

Next steps:
1. Access Grafana:
   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
   User: admin, Password: (see k8s/base/monitoring/prometheus-values.yaml)

2. Access Odoo Dev:
   kubectl port-forward -n odoo-dev svc/odoo-dev 8069:8069
   URL: http://localhost:8069

3. Deploy to stage/prod:
   ./scripts/deploy.sh -e stage
   ./scripts/deploy.sh -e prod

4. View logs:
   kubectl logs -n odoo-dev -l app.kubernetes.io/name=odoo -f

Happy deploying!
EOF
}

main
