# Odoo Deployment Guide

## Полная интеграция odoo-project завершена!

Этот документ описывает финальную архитектуру и процесс деплоя Odoo в вашей инфраструктуре.

## Архитектура

### Компоненты

```
┌─────────────────────────────────────────────────────────────┐
│                    Proxmox Infrastructure                    │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ k3s-master   │  │ k3s-node1    │  │ GitLab       │      │
│  │ 10.12.14.15  │  │ 10.12.14.16  │  │ 10.12.14.17  │      │
│  │ 4 CPU, 8GB   │  │ 4 CPU, 8GB   │  │ 4 CPU, 8GB   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                               │
│  ┌──────────────┐  ┌──────────────────────────────┐         │
│  │ GitLab Runner│  │ PostgreSQL Production        │         │
│  │ 10.12.14.18  │  │ 10.12.14.19                  │         │
│  │ 2 CPU, 4GB   │  │ 8 CPU, 16GB RAM, 500GB SSD   │         │
│  └──────────────┘  └──────────────────────────────┘         │
│                                                               │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│              Kubernetes Cluster (k3s)                        │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Namespace: odoo-prod                                        │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ Odoo Pod 1 │  │ Odoo Pod 2 │  │ Odoo Pod 3 │            │
│  │ 1CPU, 2GB  │  │ 1CPU, 2GB  │  │ 1CPU, 2GB  │            │
│  └────────────┘  └────────────┘  └────────────┘            │
│         │              │              │                      │
│         └──────────────┴──────────────┘                      │
│                        │                                      │
│         ┌──────────────┴──────────────┐                      │
│         │                              │                      │
│    ┌────▼────┐                   ┌────▼────┐                │
│    │ Redis   │                   │ Postgres│                │
│    │ (k8s)   │                   │ External│                │
│    │ 3 pods  │                   │ Service │                │
│    └─────────┘                   └────┬────┘                │
│                                        │                      │
│                                        │ 10.12.14.19:5432    │
└────────────────────────────────────────┼────────────────────┘
                                         │
                                    ┌────▼────┐
                                    │PostgreSQL│
                                    │   VM     │
                                    │ 500GB DB │
                                    └──────────┘
```

### Окружения

| Environment | Namespace | PostgreSQL | Replicas | Domain |
|------------|-----------|------------|----------|--------|
| **Production** | odoo-prod | External VM (10.12.14.19) | 4 | hd.local |
| **Staging** | odoo-stage | In-cluster | 2 | stage.hd.local |
| **Development** | odoo-dev | In-cluster | 2 | dev.hd.local |
| **Test** | odoo-test-* | In-cluster | 1 | *.test.hd.local |

## Процесс деплоя

### Первоначальная настройка (один раз)

#### 1. Создание инфраструктуры

```bash
cd c:\infra

# Создать все VM через Terraform
cd terraform
terraform init
terraform plan
terraform apply

# Настроить все сервисы через Ansible
cd ../ansible
ansible-playbook playbook.yml

# Настроить PostgreSQL production
bash ../scripts/setup-postgres-prod.sh
```

#### 2. Настройка GitLab CI/CD

```bash
# Настроить доступ GitLab Runner к k3s
bash scripts/setup-gitlab-runner-k3s.sh

# Добавить переменные в GitLab
# См. docs/gitlab-ci-variables.md
```

#### 3. Создание secrets для Kubernetes

```bash
# Dev environment
bash scripts/create-k8s-secrets.sh odoo-dev dev

# Stage environment
bash scripts/create-k8s-secrets.sh odoo-stage stage

# Production environment
bash scripts/create-k8s-secrets.sh odoo-prod prod
```

### Деплой через GitLab CI/CD (рекомендуется)

#### Development
```bash
# Push в ветку develop
git checkout develop
git add .
git commit -m "Update Odoo configuration"
git push origin develop

# GitLab CI автоматически задеплоит в odoo-dev
```

#### Staging
```bash
# Push в main branch
git checkout main
git merge develop
git push origin main

# Ручной запуск deploy:stage в GitLab UI
```

#### Production
```bash
# Создать tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Ручной запуск deploy:prod в GitLab UI
```

### Ручной деплой (для dev/testing)

