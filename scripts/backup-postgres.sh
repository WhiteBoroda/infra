#!/bin/bash
# scripts/backup-postgres.sh
# Manual PostgreSQL backup script

set -euo pipefail

BACKUP_TYPE="${1:-full}"  # full, diff, or incr
STANZA="odoo"

echo "Running PostgreSQL backup (type: $BACKUP_TYPE)..."

ansible postgres_prod -m shell -a "sudo -u postgres pgbackrest --stanza=$STANZA --type=$BACKUP_TYPE backup" -b

echo "Backup complete!"
echo ""
echo "To view backup info:"
echo "  ansible postgres_prod -m shell -a 'sudo -u postgres pgbackrest --stanza=$STANZA info' -b"
