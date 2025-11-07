# Структура проекта Odoo Infrastructure

```
infra/
├── README.md                          # Основная документация
├── DEPLOYMENT_GUIDE.md                # Пошаговое руководство по развертыванию
├── PROJECT_STRUCTURE.md               # Этот файл - описание структуры
├── .gitlab-ci.yml                     # GitLab CI/CD pipeline
├── .yamllint                          # Конфигурация yamllint
├── .gitignore                         # Git ignore файл
│
├── terraform/                         # Terraform конфигурация
│   ├── main.tf                        # Основной файл с ресурсами Proxmox
│   ├── variables.tf                   # Переменные
│   ├── outputs.tf                     # Outputs
│   ├── terraform.tfvars.example       # Пример конфигурации
│   └── terraform.tfvars               # Реальная конфигурация (не в git)
│
├── ansible/                           # Ansible конфигурация
│   ├── playbook.yml                   # Главный playbook
│   ├── inventory.ini                  # Inventory файл
│   ├── group_vars/
│   │   └── all.yml                    # Глобальные переменные
│   └── roles/
│       ├── k3s/                       # Роль установки k3s
│       │   └── tasks/main.yml
│       ├── gitlab/                    # Роль установки GitLab
│       │   └── tasks/main.yml
│       ├── gitlab_runner/             # Роль установки GitLab Runner
│       │   └── tasks/main.yml
│       ├── monitoring/                # Роль базового мониторинга
│       │   └── tasks/main.yml
│       ├── redis/                     # Роль установки Redis
│       │   └── tasks/main.yml
│       ├── nginx_ingress/             # Роль NGINX Ingress + MetalLB
│       │   └── tasks/main.yml
│       ├── odoo_cluster/              # Роль базового Odoo кластера
│       │   └── tasks/main.yml
│       └── prometheus_grafana/        # Роль Prometheus + Grafana
│           └── tasks/main.yml
│
├── k8s/                               # Kubernetes манифесты
│   ├── charts/                        # Helm charts
│   │   └── odoo/                      # Helm chart для Odoo
│   │       ├── Chart.yaml             # Метаданные chart
│   │       ├── values.yaml            # Дефолтные values
│   │       └── templates/             # Шаблоны манифестов
│   │           ├── _helpers.tpl       # Хелперы
│   │           ├── deployment.yaml    # Deployment шаблон
│   │           ├── service.yaml       # Service
│   │           ├── ingress.yaml       # Ingress
│   │           ├── configmap.yaml     # ConfigMap
│   │           ├── secret.yaml        # Secrets
│   │           ├── pvc.yaml           # PersistentVolumeClaim
│   │           ├── hpa.yaml           # HorizontalPodAutoscaler
│   │           ├── networkpolicy.yaml # NetworkPolicy
│   │           └── servicemonitor.yaml# ServiceMonitor
│   │
│   ├── overlays/                      # Оверлеи для окружений
│   │   ├── dev/
│   │   │   └── values.yaml            # Dev конфигурация
│   │   ├── stage/
│   │   │   └── values.yaml            # Stage конфигурация
│   │   └── prod/
│   │       └── values.yaml            # Prod конфигурация
│   │
│   ├── base/                          # Базовые манифесты
│   │   ├── monitoring/                # Конфигурация мониторинга
│   │   │   ├── prometheus-values.yaml           # Prometheus Stack values
│   │   │   ├── prometheus-rules.yaml            # PrometheusRules для алертов
│   │   │   ├── grafana-dashboard-odoo.json      # Grafana dashboard
│   │   │   └── grafana-dashboards-configmap.yaml# ConfigMap с дашбордами
│   │   ├── ingress/                   # Ingress конфигурация
│   │   ├── network-policies/          # NetworkPolicies
│   │   ├── postgres/                  # PostgreSQL манифесты
│   │   └── redis/                     # Redis манифесты
│   │
│   └── tests/                         # Тестовые манифесты
│       ├── test-deployment.yaml       # Тестовое окружение для Odoo
│       ├── load-test.js               # k6 нагрузочные тесты
│       └── locustfile.py              # Locust нагрузочные тесты
│
├── docker/                            # Docker конфигурация
│   ├── Dockerfile.odoo                # Dockerfile для кастомного Odoo
│   └── requirements.txt               # Python зависимости
│
└── scripts/                           # Вспомогательные скрипты
    ├── deploy.sh                      # Скрипт деплоя
    └── setup-infrastructure.sh        # Скрипт полной настройки
```

## Описание компонентов

### Terraform
Создает следующую инфраструктуру в Proxmox:
- **k3s-master** (192.168.0.20): Master нода K3s кластера
- **k3s-node1** (192.168.0.21): Worker нода K3s
- **gitlab** (192.168.0.22): GitLab сервер для CI/CD
- **monitoring** (192.168.0.23): Standalone мониторинг (опционально)
- **redis** (192.168.0.24): LXC контейнер с Redis
- **postgres** (192.168.0.25): PostgreSQL сервер