```bash
# Development
bash scripts/deploy-odoo-dev.sh

# Production (используйте с осторожностью!)
kubectl apply -f k8s/base/postgres-external-service.yaml -n odoo-prod
kubectl apply -f k8s/base/pvc.yaml -n odoo-prod
kubectl apply -f k8s/base/redis-deployment.yaml -n odoo-prod
kubectl apply -f k8s/base/deployment.yaml -n odoo-prod
kubectl apply -f k8s/base/service.yaml -n odoo-prod
kubectl apply -f k8s/base/ingress.yaml -n odoo-prod
```

## Мониторинг и обслуживание

### Проверка статуса

```bash
# Все окружения
kubectl get pods --all-namespaces | grep odoo

# Production
kubectl get pods -n odoo-prod
kubectl get svc -n odoo-prod
kubectl get ingress -n odoo-prod

# PostgreSQL VM
ansible postgres_prod -m shell -a 'systemctl status postgresql'
```

### Логи

```bash
# Odoo logs
kubectl logs -f -l app=odoo -n odoo-prod

# PostgreSQL logs
ansible postgres_prod -m shell -a 'tail -f /var/log/postgresql/postgresql-15-main.log' -b

# GitLab CI/CD logs
# См. GitLab UI > CI/CD > Pipelines
```

### Backup

```bash
# PostgreSQL backup (автоматически ежедневно в 02:00)
bash scripts/backup-postgres.sh full

# Kubernetes resources backup
kubectl get all -n odoo-prod -o yaml > backup-odoo-prod-$(date +%Y%m%d).yaml
```

## Масштабирование

### Горизонтальное (больше pods)

```bash
# Production
kubectl scale deployment odoo --replicas=6 -n odoo-prod

# Или через Kustomize
# Обновить kubernetes/overlays/prod/kustomization.yaml:
# replicas:
# - name: odoo
#   count: 6
```

### Вертикальное (больше ресурсов)

Обновить `kubernetes/overlays/prod/deployment-patch.yaml`:
```yaml
resources:
  requests:
    cpu: "2000m"
    memory: "4Gi"
  limits:
    cpu: "4000m"
    memory: "8Gi"
```

## Troubleshooting

### Odoo не запускается

```bash
# Проверить logs
kubectl logs -l app=odoo -n odoo-prod --tail=100

# Проверить events
kubectl get events -n odoo-prod --sort-by='.lastTimestamp'

# Проверить подключение к PostgreSQL
kubectl exec -it deployment/odoo -n odoo-prod -- psql -h postgres-prod -U odoo -d odoo_prod
```

### PostgreSQL проблемы

```bash
# Проверить статус
ansible postgres_prod -m shell -a 'systemctl status postgresql'

# Проверить подключения
ansible postgres_prod -m shell -a 'sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"' -b

# Проверить размер базы
ansible postgres_prod -m shell -a 'sudo -u postgres psql -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) FROM pg_database;"' -b
```

### GitLab CI/CD не работает

1. Проверить переменные в GitLab: Settings > CI/CD > Variables
2. Проверить GitLab Runner: `kubectl get pods -n gitlab-runner`
3. Проверить KUBECONFIG_CONTENT: `echo $KUBECONFIG_CONTENT | base64 -d | kubectl --kubeconfig=- get nodes`

## Полезные команды

```bash
# Рестарт Odoo
kubectl rollout restart deployment/odoo -n odoo-prod

# Shell в Odoo pod
kubectl exec -it deployment/odoo -n odoo-prod -- /bin/bash

# Port forward для локального доступа
kubectl port-forward -n odoo-prod svc/odoo 8069:8069

# Обновить image
kubectl set image deployment/odoo odoo=registry.gitlab.hd.local/odoo-team/odoo:v1.0.1 -n odoo-prod

# Rollback deployment
kubectl rollout undo deployment/odoo -n odoo-prod
```

## Контакты и поддержка

- **Документация**: `c:\infra\docs\`
- **Логи**: GitLab CI/CD Pipelines, Kubernetes logs
- **Мониторинг**: Prometheus + Grafana (если настроено)

## Следующие шаги

1. ✅ Настроить SSL сертификаты (Let's Encrypt)
2. ✅ Настроить мониторинг (Prometheus + Grafana)
3. ✅ Настроить автоматические бэкапы
4. ⏳ Настроить WAF (Web Application Firewall)
5. ⏳ Настроить CDN для статики
6. ⏳ Настроить репликацию PostgreSQL (если нужно)
