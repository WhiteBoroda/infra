# Kubernetes Manifests Cleanup Analysis

## Текущая архитектура

### Production
- **PostgreSQL**: External VM (10.12.14.19) - НЕ в Kubernetes
- **Подключение**: Через `postgres-external-service.yaml`

### Dev/Stage/Test
- **PostgreSQL**: Simple StatefulSet в Kubernetes
- **Файл**: `postgres-statefulset.yaml`

## ❌ Файлы к удалению (НЕ используются)

### 1. PostgreSQL HA Cluster (Zalando Operator)
```
k8s/base/postgres-cluster.yaml          ← Zalando PostgreSQL cluster (3 replicas + Patroni)
k8s/base/postgres-operator.yaml         ← Zalando Postgres Operator
k8s/base/postgres-ha/                   ← Вся папка
  ├── patroni-statefulset.yaml          ← Patroni для HA
  └── etcd-statefulset.yaml             ← etcd для Patroni (если есть)
```

**Причина**: Мы используем external VM для prod, а для dev/stage/test - простой StatefulSet.

### 2. PgBouncer
```
k8s/base/pgbouncer-deployment.yaml      ← Connection pooler
```

**Причина**: 
- Для prod: прямое подключение к external PostgreSQL
- Для dev/stage/test: не нужен connection pooler (малая нагрузка)

### 3. PostgreSQL Backup CronJob
```
k8s/base/postgres-backup-cronjob.yaml   ← Kubernetes-based backups
```

**Причина**: 
- Для prod: бэкапы делаются на VM через pgBackRest
- Для dev/stage/test: не критично (можно пересоздать)

## ✅ Файлы которые НУЖНЫ

### PostgreSQL
```
k8s/base/postgres-statefulset.yaml      ← Для dev/stage/test окружений
k8s/base/postgres-external-service.yaml ← Для prod (подключение к VM)
```

### Odoo
```
k8s/base/deployment.yaml                ← Odoo deployment
k8s/base/service.yaml                   ← Odoo service
k8s/base/ingress.yaml                   ← Ingress
k8s/base/configmap.yaml                 ← Odoo configuration
k8s/base/pvc.yaml                       ← Persistent volumes
```

### Redis
```
k8s/base/redis-deployment.yaml          ← Redis для sessions
k8s/base/redis-exporter.yaml            ← Prometheus exporter (опционально)
```

### Monitoring (опционально)
```
k8s/base/monitoring/                    ← Prometheus rules, dashboards
```

## 🔍 Проверка использования

### В overlays НЕ используются:
- ❌ `postgres-cluster.yaml` - нигде не referenced
- ❌ `pgbouncer-deployment.yaml` - нигде не referenced  
- ❌ `postgres-operator.yaml` - нигде не referenced
- ❌ `postgres-backup-cronjob.yaml` - нигде не referenced

### Используются:
- ✅ `postgres-statefulset.yaml` - в dev overlay (через deploy-odoo-dev.sh)
- ✅ `postgres-external-service.yaml` - в prod overlay (kustomization.yaml)

## 📝 Рекомендации

### Удалить сейчас
```bash
# PostgreSQL HA components (не используются)
rm k8s/base/postgres-cluster.yaml
rm k8s/base/postgres-operator.yaml
rm k8s/base/pgbouncer-deployment.yaml
rm k8s/base/postgres-backup-cronjob.yaml
rm -rf k8s/base/postgres-ha/

# Redis exporter (если не нужен мониторинг)
# rm k8s/base/redis-exporter.yaml  # опционально
```

### Оставить
```bash
# Эти файлы НУЖНЫ
k8s/base/postgres-statefulset.yaml      # dev/stage/test
k8s/base/postgres-external-service.yaml # prod
k8s/base/deployment.yaml                # Odoo
k8s/base/service.yaml                   # Odoo service
k8s/base/ingress.yaml                   # Ingress
k8s/base/configmap.yaml                 # Config
k8s/base/pvc.yaml                       # Storage
k8s/base/redis-deployment.yaml          # Redis
```

## 🎯 Итоговая структура k8s/base/

```
k8s/base/
├── deployment.yaml                 ← Odoo
├── service.yaml                    ← Odoo service
├── ingress.yaml                    ← Ingress
├── configmap.yaml                  ← Odoo config
├── pvc.yaml                        ← Persistent volumes
├── postgres-statefulset.yaml       ← PostgreSQL для dev/stage/test
├── postgres-external-service.yaml  ← PostgreSQL prod (external VM)
├── redis-deployment.yaml           ← Redis
├── redis-exporter.yaml             ← Redis monitoring (опционально)
└── monitoring/                     ← Prometheus rules (опционально)
    ├── prometheus-rules.yaml
    └── grafana-dashboard-odoo.json
```

## ⚠️ Важно

Если в будущем захотите PostgreSQL HA в Kubernetes:
1. Сохраните файлы в `docs/archived-manifests/` перед удалением
2. Или создайте отдельную ветку `feature/postgres-ha-k8s`

Но для текущей архитектуры (external VM для prod) эти файлы не нужны.
