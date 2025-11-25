# Odoo Infrastructure

Production-ready infrastructure for deploying Odoo ERP with Kubernetes (k3s), featuring external PostgreSQL, automated CI/CD, and comprehensive monitoring.

## 🚀 Quick Links

- **[Deployment Guide](docs/odoo-deployment-guide.md)** - Complete deployment instructions
- **[Quick Start](docs/QUICKSTART.md)** - Get started in 5 minutes
- **[GitLab CI/CD Setup](docs/gitlab-ci-variables.md)** - CI/CD configuration
- **[PostgreSQL Production](docs/postgres-production.md)** - Database setup
- **[Migration Complete](docs/MIGRATION-COMPLETE.md)** - Migration summary

## 📋 Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Proxmox Infrastructure                    │
├─────────────────────────────────────────────────────────────┤
│  k3s-master (10.12.14.15)    k3s-node1 (10.12.14.16)       │
│  GitLab (10.12.14.17)        GitLab Runner (10.12.14.18)   │
│  PostgreSQL Production (10.12.14.19) - 500GB, 16GB RAM     │
└─────────────────────────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Cluster (k3s)                        │
├─────────────────────────────────────────────────────────────┤
│  Namespaces: odoo-test, odoo-dev, odoo-stage, odoo-prod    │
│                                                               │
│  Odoo Pods (4 replicas in prod) → Redis (3 replicas)       │
│         ↓                                                     │
│  External PostgreSQL VM (production)                        │
│  In-cluster PostgreSQL (dev/stage/test)                    │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 Features

- ✅ **External PostgreSQL** for production (500GB, automated backups)
- ✅ **Multi-environment** support (test, dev, stage, prod)
- ✅ **Kustomize-based** deployments with overlays
- ✅ **GitLab CI/CD** with automated pipelines
- ✅ **Centralized configuration** via `config/variables.yaml`
- ✅ **Automated backups** with pgBackRest (30-day retention)
- ✅ **Prometheus monitoring** with exporters
- ✅ **Dynamic test environments** for feature branches

## 📦 Components

### Infrastructure (Terraform + Ansible)
- **Terraform**: VM provisioning on Proxmox
- **Ansible**: Server configuration and setup
- **k3s**: Lightweight Kubernetes distribution

### Application Stack
- **Odoo 17/18/19**: Multi-version support
- **PostgreSQL 15**: External VM for production
- **Redis**: Session management and caching
- **GitLab**: CI/CD and container registry

### Deployment
- **Kustomize**: Kubernetes manifest management
- **Makefile**: Deployment automation
- **GitLab CI/CD**: Automated pipelines

## 🚀 Quick Start

### 1. Prerequisites
```bash
# Install required tools
terraform --version  # >= 1.0
ansible --version    # >= 2.9
kubectl version      # >= 1.28
```

### 2. Setup Infrastructure
```bash
# Configure Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your Proxmox credentials

# Create VMs
terraform init
terraform apply

# Configure with Ansible
cd ../ansible
ansible-playbook playbook.yml
```

### 3. Setup PostgreSQL Production
```bash
bash scripts/setup-postgres-prod.sh
```

### 4. Deploy Odoo
```bash
# Create secrets
bash scripts/create-k8s-secrets.sh odoo-dev dev

# Deploy to dev
bash scripts/deploy-odoo-dev.sh
```

## 📁 Project Structure

```
infra/
├── config/                  # Centralized configuration
│   └── variables.yaml       # All environment variables
├── docker/                  # Docker images
│   ├── Dockerfile           # Multi-version Odoo
│   └── odoo.conf            # Odoo configuration
├── custom-addons/           # Custom Odoo modules
├── k8s/                     # Kubernetes manifests
│   ├── base/                # Base manifests
│   └── overlays/            # Environment-specific
│       ├── test/            # Test environment
│       ├── dev/             # Development
│       ├── stage/           # Staging
│       └── prod/            # Production
├── terraform/               # Infrastructure as Code
├── ansible/                 # Configuration management
├── scripts/                 # Automation scripts
└── docs/                    # Documentation
```

## 🔄 Deployment Workflow

### Development
```bash
git push origin develop
# → GitLab CI automatically deploys to odoo-dev
```

### Staging
```bash
git push origin main
# → Manual deployment via GitLab UI
```

### Production
```bash
git tag v1.0.0
git push origin v1.0.0
# → Manual deployment via GitLab UI
```

## 📊 Monitoring

- **PostgreSQL**: Prometheus exporter on port 9187
- **Odoo**: Application metrics
- **Kubernetes**: Cluster metrics
- **Grafana**: Dashboards (import ID: 9628 for PostgreSQL)

## 🔧 Common Commands

```bash
# Check deployment status
kubectl get pods -n odoo-prod

# View logs
kubectl logs -f -l app=odoo -n odoo-prod

# Scale deployment
kubectl scale deployment odoo --replicas=6 -n odoo-prod

# PostgreSQL backup
bash scripts/backup-postgres.sh full

# Access Odoo
kubectl port-forward -n odoo-dev svc/odoo 8069:8069
```

## 📚 Documentation

- [Deployment Guide](docs/odoo-deployment-guide.md) - Full deployment instructions
- [PostgreSQL Setup](docs/postgres-production.md) - Database configuration
- [GitLab CI/CD](docs/gitlab-ci-variables.md) - CI/CD setup
- [Kubernetes Overlays](docs/kubernetes-overlays-summary.md) - Environment configs
- [Quick Start](docs/QUICKSTART.md) - Fast setup guide

## 🛠️ Troubleshooting

See [Deployment Guide](docs/odoo-deployment-guide.md#troubleshooting) for common issues and solutions.

## 📝 License

MIT

## 👥 Support

For issues and questions, see documentation in `docs/` folder.

---

**Version**: 2.0.0  
**Last Updated**: 2025-11-25  
**Architecture**: Kustomize + External PostgreSQL
