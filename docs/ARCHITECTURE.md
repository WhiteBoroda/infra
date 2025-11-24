# Архитектура инфраструктуры

## Рекомендуемая архитектура

### Принцип разделения ответственности

**Kubernetes (K3s) - для приложений:**
- ✅ Odoo приложение
- ✅ PostgreSQL для Odoo (stateless/development)
- ✅ Redis для кеширования Odoo
- ✅ Prometheus/Grafana для мониторинга Kubernetes
- ✅ NGINX Ingress, Cert-Manager, MetalLB

**Отдельные VM - для критической инфраструктуры:**
- ✅ PostgreSQL для production (с persistence, backup)
- ✅ Redis для production (с persistence, если нужно)
- ✅ GitLab (CI/CD)
- ⚠️ Мониторинг (опционально - можно в Kubernetes)

---

## Варианты архитектуры

### Вариант 1: Гибридный (рекомендуется для production)

```
┌─────────────────────────────────────────────────────────┐
│ Kubernetes Cluster (K3s)                                │
│ ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│ │   Odoo      │  │ PostgreSQL │  │   Redis     │        │
│ │  (app pods) │  │  (dev/test)│  │  (cache)    │        │
│ └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                           │
│ ┌─────────────┐  ┌─────────────┐                          │
│ │ Prometheus  │  │  Grafana   │                          │
│ │ (k8s metrics)│ │ (dashboards)│                          │
│ └─────────────┘  └─────────────┘                          │
└─────────────────────────────────────────────────────────┘
                          │
                          │ (для production)
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Standalone VMs                                          │
│ ┌─────────────┐  ┌─────────────┐  ┌─────────────┐      │
│ │ PostgreSQL  │  │   Redis     │  │   GitLab    │      │
│ │ (production)│  │ (production)│  │  (CI/CD)    │      │
│ │ с backup    │  │ с backup    │  │             │      │
│ └─────────────┘  └─────────────┘  └─────────────┘      │
└─────────────────────────────────────────────────────────┘
```

**Когда использовать:**
- Production окружение
- Нужен контроль над БД (backup, репликация)
- Высокие требования к производительности БД
- Разделение ответственности (DevOps vs DBA)

**Преимущества:**
- ✅ Лучшая производительность БД (нет overhead Kubernetes)
- ✅ Проще backup/restore
- ✅ Независимость от Kubernetes
- ✅ Можно использовать managed databases (AWS RDS, etc.)

**Недостатки:**
- ⚠️ Больше VM для управления
- ⚠️ Нужна настройка сетевого доступа

---

### Вариант 2: Все в Kubernetes (рекомендуется для dev/stage)

```
┌─────────────────────────────────────────────────────────┐
│ Kubernetes Cluster (K3s)                                │
│ ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│ │   Odoo      │  │ PostgreSQL  │  │   Redis     │        │
│ │  (app pods) │  │ (StatefulSet)│ │ (StatefulSet)│        │
│ └─────────────┘  └─────────────┘  └─────────────┘        │
│                                                           │
│ ┌─────────────┐  ┌─────────────┐                          │
│ │ Prometheus  │  │  Grafana   │                          │
│ └─────────────┘  └─────────────┘                          │
└─────────────────────────────────────────────────────────┘
                          │
                          │ (только для CI/CD)
                          ▼
┌─────────────────────────────────────────────────────────┐
│ Standalone VM                                           │
│ ┌─────────────┐                                         │
│ │   GitLab    │                                         │
│ │  (CI/CD)    │                                         │
│ └─────────────┘                                         │
└─────────────────────────────────────────────────────────┘
```

**Когда использовать:**
- Development/Staging окружения
- Небольшие проекты
- Нужна простота управления
- Kubernetes-native подход

**Преимущества:**
- ✅ Проще управление (все в одном месте)
- ✅ Автоматическое масштабирование
- ✅ Встроенные backup через Velero
- ✅ Меньше VM

**Недостатки:**
- ⚠️ Overhead Kubernetes для БД
- ⚠️ Сложнее настройка persistence
- ⚠️ Зависимость от Kubernetes

---

## Рекомендации по компонентам

### PostgreSQL

