# Phase 2 Progress Summary

## Что сделано

### 1. Обновлена конфигурация доменов
✅ GitLab URL обновлен на `gitlab.hd.local`
✅ Registry URL обновлен на `registry.gitlab.hd.local`
✅ Все placeholders YOURDOMAIN заменены

### 2. Настроено подключение к внешнему PostgreSQL
✅ Создан `kubernetes/base/postgres-external-service.yaml`:
   - Service для подключения к PostgreSQL VM (10.12.14.19)
   - Endpoints для прямого доступа

✅ Создан `kubernetes/overlays/prod/postgres-host-patch.yaml`:
   - Patch для production окружения
   - Использует `postgres-prod` вместо in-cluster PostgreSQL

✅ Обновлен `kubernetes/overlays/prod/kustomization.yaml`:
   - Убраны postgres-cluster.yaml и pgbouncer-deployment.yaml (не нужны для prod)
   - Добавлен postgres-external-service.yaml
   - Обновлены ConfigMap параметры (db_host=postgres-prod, db_port=5432)

✅ Обновлен `kubernetes/base/deployment.yaml`:
   - Registry URL: registry.gitlab.hd.local
   - Комментарии о выборе PostgreSQL host

### 3. Архитектурное решение
**Production**: PostgreSQL на отдельной VM (10.12.14.19)
**Dev/Stage/Test**: PostgreSQL в Kubernetes (меньше ресурсов)

## Следующие шаги (Phase 3)

1. **Создать Kubernetes Secrets**:
   ```bash
   kubectl create namespace odoo-prod
   kubectl create secret generic odoo-secrets \
     --from-literal=db-user=odoo \
     --from-literal=db-password=<пароль из ansible vault> \
     --from-literal=admin-password=<admin пароль> \
     -n odoo-prod
   ```

2. **Создать PersistentVolumeClaims**:
   - odoo-data-pvc (50Gi)
   - odoo-addons-pvc (10Gi)

3. **Деплой в dev окружение** для тестирования

4. **Настроить GitLab Runner** для CI/CD

## Файлы для review

- `odoo-project/kubernetes/base/postgres-external-service.yaml` - новый
- `odoo-project/kubernetes/overlays/prod/postgres-host-patch.yaml` - новый
- `odoo-project/kubernetes/overlays/prod/kustomization.yaml` - обновлен
- `odoo-project/kubernetes/base/deployment.yaml` - обновлен registry URL