### Ansible
Настраивает серверы:
1. Устанавливает и конфигурирует K3s кластер
2. Устанавливает GitLab и GitLab Runner
3. Устанавливает Redis и базовый мониторинг
4. Настраивает NGINX Ingress, MetalLB, Cert-Manager
5. Разворачивает базовый Odoo кластер
6. Настраивает Prometheus и Grafana

### Kubernetes (K8s)
Структура для работы с Kubernetes:

#### Helm Chart для Odoo
Полнофункциональный Helm chart с поддержкой:
- Множественных модулей (web, accounting, inventory)
- Разных окружений (dev, stage, prod)
- Автомасштабирования (HPA)
- Network policies
- Service monitors для Prometheus
- Конфигурируемые ресурсы

#### Мониторинг
- **Prometheus** для сбора метрик
- **Grafana** для визуализации
- **AlertManager** для алертов
- Кастомные PrometheusRules для Odoo
- Готовые дашборды

#### Тестирование
- Unit тесты через pytest
- Интеграционные тесты через Helm
- Нагрузочные тесты через k6 и Locust
- Тестовое окружение для быстрой проверки

### CI/CD Pipeline
GitLab CI/CD pipeline с этапами:
1. **Lint**: Проверка YAML, Helm, Ansible
2. **Build**: Сборка Docker образов
3. **Test**: Unit и интеграционные тесты
4. **Security**: Сканирование уязвимостей (Trivy)
5. **Deploy Dev**: Автодеплой в dev
6. **Deploy Stage**: Ручной деплой в stage
7. **Deploy Prod**: Ручной деплой в prod (только по тегам)
8. **Performance**: Нагрузочное тестирование

## Workflow

### Разработка
```
1. Разработка → Push в develop
2. GitLab CI → Lint + Build + Test
3. Автодеплой в dev окружение
4. Проверка в dev
```

### Staging
```
1. Merge в main
2. GitLab CI → Lint + Build + Test + Security
3. Ручной деплой в stage
4. Нагрузочное тестирование
5. QA проверка
```

### Production
```
1. Создание тега (v1.0.0)
2. GitLab CI → Full pipeline
3. Ручной деплой в prod
4. Мониторинг метрик
5. Проверка алертов
```

## Окружения

### Development (dev)
- **Цель**: Быстрое тестирование новых функций
- **Ресурсы**: Минимальные (1 replica, no persistence)
- **Логирование**: Debug
- **Деплой**: Автоматический из develop ветки

### Staging (stage)
- **Цель**: Pre-production тестирование
- **Ресурсы**: Средние (2 replicas, persistence enabled)
- **Логирование**: Info
- **Деплой**: Ручной из main ветки
- **Особенности**: Нагрузочное тестирование

### Production (prod)
- **Цель**: Боевое окружение
- **Ресурсы**: Максимальные (3+ replicas, full persistence)
- **Логирование**: Warn/Error
- **Деплой**: Только по тегам
- **Особенности**: HA, автомасштабирование, полный мониторинг

## Ключевые особенности

### 1. Модульная архитектура Odoo
Возможность запускать разные Odoo модули на разных подах:
- Web модуль (основной интерфейс)
- Accounting модуль (бухгалтерия)
- Inventory модуль (склад)

### 2. Автомасштабирование
HPA автоматически масштабирует поды на основе:
- CPU utilization
- Memory utilization
- Custom metrics (если настроено)

### 3. Безопасность
- NetworkPolicies для изоляции
- TLS сертификаты через Cert-Manager
- Secrets для паролей
- Сканирование уязвимостей в CI/CD

### 4. Мониторинг
- Реалтайм метрики в Prometheus
- Визуализация в Grafana
- Алерты в Slack/Email
- Кастомные метрики для Odoo

### 5. Тестирование
- Unit тесты для кода
- Интеграционные тесты для манифестов
- Нагрузочные тесты для производительности
- Тестовое окружение для экспериментов

## Быстрые команды

```bash
# Полная настройка с нуля
./scripts/setup-infrastructure.sh

# Деплой в конкретное окружение
./scripts/deploy.sh -e dev
./scripts/deploy.sh -e stage
./scripts/deploy.sh -e prod -t v1.0.0

# Просмотр логов
kubectl logs -n odoo-prod -l app.kubernetes.io/name=odoo -f

# Масштабирование
kubectl scale deployment odoo-prod-web --replicas=5 -n odoo-prod

# Мониторинг
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Тестирование
k6 run k8s/tests/load-test.js
locust -f k8s/tests/locustfile.py --host http://odoo-stage.local
```

## Требования

### Железо
- Proxmox сервер: 32GB RAM, 8+ cores
- Сеть: 192.168.0.0/24

### Софт
- Terraform >= 1.0
- Ansible >= 2.9
- kubectl >= 1.28
- helm >= 3.13
- Docker (для локальной разработки)

## Поддержка

Для вопросов и проблем:
1. Проверьте README.md
2. Проверьте DEPLOYMENT_GUIDE.md
3. Создайте issue в GitLab
4. Свяжитесь с DevOps командой

---
**Версия**: 1.0.0
**Последнее обновление**: 2024-11
**Автор**: DevOps Team