**В Kubernetes:**
- ✅ Development/Staging
- ✅ Тестовые окружения
- ✅ Stateless приложения

**Отдельная VM:**
- ✅ Production
- ✅ Критичные данные
- ✅ Нужна репликация
- ✅ Большие объемы данных (>100GB)

**Конфигурация для production VM:**
```yaml
# ansible/roles/postgres/tasks/main.yml
- name: Install PostgreSQL
  # Установка PostgreSQL 15
  # Настройка репликации
  # Настройка backup
  # Настройка мониторинга
```

### Redis

**В Kubernetes:**
- ✅ Кеш для приложений
- ✅ Session store
- ✅ Development/Staging

**Отдельная VM:**
- ✅ Production с persistence
- ✅ Большие объемы данных
- ✅ Нужна репликация (Redis Cluster)

### Мониторинг

**В Kubernetes (рекомендуется):**
- ✅ Prometheus для метрик Kubernetes
- ✅ Grafana для дашбордов
- ✅ ServiceMonitors для приложений
- ✅ Проще интеграция с Kubernetes

**Отдельная VM (опционально):**
- ✅ Долгосрочное хранение метрик (Thanos)
- ✅ Централизованный мониторинг нескольких кластеров
- ✅ Изоляция от Kubernetes

---

## Миграционная стратегия

### Текущее состояние → Рекомендуемое

1. **PostgreSQL:**
   ```bash
   # Текущее: PostgreSQL в Kubernetes (dev)
   # Рекомендуемое: 
   # - Dev/Stage: остаются в Kubernetes
   # - Production: мигрировать на отдельную VM
   ```

2. **Redis:**
   ```bash
   # Текущее: Redis в Kubernetes
   # Рекомендуемое:
   # - Оставить в Kubernetes (для кеша это нормально)
   # - Production: опционально на VM, если нужна persistence
   ```

3. **Мониторинг:**
   ```bash
   # Текущее: Docker на VM + Kubernetes
   # Рекомендуемое:
   # - Удалить Docker мониторинг с VM
   # - Использовать только Kubernetes (Prometheus/Grafana)
   # - VM monitoring можно использовать для других целей
   ```

---

## Конфигурация для разных окружений

### Development
```yaml
# Все в Kubernetes
postgresql:
  enabled: true  # в Kubernetes
redis:
  enabled: true  # в Kubernetes
monitoring:
  location: kubernetes
```

### Staging
```yaml
# Все в Kubernetes, но с persistence
postgresql:
  enabled: true
  persistence:
    enabled: true
    size: 50Gi
redis:
  enabled: true
  persistence:
    enabled: true
```

### Production
```yaml
# PostgreSQL на отдельной VM
postgresql:
  enabled: false  # не в Kubernetes
  external:
    host: 192.168.0.25
    port: 5432
    database: odoo_prod
    user: odoo
    password: "secure_password"

# Redis можно оставить в Kubernetes или на VM
redis:
  enabled: true  # или false, если на VM
  external:
    host: 192.168.0.24
    port: 6379
```

---

## Примеры конфигурации

### Подключение к внешнему PostgreSQL

```yaml
# k8s/overlays/prod/values.yaml
odoo:
  database:
    host: 192.168.0.25  # внешний PostgreSQL
    port: 5432
    user: odoo
    password: "secure_password_from_vault"
    name: odoo_prod
```

### Подключение к внешнему Redis

```yaml
odoo:
  cache:
    redis:
      host: 192.168.0.24  # внешний Redis
      port: 6379
      password: "redis_password"
```

---

## Резюме рекомендаций

1. **Для вашего случая (Odoo кластер):**
   - ✅ **Development/Staging**: Все в Kubernetes (текущая конфигурация)
   - ✅ **Production**: PostgreSQL на отдельной VM, Redis можно в Kubernetes
   - ✅ **Мониторинг**: Только в Kubernetes, удалить Docker с VM monitoring

2. **VM monitoring можно использовать для:**
   - Долгосрочного хранения метрик (Thanos)
   - Централизованного логирования (Loki)
   - Или удалить, если не нужна

3. **VM postgres и redis:**
   - Использовать только для production
   - Настроить backup и мониторинг
   - Подключить Odoo через внешние хосты

