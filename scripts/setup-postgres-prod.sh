#!/bin/bash
# scripts/setup-postgres-prod.sh
# Setup PostgreSQL production server with Terraform and Ansible

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

log "Starting PostgreSQL production setup..."

# Check if we're in the right directory
if [ ! -f "terraform/main.tf" ]; then
    error "Please run this script from the infra directory"
fi

# Step 1: Create VM with Terraform
log "Step 1: Creating PostgreSQL VM with Terraform..."
cd terraform
terraform init
terraform plan -target=proxmox_vm_qemu.postgres_prod
read -p "Apply Terraform changes? (yes/no): " -r
if [[ $REPLY =~ ^yes$ ]]; then
    terraform apply -target=proxmox_vm_qemu.postgres_prod
else
    error "Terraform apply cancelled"
fi
cd ..

# Wait for VM to be ready
log "Waiting for VM to be ready (30 seconds)..."
sleep 30

# Step 2: Test SSH connection
log "Step 2: Testing SSH connection..."
if ! ansible postgres_prod -m ping; then
    error "Cannot connect to postgres_prod VM. Check SSH keys and network."
fi

# Step 3: Run Ansible playbook
log "Step 3: Running Ansible playbook..."
ansible-playbook ansible/playbook.yml --tags postgres --ask-vault-pass

log "PostgreSQL production setup complete!"
log ""
log "PostgreSQL is now running on: 10.12.14.19:5432"
log ""
log "Next steps:"
log "1. Set the Odoo database password in ansible/group_vars/all.yml (encrypted with ansible-vault)"
log "2. Update odoo-project/config/variables.yaml with actual domain names"
log "3. Configure Odoo to connect to this PostgreSQL server"
log ""
log "Useful commands:"
log "  - Check PostgreSQL status: ansible postgres_prod -m shell -a 'systemctl status postgresql'"
log "  - View PostgreSQL logs: ansible postgres_prod -m shell -a 'tail -f /var/log/postgresql/postgresql-15-main.log'"
log "  - Run backup manually: ansible postgres_prod -m shell -a 'sudo -u postgres pgbackrest --stanza=odoo backup' -b"
log "  - List backups: ansible postgres_prod -m shell -a 'sudo -u postgres pgbackrest --stanza=odoo info' -b"
