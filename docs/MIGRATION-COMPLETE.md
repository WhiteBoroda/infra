# Migration Complete - odoo-project → infra

## ✅ Файлы перенесены

### Kubernetes Manifests
```
odoo-project/kubernetes/base/          → k8s/base/
odoo-project/kubernetes/overlays/test/ → k8s/overlays/test/  ✨ NEW
odoo-project/kubernetes/overlays/dev/  → k8s/overlays/dev/   (updated)
odoo-project/kubernetes/overlays/stage/→ k8s/overlays/stage/ (updated)
odoo-project/kubernetes/overlays/prod/ → k8s/overlays/prod/  (updated)
```

### Configuration & Code
```
odoo-project/config/        → config/
odoo-project/docker/        → docker/
odoo-project/custom-addons/ → custom-addons/
odoo-project/.gitlab-ci.yml → .gitlab-ci.yml
odoo-project/Makefile       → Makefile
odoo-project/requirements.txt → requirements.txt
```

## ✅ Обновленные скрипты

- `scripts/deploy-odoo-dev.sh` - обновлены пути с `odoo-project/kubernetes/` на `k8s/`

## 🗑️ Готово к удалению

Папка `odoo-project/` теперь может быть удалена:

```bash
# Проверьте, что всё скопировано
ls -la config/
ls -la docker/
ls -la custom-addons/
ls -la k8s/overlays/test/

# Удалите odoo-project
rm -rf odoo-project/
```

## 📁 Новая структура infra/

```
infra/
├── .gitlab-ci.yml          ← GitLab CI/CD pipeline
├── Makefile                ← Deployment automation
├── requirements.txt        ← Python dependencies
├── config/
│   └── variables.yaml      ← Centralized configuration
├── docker/
│   ├── Dockerfile          ← Multi-version Odoo image
│   ├── odoo.conf           ← Odoo configuration
│   ├── entrypoint.sh       ← Container entrypoint
│   └── requirements-*.txt  ← Version-specific deps
├── custom-addons/          ← Custom Odoo modules
├── k8s/
│   ├── base/               ← Base Kubernetes manifests
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   ├── pvc.yaml
│   │   ├── configmap.yaml
│   │   ├── postgres-external-service.yaml
│   │   ├── postgres-statefulset.yaml
│   │   └── redis-deployment.yaml
│   └── overlays/
│       ├── test/           ← Test environment (NEW!)
│       ├── dev/            ← Development
│       ├── stage/          ← Staging
│       └── prod/           ← Production
├── ansible/                ← Ansible roles & playbooks
├── terraform/              ← Infrastructure as Code
├── scripts/                ← Automation scripts
└── docs/                   ← Documentation
```

## 🎯 Следующие шаги

1. **Проверить миграцию**:
   ```bash
   # Проверить что test overlay существует
   ls k8s/overlays/test/
   
   # Проверить Makefile
   make help
   ```

2. **Обновить Git** (если используется):
   ```bash
   git add .
   git commit -m "Migrate odoo-project to infra root structure"
   ```

3. **Удалить odoo-project**:
   ```bash
   rm -rf odoo-project/
   ```

4. **Тестировать деплой**:
   ```bash
   bash scripts/deploy-odoo-dev.sh
   ```

## ✨ Преимущества новой структуры

- ✅ Единая структура проекта
- ✅ Все overlays (test, dev, stage, prod) в одном месте
- ✅ Централизованная конфигурация в `config/variables.yaml`
- ✅ Makefile в корне для удобства
- ✅ GitLab CI/CD в корне проекта
- ✅ Проще навигация и поддержка
