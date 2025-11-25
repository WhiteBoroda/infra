# Kubernetes Overlays - Summary

## Что обновлено

### Test Environment (`kubernetes/overlays/test/`)
✅ **5 файлов**:
- `kustomization.yaml` - основная конфигурация
- `deployment-patch.yaml` - обновлен домен на `BRANCH_NAME.test.hd.local`
- `ingress-patch.yaml` - динамические домены для feature branches
- `configmap-patch.yaml` - конфигурация Odoo для тестов
- `redis-patch.yaml` - минимальные ресурсы для Redis

**Особенности**:
- 1 replica Odoo, 1 replica Redis
- Debug logging
- Demo data включена
- Динамические домены: `feature-123.test.hd.local`

### Dev Environment (`kubernetes/overlays/dev/`)
✅ **Обновлено до 3 файлов**:
- `kustomization.yaml` - обновлен (resources вместо bases)
- `deployment-patch.yaml` - создан (домен: `dev.hd.local`)
- `ingress-patch.yaml` - уже существует

**Особенности**:
- 2 replicas Odoo, 1 replica Redis
- Info logging
- In-cluster PostgreSQL
- Домен: `dev.hd.local`

### Stage Environment (`kubernetes/overlays/stage/`)
✅ **6 файлов** (уже полная конфигурация):
- `kustomization.yaml`
- `deployment-patch.yaml`
- `ingress-patch.yaml`
- `configmap-patch.yaml`
- `pvc-patch.yaml`
- `redis-patch.yaml`

**Особенности**:
- 2 replicas Odoo, 2 replicas Redis
- Info logging
- Basic auth enabled
- Домен: `stage.hd.local`

### Production Environment (`kubernetes/overlays/prod/`)
✅ **3 файла** (обновлено ранее):
- `kustomization.yaml` - external PostgreSQL
- `deployment-patch.yaml`
- `ingress-patch.yaml`
- `postgres-host-patch.yaml` - использует postgres-prod (10.12.14.19)
- `redis-statefulset.yaml`

**Особенности**:
- 4 replicas Odoo, 3 replicas Redis
- Warning logging
- External PostgreSQL VM
- Домен: `hd.local`

## Использование

### Test (feature branches)
```bash
cd kubernetes/overlays/test
# BRANCH_NAME будет заменен в CI/CD
kustomize build . | kubectl apply -n odoo-test-feature-123 -f -
```

### Dev
```bash
cd kubernetes/overlays/dev
kustomize build . | kubectl apply -n odoo-dev -f -
```

### Stage
```bash
cd kubernetes/overlays/stage
kustomize build . | kubectl apply -n odoo-stage -f -
```

### Production
```bash
cd kubernetes/overlays/prod
kustomize build . | kubectl apply -n odoo-prod -f -
```

## Все домены обновлены на hd.local ✅
