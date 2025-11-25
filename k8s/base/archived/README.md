# Archived Kubernetes Resources

This directory contains Kubernetes manifests that are **not currently in use** but kept for future reference.

## Archived Files

### 1. pgbouncer-deployment.yaml
**Reason for archiving:** 
- PgBouncer is not currently used in the infrastructure
- Configured to connect to `postgres-patroni-master` which doesn't exist
- Current setup:
  - **Production**: Direct connection to external PostgreSQL VM (10.12.14.19)
  - **Dev/Test/Stage**: Simple postgres StatefulSet

**Potential future use:**
- If implementing connection pooling for production PostgreSQL
- Would need to update host to `postgres-prod` for production

---

### 2. postgres-ha/ directory
**Contains:**
- `patroni-statefulset.yaml` - PostgreSQL HA cluster with Patroni
- `etcd-statefulset.yaml` - etcd for Patroni cluster coordination

**Reason for archiving:**
- Patroni HA cluster is not deployed in any environment
- Current setup uses simpler solutions:
  - **Production**: External PostgreSQL VM with physical HA (10.12.14.19)
  - **Dev/Test/Stage**: Single-replica StatefulSet (adequate for non-production)

**Potential future use:**
- If needing PostgreSQL HA within Kubernetes for staging/test environments
- Would require etcd cluster setup and significant configuration

---

## Current Architecture

### Production (odoo-prod)
- PostgreSQL: External VM at **10.12.14.19** (500GB, 16GB RAM, 8 CPU)
- Service: `postgres-prod` (defined in `postgres-external-service.yaml`)
- Backup: pgBackRest on the VM, 30-day retention

### Dev/Test/Stage
- PostgreSQL: In-cluster StatefulSet (defined in `postgres-statefulset.yaml`)
- Service: `postgres`
- Storage: 20Gi PVC per environment

---

## If You Need These Resources

To restore any of these files:
```bash
# From k8s/base/archived/
cp pgbouncer-deployment.yaml ../
cp -r postgres-ha ../
```

Remember to update references and configurations before deployment!

---

**Archived on:** 2025-11-25  
**By:** Infrastructure cleanup - removing unused resources
