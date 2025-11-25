#!/bin/bash
# Script to create a working cloud-init template for Proxmox
# Run this on your Proxmox host

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Configuration
VM_ID=${1:-9000}
VM_NAME="ubuntu-22.04-cloudinit"
STORAGE="local-lvm"
BRIDGE="vmbr0"
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
IMAGE_FILE="ubuntu-22.04-cloudimg.img"

log "Creating cloud-init template VM $VM_ID"

# Check if running on Proxmox
if ! command -v qm &> /dev/null; then
    error "This script must be run on a Proxmox host!"
fi

log "Step 1: Cleanup"
if qm status $VM_ID &>/dev/null; then
    warn "VM $VM_ID exists, destroying..."
    qm destroy $VM_ID || true
fi

log "Step 2: Download cloud image"
cd /tmp
if [ -f "$IMAGE_FILE" ]; then
    warn "Image exists, removing..."
    rm -f "$IMAGE_FILE"
fi

log "Downloading from $IMAGE_URL..."
wget -q --show-progress -O "$IMAGE_FILE" "$IMAGE_URL"

log "Step 3: Install tools"
apt-get update -qq
apt-get install -y -qq libguestfs-tools

log "Step 4: Customize image"
log "Installing qemu-guest-agent and configuring cloud-init..."

virt-customize -a "$IMAGE_FILE" \
  --install qemu-guest-agent \
  --run-command 'systemctl enable qemu-guest-agent' \
  --run-command 'systemctl enable ssh' \
  --write '/etc/cloud/cloud.cfg.d/99_pve.cfg:datasource_list: [NoCloud, ConfigDrive]' \
  --run-command 'cloud-init clean --logs'

log "Step 5: Create VM"
qm create $VM_ID \
  --name "$VM_NAME" \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=$BRIDGE \
  --vga std \
  --ostype l26

log "Step 6: Import disk"
qm importdisk $VM_ID "$IMAGE_FILE" $STORAGE

log "Step 7: Configure VM"
qm set $VM_ID --scsihw virtio-scsi-pci
qm set $VM_ID --scsi0 ${STORAGE}:vm-${VM_ID}-disk-0
qm set $VM_ID --ide2 ${STORAGE}:cloudinit
qm set $VM_ID --boot c --bootdisk scsi0
qm set $VM_ID --agent enabled=1

log "Step 8: Convert to template"
qm template $VM_ID

log ""
log "✅ SUCCESS! Template created"
log ""
log "Template ID: $VM_ID"
log "Template Name: $VM_NAME"
log ""
log "Test it with:"
log "  qm clone $VM_ID 999 --name test-vm --full"
log "  qm set 999 --ciuser ubuntu --cipassword ubuntu"
log "  qm set 999 --ipconfig0 ip=10.12.14.99/24,gw=10.12.14.254"
log "  qm set 999 --nameserver 8.8.8.8"
log "  qm start 999"
log ""
log "After 2 minutes:"
log "  ssh <your-user>@10.12.14.99  # Use your actual SSH username from ansible/inventory.ini"
log ""

# Cleanup
rm -f "/tmp/$IMAGE_FILE"
