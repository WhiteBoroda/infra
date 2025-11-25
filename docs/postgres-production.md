# PostgreSQL Production Setup

## Overview

PostgreSQL для production развернут на отдельной VM вне Kubernetes кластера для обеспечения максимальной производительности и надежности.

## Характеристики VM

- **CPU**: 8 cores
- **RAM**: 16 GB
- **Disk**: 200 GB SSD
- **IP**: 10.12.14.19
- **OS**: Ubuntu 22.04 LTS

## Конфигурация PostgreSQL

### Версия
PostgreSQL 15

### Оптимизация
Конфигурация оптимизирована для:
- 500+ одновременных пользователей
- Odoo ERP workload
- SSD storage
- 16GB RAM

### Ключевые параметры
```
max_connections = 300
shared_buffers = 4GB
effective_cache_size = 12GB
work_mem = 10MB
maintenance_work_mem = 1GB
max_wal_size = 8GB
```

## Backup Strategy

### Инструмент
pgBackRest - enterprise-grade backup solution

### Расписание
- **Ежедневно в 02:00**: Incremental backup
- **Еженедельно (воскресенье) в 03:00**: Full backup

### Retention Policy
- Full backups: 30 дней
- Differential backups: 7 дней
- WAL archives: 30 дней

### Ручной backup
```bash
# Full backup
bash scripts/backup-postgres.sh full

# Differential backup
bash scripts/backup-postgres.sh diff

# Incremental backup
bash scripts/backup-postgres.sh incr

# View backup info
ansible postgres_prod -m shell -a 'sudo -u postgres pgbackrest --stanza=odoo info' -b
```

### Восстановление из backup
```bash
# Stop PostgreSQL
ansible postgres_prod -m shell -a 'sudo systemctl stop postgresql' -b

# Restore latest backup
ansible postgres_prod -m shell -a 'sudo -u postgres pgbackrest --stanza=odoo restore' -b

# Start PostgreSQL
ansible postgres_prod -m shell -a 'sudo systemctl start postgresql' -b
```

## Мониторинг

### Prometheus Exporter
PostgreSQL exporter установлен и доступен на порту 9187

### Метрики
- Connection pool usage
- Query performance
- Replication lag (если настроена репликация)
- Database size
- Transaction rate
- Cache hit ratio

### Grafana Dashboard
Импортируйте dashboard ID: 9628 (PostgreSQL Database)

## Подключение из Odoo

### Connection String
```
Host: 10.12.14.19
Port: 5432
Database: odoo_prod / odoo_stage / odoo_dev
User: odoo
Password: <from ansible vault>
```

### Для production (через PgBouncer в будущем)
```
Host: pgbouncer-service.odoo-prod.svc.cluster.local
Port: 6432
```

## Безопасность

### Аутентификация
- SCRAM-SHA-256 для всех подключений
- Доступ разрешен только с IP адресов k3s кластера (10.12.14.0/24)

### Сетевая изоляция
- PostgreSQL слушает на всех интерфейсах, но pg_hba.conf ограничивает доступ
- Firewall правила (если настроены) дополнительно ограничивают доступ

### SSL/TLS
TODO: Настроить SSL для шифрования соединений

## Обслуживание

### Проверка статуса
```bash
ansible postgres_prod -m shell -a 'systemctl status postgresql'
```

### Просмотр логов
```bash
ansible postgres_prod -m shell -a 'tail -f /var/log/postgresql/postgresql-15-main.log' -b
```

### Vacuum
Autovacuum настроен и работает автоматически. Для ручного vacuum:
```bash
ansible postgres_prod -m shell -a 'sudo -u postgres vacuumdb --all --analyze' -b
```

### Обновление статистики
```bash
ansible postgres_prod -m shell -a 'sudo -u postgres psql -c "ANALYZE;"' -b
```

## Масштабирование

### Репликация (будущее)
Для дальнейшего масштабирования можно настроить:
1. Streaming replication (1 master + 2 replicas)
2. Patroni для автоматического failover
3. HAProxy для балансировки read-запросов

### Connection Pooling
PgBouncer можно развернуть в Kubernetes для эффективного управления connection pool

## Troubleshooting

### Высокая нагрузка
```sql
-- Найти долгие запросы
SELECT pid, now() - pg_stat_activity.query_start AS duration, query 
FROM pg_stat_activity 
WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';

-- Убить долгий запрос
SELECT pg_terminate_backend(pid);
```

### Проблемы с disk space
```bash
# Проверить размер баз данных
ansible postgres_prod -m shell -a 'sudo -u postgres psql -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) FROM pg_database;"' -b

# Очистить старые WAL файлы (если backup не работает)
ansible postgres_prod -m shell -a 'sudo -u postgres pg_archivecleanup /var/lib/postgresql/15/main/pg_wal 000000010000000000000010' -b
```

### Проблемы с подключением
```bash
# Проверить pg_hba.conf
ansible postgres_prod -m shell -a 'cat /etc/postgresql/15/main/pg_hba.conf' -b

# Проверить активные подключения
ansible postgres_prod -m shell -a 'sudo -u postgres psql -c "SELECT count(*) FROM pg_stat_activity;"' -b
```

## Контакты

При проблемах с PostgreSQL:
1. Проверьте логи: `/var/log/postgresql/`
2. Проверьте метрики в Grafana
3. Обратитесь к документации: https://www.postgresql.org/docs/15/
