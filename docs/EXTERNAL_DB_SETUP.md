# Настройка внешних PostgreSQL и Redis

## Подключение Odoo к внешнему PostgreSQL

### Вариант 1: Через Ansible (текущая конфигурация)

Измените `ansible/roles/odoo_cluster/tasks/main.yml`:

```yaml
# Вместо развертывания PostgreSQL в Kubernetes
- name: Configure Odoo to use external PostgreSQL
  shell: |
    kubectl apply -n odoo -f - <<EOF
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: odoo-config
    data:
      odoo.conf: |
        [options]
        db_host = 192.168.0.25  # внешний PostgreSQL
        db_port = 5432
        db_user = odoo
        db_password = odoo123
        list_db = True
        proxy_mode = True
        session_store = redis
        redis_host = 192.168.0.24  # внешний Redis
        redis_port = 6379
    EOF
```

### Вариант 2: Через Helm values

Создайте `k8s/overlays/prod/values-external-db.yaml`:

```yaml
# Отключаем встроенный PostgreSQL
postgresql:
  enabled: false

# Отключаем встроенный Redis (опционально)
redis:
  enabled: false

# Настраиваем Odoo для использования внешних БД
odoo:
  database:
    host: 192.168.0.25
    port: 5432
    user: odoo
    password: "secure_password"
    name: odoo_prod
  
  cache:
    redis:
      host: 192.168.0.24
      port: 6379
      password: ""  # если нужен пароль
```

Деплой:
```bash
helm upgrade --install odoo-prod k8s/charts/odoo/ \
  -f k8s/overlays/prod/values.yaml \
  -f k8s/overlays/prod/values-secrets.yaml \
  -f k8s/overlays/prod/values-external-db.yaml \
  --namespace odoo-prod
```

---

## Настройка PostgreSQL на отдельной VM

### 1. Установка PostgreSQL через Ansible

Создайте `ansible/roles/postgres/tasks/main.yml`:

```yaml
- name: Install PostgreSQL
  apt:
    name:
      - postgresql-15
      - postgresql-contrib-15
    state: present

- name: Configure PostgreSQL
  template:
    src: postgresql.conf.j2
    dest: /etc/postgresql/15/main/postgresql.conf
  notify: restart postgresql

- name: Configure pg_hba.conf
  template:
    src: pg_hba.conf.j2
    dest: /etc/postgresql/15/main/pg_hba.conf
  notify: restart postgresql

- name: Create Odoo database
  postgresql_db:
    name: odoo
    state: present

- name: Create Odoo user
  postgresql_user:
    name: odoo
    password: "{{ postgres_odoo_password }}"
    priv: "odoo:ALL"
    state: present
```

### 2. Настройка доступа из Kubernetes

В `pg_hba.conf`:
```
# Разрешить доступ из Kubernetes кластера
host    odoo    odoo    192.168.0.0/24    md5
```

В `postgresql.conf`:
```conf
listen_addresses = '*'
```

---

## Настройка Redis на отдельной VM

### 1. Установка Redis через Ansible

Создайте `ansible/roles/redis/tasks/main.yml`:

```yaml
- name: Install Redis
  apt:
    name: redis-server
    state: present

- name: Configure Redis
  template:
    src: redis.conf.j2
    dest: /etc/redis/redis.conf
  notify: restart redis

- name: Enable Redis persistence
  lineinfile:
    path: /etc/redis/redis.conf
    regexp: '^save'
    line: 'save 900 1'
```

### 2. Настройка доступа из Kubernetes

В `redis.conf`:
```conf
bind 0.0.0.0
protected-mode no  # или yes с паролем
requirepass "your_secure_password"
```

---

## Рекомендуемая структура для разных окружений

### Development (все в Kubernetes)
```yaml
# k8s/overlays/dev/values.yaml
postgresql:
  enabled: true
  primary:
    persistence:
      enabled: false  # для dev можно без persistence

redis:
  enabled: true
  master:
    persistence:
      enabled: false
```

### Staging (все в Kubernetes с persistence)
```yaml
# k8s/overlays/stage/values.yaml
postgresql:
  enabled: true
  primary:
    persistence:
      enabled: true
      size: 50Gi

redis:
  enabled: true
  master:
    persistence:
      enabled: true
```

### Production (внешние БД)
```yaml
# k8s/overlays/prod/values.yaml
postgresql:
  enabled: false  # используем внешний

redis:
  enabled: false  # опционально, можно оставить в k8s

odoo:
  database:
    host: 192.168.0.25  # внешний PostgreSQL
    port: 5432
    user: odoo
    password: "{{ vault_postgres_password }}"
  
  cache:
    redis:
      host: 192.168.0.24  # внешний Redis
      port: 6379
```

---

## Миграция данных

### Из Kubernetes PostgreSQL в внешний

```bash
# 1. Экспорт из Kubernetes
kubectl exec -n odoo postgres-postgresql-0 -- \
  pg_dump -U odoo odoo > odoo_backup.sql

# 2. Импорт во внешний PostgreSQL
psql -h 192.168.0.25 -U odoo -d odoo < odoo_backup.sql
```

---

## Мониторинг внешних БД

### Добавить в Prometheus

```yaml
# k8s/base/monitoring/prometheus-values.yaml
additionalScrapeConfigs:
  - job_name: 'postgres-external'
    static_configs:
      - targets: ['192.168.0.25:9187']  # postgres_exporter
    
  - job_name: 'redis-external'
    static_configs:
      - targets: ['192.168.0.24:9121']  # redis_exporter
```

---

## Резюме

**Рекомендация для вашего проекта:**

1. **Development/Staging**: Оставить текущую конфигурацию (все в Kubernetes)
2. **Production**: 
   - PostgreSQL → на VM (192.168.0.25)
   - Redis → можно оставить в Kubernetes (для кеша это нормально)
   - Мониторинг → только в Kubernetes, удалить Docker с VM

3. **VM monitoring (192.168.0.23)**: 
   - Удалить Docker контейнеры
   - Использовать для других целей или удалить

4. **VM redis (192.168.0.24)**: 
   - Использовать только если нужна persistence для production
   - Иначе можно не использовать

5. **VM postgres (192.168.0.25)**: 
   - Использовать для production
   - Настроить backup и мониторинг

