# Quick Start Guide

## Замена доменов в конфигурации

Все домены вынесены в `config/variables.yaml` для быстрой замены.

### Шаг 1: Замените YOURDOMAIN.COM на ваш домен

```bash
cd c:\infra

# Windows PowerShell
(Get-Content config\variables.yaml) -replace 'YOURDOMAIN\.COM', 'ваш-домен.com' | Set-Content config\variables.yaml

# Или вручную откройте файл и замените все вхождения YOURDOMAIN.COM
```

### Шаг 2: Проверьте изменения

Откройте `config/variables.yaml` и убедитесь, что все домены обновлены:
- `domains.base`
- `domains.test`
- `domains.dev`
- `domains.stage`
- `domains.prod`
- `registry.url`

### Шаг 3: Установите PostgreSQL Production

```bash
cd c:\infra
bash scripts/setup-postgres-prod.sh
```

Этот скрипт:
1. Создаст VM через Terraform
2. Настроит PostgreSQL 15
3. Установит pgBackRest для бэкапов
4. Настроит мониторинг

### Шаг 4: Создайте пароль для БД

```bash
ansible-vault create ansible/group_vars/postgres_prod.yml
```

Добавьте:
```yaml
vault_postgres_odoo_password: "ваш_надежный_пароль"
```

## Готово!

PostgreSQL production готов к использованию на `10.12.14.19:5432`

Следующий шаг: Phase 2 - Odoo Migration
