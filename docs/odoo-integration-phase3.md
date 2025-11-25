# Phase 3: Deployment Preparation

## Изменения

### 1. Увеличен размер диска PostgreSQL VM
✅ **Обновлено**: `terraform/main.tf`
- Размер диска: 200GB → **500GB**
- Причина: текущая база занимает 200GB, нужен запас для роста
- После применения Terraform нужно будет расширить раздел в ОС

### 2. Созданы скрипты для деплоя

✅ **Создан**: `scripts/create-k8s-secrets.sh`
- Интерактивное создание Kubernetes secrets
- Поддержка GitLab registry credentials
- Использование: `bash scripts/create-k8s-secrets.sh odoo-dev dev`

✅ **Создан**: `scripts/deploy-odoo-dev.sh`
- Автоматический деплой в dev окружение
- Создает namespace, secrets, PVCs
- Деплоит PostgreSQL, Redis, Odoo
- Ждет готовности всех компонентов

### 3. Обновлены PersistentVolumeClaims

✅ **Обновлен**: `odoo-project/kubernetes/base/pvc.yaml`
- `odoo-data-pvc`: 50Gi (ReadWriteOnce)
- `odoo-addons-pvc`: 10Gi (ReadWriteMany)
- `odoo-filestore-pvc`: 100Gi (ReadWriteMany) - для файлов и вложений

## Следующие шаги

### 1. Обновить PostgreSQL VM (если уже создана)
```bash
cd c:\infra\terraform
terraform plan -target=proxmox_vm_qemu.postgres_prod
terraform apply -target=proxmox_vm_qemu.postgres_prod
```

После применения, на VM нужно расширить раздел:
```bash
# SSH на postgres-prod VM
ansible postgres_prod -m shell -a 'sudo growpart /dev/sda 1' -b
ansible postgres_prod -m shell -a 'sudo resize2fs /dev/sda1' -b
```

### 2. Создать secrets для dev окружения
```bash
bash scripts/create-k8s-secrets.sh odoo-dev dev
```

### 3. Деплой в dev
```bash
bash scripts/deploy-odoo-dev.sh
```

### 4. Проверить деплой
```bash
kubectl get pods -n odoo-dev
kubectl logs -f -l app=odoo -n odoo-dev
```

### 5. Настроить DNS или /etc/hosts
```
10.12.14.15  dev.hd.local
```

## Важные замечания

**PostgreSQL для dev/stage/test**:
- Используется простой StatefulSet в Kubernetes
- Для production используется внешняя VM (10.12.14.19)

**Storage Class**:
- k3s использует `local-path` по умолчанию
- Для production может потребоваться NFS или другое shared storage для ReadWriteMany

**Размеры дисков**:
- PostgreSQL VM: 500GB (для production базы 200GB + рост)
- Odoo filestore PVC: 100GB (для файлов и вложений)
- Odoo data PVC: 50GB (для локальных данных)
