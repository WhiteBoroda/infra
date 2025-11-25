# Odoo Project Integration Summary

## Что сделано (Phase 1)

### 1. PostgreSQL Production VM
✅ Добавлена VM в Terraform:
- **Ресурсы**: 8 CPU cores, 16GB RAM, 200GB SSD
- **IP**: 10.12.14.19
- **Файл**: `terraform/main.tf`

✅ Создана Ansible роль `postgres_prod`:
- PostgreSQL 15 с production-оптимизацией
- pgBackRest для автоматических бэкапов (ежедневно в 02:00)
- Retention: 30 дней для full backups
- Prometheus exporter для мониторинга
- Конфигурация: 4GB shared_buffers, 12GB effective_cache_size

✅ Обновлена инфраструктура:
- `ansible/inventory.ini` - добавлена группа `postgres_prod`
- `ansible/playbook.yml` - добавлена роль postgres_prod
- `terraform/outputs.tf` - добавлен IP postgres-prod

### 2. Odoo Project Configuration
✅ Обновлен `odoo-project/config/variables.yaml`:
- Домены заменены на `YOURDOMAIN.COM` (placeholder для быстрой замены)
- Добавлен wildcard pattern для test environments
- Добавлена конфигурация `postgres_prod_vm` с IP 10.12.14.19
- Увеличены параметры PostgreSQL под 16GB RAM

✅ Созданы недостающие файлы:
- `odoo-project/custom-addons/.gitkeep` - директория для кастомных модулей
- `odoo-project/docker/odoo.conf` - конфигурация Odoo для Docker

### 3. Скрипты и документация
✅ Созданы скрипты:
- `scripts/setup-postgres-prod.sh` - автоматизация создания PostgreSQL VM
- `scripts/backup-postgres.sh` - ручной запуск бэкапов

✅ Документация:
- `docs/postgres-production.md` - полное руководство по PostgreSQL production

## Следующие шаги

### Что нужно сделать вручную:

1. **Заменить домены** в `odoo-project/config/variables.yaml`:
   ```bash
   # Найти и заменить YOURDOMAIN.COM на ваш реальный домен
   # Например: hlibodar.com.ua
   ```

2. **Создать GitLab registry URL** в том же файле:
   ```yaml
   registry:
     url: "registry.gitlab.YOURDOMAIN.COM"  # Заменить на реальный URL
   ```

3. **Установить пароль для PostgreSQL** в Ansible Vault:
   ```bash
   ansible-vault create ansible/group_vars/postgres_prod.yml
   # Добавить:
   # vault_postgres_odoo_password: "your_secure_password"
   ```

4. **Запустить создание PostgreSQL VM**:
   ```bash
   bash scripts/setup-postgres-prod.sh
   ```

### Phase 2: Odoo Migration (следующий этап)
- [ ] Переместить odoo-project в infra/odoo
- [ ] Обновить Kubernetes manifests для подключения к внешнему PostgreSQL
- [ ] Настроить ConfigMaps и Secrets
- [ ] Деплой в dev environment

## Важные файлы для review

1. `terraform/main.tf` - PostgreSQL VM definition
2. `ansible/roles/postgres_prod/` - вся роль PostgreSQL
3. `odoo-project/config/variables.yaml` - централизованная конфигурация
4. `docs/postgres-production.md` - документация

## Архитектурное решение

**PostgreSQL для production** вынесен на отдельную VM вместо Kubernetes по следующим причинам:
- ✅ Больше ресурсов (16GB RAM vs ограничения в K8s)
- ✅ Проще масштабировать вертикально
- ✅ Изоляция от проблем кластера
- ✅ Прямой доступ к диску для бэкапов
- ✅ Меньше overhead от Kubernetes

**Для dev/stage/test** можно использовать PostgreSQL в Kubernetes (меньше ресурсов).
