# Odoo Cluster Infrastructure

Полноценная CI/CD инфраструктура для развертывания и управления Odoo кластером в Kubernetes (K3s).

## 📋 Содержание

- [Архитектура](#архитектура)
- [Компоненты](#компоненты)
- [Требования](#требования)
- [Быстрый старт](#быстрый-старт)
- [Развертывание](#развертывание)
- [CI/CD Pipeline](#cicd-pipeline)
- [Мониторинг](#мониторинг)
- [Тестирование](#тестирование)
- [Управление окружениями](#управление-окружениями)
- [Troubleshooting](#troubleshooting)

## 🏗️ Архитектура

```
┌─────────────────────────────────────────────────────────────┐
│                         GitLab CI/CD                        │
│         (Build → Test → Security → Deploy)                  │
└───────────────┬─────────────────────────────────────────────┘
                │
                ▼
┌───────────────────────────────────────────────────────────┐
│                    K3s Cluster                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐       │
│  │   Dev       │  │   Stage     │  │   Prod      │       │
│  │ Namespace   │  │ Namespace   │  │ Namespace   │       │
│  └─────────────┘  └─────────────┘  └─────────────┘       │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐ │
│  │              Odoo Pods (Multi-Module)                │ │
│  │  • Web Module  • Accounting  • Inventory            │ │
│  └──────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌──────────┐    ┌──────────┐    ┌────────────────┐     │
│  │PostgreSQL│    │  Redis   │    │ Load Balancer  │     │
│  └──────────┘    └──────────┘    │  (MetalLB +    │     │
│                                   │  NGINX Ingress)│     │
│                                   └────────────────┘     │
└───────────────────────────────────────────────────────────┘
                │
                ▼
┌───────────────────────────────────────────────────────────┐
│              Monitoring Stack                              │
│  • Prometheus  • Grafana  • AlertManager                  │
└───────────────────────────────────────────────────────────┘
```

## 🔧 Компоненты

### Инфраструктура
- **Proxmox VE** - виртуализация
- **Terraform** - IaC для создания VM
- **Ansible** - конфигурация серверов
- **K3s** - легковесный Kubernetes

### Приложения
- **Odoo 17** - ERP система
- **PostgreSQL 15** - база данных
- **Redis** - кеш и сессии
- **GitLab** - CI/CD и registry

### Мониторинг и обсервабельность
- **Prometheus** - метрики
- **Grafana** - визуализация
- **AlertManager** - алерты

### Сеть и безопасность
- **MetalLB** - LoadBalancer для bare metal
- **NGINX Ingress** - маршрутизация трафика
- **Cert-Manager** - автоматические SSL сертификаты
- **NetworkPolicies** - изоляция сети

## 📦 Требования

### Железо
- **Proxmox сервер** с минимум 32GB RAM и 8 cores
- **Сеть** - доступ к интернету и локальная сеть 192.168.0.0/24

### Софт на локальной машине
```bash
# Terraform
terraform --version  # >= 1.0

# Ansible
ansible --version    # >= 2.9

# kubectl
kubectl version      # >= 1.28

# helm
helm version         # >= 3.13
```

## 🚀 Быстрый старт

### 1. Клонирование репозитория
```bash
git clone <repo-url>
cd infra
```

### 2. Настройка переменных Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Отредактируйте terraform.tfvars с вашими данными
```

Пример `terraform.tfvars`:
```hcl
pm_api_url          = "https://proxmox.local:8006/api2/json"
pm_api_token_id     = "root@pam!terraform"
pm_api_token_secret = "your-secret-token"
target_node         = "pve"
storage             = "local-lvm"
template_name       = "ubuntu-22.04-cloudinit"
ssh_pubkey_path     = "~/.ssh/id_rsa.pub"
```

### 3. Создание инфраструктуры
```bash
terraform init
terraform plan
terraform apply
```

### 4. Настройка с помощью Ansible
```bash
cd ../ansible

# Проверка подключения
ansible all -i inventory.ini -m ping

# Запуск playbook
ansible-playbook -i inventory.ini playbook.yml
```

### 5. Настройка kubectl
```bash
# Копируем kubeconfig с master ноды
scp ubuntu@192.168.0.20:/home/ubuntu/.kube/config ~/.kube/config

# Или используем файл из /tmp после Ansible
cp /tmp/k3s.yaml ~/.kube/config
# Замените IP в config на адрес мастера
sed -i 's/127.0.0.1/192.168.0.20/g' ~/.kube/config

# Проверка
kubectl get nodes
```

## 📚 Развертывание

### Управление секретами Helm

Каждое окружение (`k8s/overlays/<env>`) содержит файл `values-secrets.example.yaml`.

1. Скопируйте его и заполните реальными значениями:
   ```bash
   cp k8s/overlays/dev/values-secrets.example.yaml k8s/overlays/dev/values-secrets.yaml
   cp k8s/overlays/stage/values-secrets.example.yaml k8s/overlays/stage/values-secrets.yaml
   cp k8s/overlays/prod/values-secrets.example.yaml k8s/overlays/prod/values-secrets.yaml
   ```
2. Внесите **только локально** пароли БД и администратора Odoo. Файлы `values-secrets.yaml` автоматически игнорируются `.gitignore`.
3. Скрипты и CI/CD пайплайн автоматически подхватывают файл, если он существует.

Для GitLab CI сохраните содержимое `values-secrets.yaml` в переменных:
```
DEV_VALUES_SECRETS_B64   - base64 от k8s/overlays/dev/values-secrets.yaml
STAGE_VALUES_SECRETS_B64 - base64 от k8s/overlays/stage/values-secrets.yaml
PROD_VALUES_SECRETS_B64  - base64 от k8s/overlays/prod/values-secrets.yaml
```
Получить base64:
```bash
cat k8s/overlays/dev/values-secrets.yaml | base64 -w 0
```

### Развертывание Odoo через Helm

#### Development окружение
```bash
helm install odoo-dev k8s/charts/odoo/ \
  -f k8s/overlays/dev/values.yaml \
  -f k8s/overlays/dev/values-secrets.yaml \
  --namespace odoo-dev \
  --create-namespace
```

#### Staging окружение
```bash
helm install odoo-stage k8s/charts/odoo/ \
  -f k8s/overlays/stage/values.yaml \
  -f k8s/overlays/stage/values-secrets.yaml \
  --namespace odoo-stage \
  --create-namespace
```

#### Production окружение
```bash
# ВАЖНО: Перед деплоем заполните secrets-файл!
vim k8s/overlays/prod/values-secrets.yaml

helm install odoo-prod k8s/charts/odoo/ \
  -f k8s/overlays/prod/values.yaml \
  -f k8s/overlays/prod/values-secrets.yaml \
  --namespace odoo-prod \
  --create-namespace
```

### Обновление релиза
```bash
helm upgrade odoo-prod k8s/charts/odoo/ \
  -f k8s/overlays/prod/values.yaml \
  -f k8s/overlays/prod/values-secrets.yaml \
  --namespace odoo-prod
```

### Проверка статуса
```bash
# Статус деплоймента
kubectl get all -n odoo-prod

# Логи
kubectl logs -n odoo-prod -l app.kubernetes.io/name=odoo --tail=100 -f

# События
kubectl get events -n odoo-prod --sort-by='.lastTimestamp'
```

## 🔄 CI/CD Pipeline

### Структура Pipeline

1. **Lint** - проверка YAML, Helm charts, Ansible
2. **Build** - сборка custom Docker образов
3. **Test** - unit тесты и интеграционные тесты
4. **Security** - сканирование на уязвимости
5. **Deploy Dev** - автодеплой в dev при push в develop
6. **Deploy Stage** - ручной деплой в stage
7. **Deploy Prod** - ручной деплой в prod при создании тега
8. **Performance Test** - нагрузочное тестирование

### Настройка GitLab CI/CD

#### 1. Добавьте переменные в GitLab
Settings → CI/CD → Variables:
```
KUBECONFIG_CONTENT      - base64 encoded kubeconfig
CI_REGISTRY             - registry.gitlab.com/yourgroup/project
CI_REGISTRY_USER        - gitlab-ci-token
CI_REGISTRY_PASSWORD    - (auto from GitLab)
DEV_VALUES_SECRETS_B64   - base64 от k8s/overlays/dev/values-secrets.yaml
STAGE_VALUES_SECRETS_B64 - base64 от k8s/overlays/stage/values-secrets.yaml
PROD_VALUES_SECRETS_B64  - base64 от k8s/overlays/prod/values-secrets.yaml
```

#### 2. Регистрация GitLab Runner
```bash
# На k3s нодах
gitlab-runner register \
  --url "http://192.168.0.22" \
  --registration-token "YOUR_TOKEN" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --description "k3s-runner" \
  --tag-list "docker,kubernetes"
```

#### 3. Триггеры деплоя
```bash
# Деплой в dev - автоматически при push в develop
git push origin develop

# Деплой в stage - вручную через GitLab UI
# или через API
curl -X POST \
  -F token=YOUR_TRIGGER_TOKEN \
  -F ref=main \
  https://gitlab.com/api/v4/projects/PROJECT_ID/trigger/pipeline

# Деплой в prod - создание тега
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

## 📊 Мониторинг

### Установка мониторинга
```bash
# Создание namespace
kubectl create namespace monitoring

# Установка Prometheus Stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  -f k8s/base/monitoring/prometheus-values.yaml \
  --namespace monitoring

# Установка PrometheusRules для Odoo
kubectl apply -f k8s/base/monitoring/prometheus-rules.yaml

# Установка Grafana dashboards
kubectl apply -f k8s/base/monitoring/grafana-dashboards-configmap.yaml
```

### Доступ к мониторингу
```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Логин: admin
# Пароль: см. в values.yaml или:
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d
```

### Основные метрики
- CPU/Memory usage per pod
- Request rate и latency
- Error rate (5xx errors)
- Database connections
- Pod restart count
- HPA status

### Настройка алертов
Отредактируйте `k8s/base/monitoring/prometheus-values.yaml`:
```yaml
alertmanager:
  config:
    receivers:
      - name: 'slack-notifications'
        slack_configs:
          - api_url: 'YOUR_SLACK_WEBHOOK_URL'
```

## 🧪 Тестирование

### Unit тесты
```bash
# Запуск локально
cd custom_modules
pytest tests/

# В CI/CD запускается автоматически
```

### Интеграционные тесты
```bash
# Helm template validation
helm template odoo k8s/charts/odoo/ \
  -f k8s/overlays/dev/values.yaml \
  | kubectl apply --dry-run=client -f -
```

### Нагрузочное тестирование

#### k6
```bash
# Простой тест
k6 run k8s/tests/load-test.js

# С параметрами
k6 run --vus 50 --duration 5m \
  -e BASE_URL=https://odoo-stage.local \
  k8s/tests/load-test.js
```

#### Locust
```bash
# Web UI
locust -f k8s/tests/locustfile.py \
  --host https://odoo-stage.local

# Headless
locust -f k8s/tests/locustfile.py \
  --host https://odoo-stage.local \
  --headless \
  --users 100 \
  --spawn-rate 10 \
  --run-time 10m
```

### Тестовое окружение
Для быстрого тестирования новых функций:
```bash
kubectl apply -f k8s/tests/test-deployment.yaml
kubectl port-forward -n odoo-test svc/odoo-test 8069:8069
# Доступ: http://localhost:8069
```

## 🎯 Управление окружениями

### Dev (разработка)
- 1 реплика
- Без persistent storage
- Debug логи
- Автодеплой из develop ветки

### Stage (тестирование)
- 2 реплики
- С persistent storage
- Info логи
- Ручной деплой из main ветки
- Нагрузочное тестирование

### Prod (продакшен)
- 3+ реплик
- Полная персистентность
- Warn/Error логи
- Деплой только по тегам
- High availability
- Auto-scaling

### Переключение между окружениями
```bash
# Смотрим текущий контекст
kubectl config current-context

# Переключаемся на нужный namespace
kubectl config set-context --current --namespace=odoo-prod

# Или используем kubens (если установлен)
kubens odoo-prod
```

## 🔍 Troubleshooting

### Проблемы с Pods

#### Pod не стартует
```bash
# Проверка событий
kubectl describe pod <pod-name> -n <namespace>

# Логи
kubectl logs <pod-name> -n <namespace>

# Логи предыдущего запуска
kubectl logs <pod-name> -n <namespace> --previous

# Exec в контейнер
kubectl exec -it <pod-name> -n <namespace> -- /bin/bash
```

#### ImagePullBackOff
```bash
# Проверка секрета для registry
kubectl get secret -n <namespace>

# Создание секрета
kubectl create secret docker-registry regcred \
  --docker-server=<registry> \
  --docker-username=<username> \
  --docker-password=<password> \
  -n <namespace>
```

#### CrashLoopBackOff
```bash
# Частые причины:
# - Неправильная конфигурация БД
# - Недостаточно ресурсов
# - Проблемы с volumes

# Проверка ресурсов
kubectl top pod -n <namespace>

# Проверка events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Проблемы с сетью

#### Ingress не работает
```bash
# Проверка ingress
kubectl get ingress -n <namespace>
kubectl describe ingress <ingress-name> -n <namespace>

# Проверка NGINX Ingress Controller
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx <nginx-pod>

# Проверка endpoints
kubectl get endpoints -n <namespace>
```

#### DNS не резолвится
```bash
# Тест DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Проверка CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

### Проблемы с БД

#### Connection refused
```bash
# Проверка PostgreSQL pod
kubectl get pods -n <namespace> -l app=postgres

# Логи PostgreSQL
kubectl logs -n <namespace> -l app=postgres

# Проверка сервиса
kubectl get svc -n <namespace>

# Тест подключения из Odoo pod
kubectl exec -it <odoo-pod> -n <namespace> -- \
  psql -h postgres-postgresql -U odoo -d odoo
```

### Проблемы с производительностью

#### Высокая нагрузка на CPU/Memory
```bash
# Топ pods по потреблению
kubectl top pods -n <namespace> --sort-by=cpu
kubectl top pods -n <namespace> --sort-by=memory

# Проверка HPA
kubectl get hpa -n <namespace>
kubectl describe hpa <hpa-name> -n <namespace>

# Масштабирование вручную
kubectl scale deployment <deployment-name> --replicas=5 -n <namespace>
```

#### Медленные запросы
```bash
# Проверка метрик в Prometheus
# http://prometheus.local

# Проверка логов Odoo на медленные запросы
kubectl logs -n <namespace> -l app=odoo | grep -i "slow"
```

## 📞 Полезные команды

### Быстрые команды
```bash
# Получить все ресурсы
kubectl get all -n <namespace>

# Удалить все в namespace
kubectl delete all --all -n <namespace>

# Рестарт deployment
kubectl rollout restart deployment/<deployment-name> -n <namespace>

# История rollout
kubectl rollout history deployment/<deployment-name> -n <namespace>

# Откат на предыдущую версию
kubectl rollout undo deployment/<deployment-name> -n <namespace>

# Watch режим
kubectl get pods -n <namespace> -w

# Широкий вывод
kubectl get pods -n <namespace> -o wide

# JSON вывод
kubectl get pod <pod-name> -n <namespace> -o json

# YAML вывод
kubectl get deployment <deployment-name> -n <namespace> -o yaml
```

### Helm команды
```bash
# Список релизов
helm list -A

# История релиза
helm history <release-name> -n <namespace>

# Откат релиза
helm rollback <release-name> <revision> -n <namespace>

# Удаление релиза
helm uninstall <release-name> -n <namespace>

# Dry-run установки
helm install <release-name> <chart> --dry-run --debug
```

## 🔐 Безопасность

### Рекомендации
1. Измените все дефолтные пароли
2. Используйте secrets вместо hardcoded паролей
3. Включите NetworkPolicies
4. Регулярно обновляйте образы
5. Используйте RBAC для ограничения доступа
6. Регулярное сканирование на уязвимости

### Создание secrets
```bash
# Создание generic secret
kubectl create secret generic odoo-secrets \
  --from-literal=db-password=<password> \
  --from-literal=admin-password=<password> \
  -n <namespace>

# Создание TLS secret
kubectl create secret tls odoo-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n <namespace>
```

## 📝 Лицензия

MIT

## 👥 Контакты

DevOps Team - devops@company.com
