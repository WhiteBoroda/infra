# Руководство по развертыванию Odoo кластера

## Пошаговое руководство для быстрого старта

### Шаг 1: Подготовка

#### 1.1. Установка необходимых инструментов

**На macOS:**
```bash
# Terraform
brew install terraform

# Ansible
brew install ansible

# kubectl
brew install kubectl

# helm
brew install helm
```

**На Ubuntu/Debian:**
```bash
# Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform

# Ansible
sudo apt install ansible

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

#### 1.2. Подготовка Proxmox

1. Создайте API токен:
   - Datacenter → API Tokens → Add
   - User: root@pam
   - Token ID: terraform
   - Privilege Separation: NO
   - Сохраните Secret!

2. Создайте Cloud-Init template:
```bash
# На Proxmox сервере
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
qm create 9000 --name ubuntu-22.04-cloudinit --memory 2048 --net0 virtio,bridge=vmbr0
qm importdisk 9000 jammy-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9000-disk-0
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --boot c --bootdisk scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1
qm template 9000
```

#### 1.3. Генерация SSH ключей (если нет)
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### Шаг 2: Клонирование и настройка проекта

```bash
# Клонируем репозиторий
git clone <repository-url>
cd infra

# Настраиваем Terraform
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Редактируем terraform.tfvars
vim terraform.tfvars
```

Пример содержимого `terraform.tfvars`:
```hcl
pm_api_url          = "https://192.168.0.100:8006/api2/json"
pm_api_token_id     = "root@pam!terraform"
pm_api_token_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
target_node         = "pve"
storage             = "local-lvm"
template_name       = "ubuntu-22.04-cloudinit"
ssh_pubkey_path     = "~/.ssh/id_rsa.pub"
```

### Шаг 3: Автоматическое развертывание

#### Вариант A: Полностью автоматически (рекомендуется для первого раза)
```bash
cd /home/user/infra
./scripts/setup-infrastructure.sh
```

Этот скрипт:
1. Проверит все зависимости
2. Создаст VM через Terraform
3. Настроит их через Ansible
4. Установит k3s кластер
5. Развернет мониторинг
6. Развернет Odoo в dev окружении

**Время выполнения:** ~30-40 минут

#### Вариант B: Пошаговое развертывание

##### B.1. Создание инфраструктуры
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Будут созданы:
- k3s-master (192.168.0.20) - 4 CPU, 8GB RAM
- k3s-node1 (192.168.0.21) - 4 CPU, 8GB RAM
- gitlab (192.168.0.22) - 4 CPU, 8GB RAM
- monitoring (192.168.0.23) - 2 CPU, 4GB RAM
- redis LXC (192.168.0.24) - 2 CPU, 1GB RAM
- postgres (192.168.0.25) - 4 CPU, 8GB RAM

##### B.2. Подождите готовности VM
```bash
# Подождите 2-3 минуты для загрузки
sleep 180

# Проверка доступности
cd ../ansible
ansible all -i inventory.ini -m ping
```

##### B.3. Настройка с Ansible
```bash
# Запуск playbook (займет 20-30 минут)
ansible-playbook -i inventory.ini playbook.yml
```

Ansible установит и настроит:
- k3s кластер (master + worker)
- GitLab
- GitLab Runners
- Базовый мониторинг
- Redis
- NGINX Ingress + MetalLB
- Cert-Manager

##### B.4. Настройка kubectl
```bash
# Копируем kubeconfig
mkdir -p ~/.kube
cp /tmp/k3s.yaml ~/.kube/config

# Заменяем localhost на IP мастера
sed -i '' 's/127.0.0.1/192.168.0.20/g' ~/.kube/config

# Проверка
kubectl get nodes
```

Ожидаемый вывод:
```
NAME         STATUS   ROLES                  AGE   VERSION
k3s-master   Ready    control-plane,master   5m    v1.28.x+k3s1
k3s-node1    Ready    <none>                 4m    v1.28.x+k3s1
```

### Шаг 4: Развертывание мониторинга

```bash
cd /home/user/infra

# Создание namespace
kubectl create namespace monitoring

# Добавление Helm репозиториев
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Установка Prometheus Stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  -f k8s/base/monitoring/prometheus-values.yaml \
  --namespace monitoring \
  --wait \
  --timeout 10m

# Применение custom правил для Odoo
kubectl apply -f k8s/base/monitoring/prometheus-rules.yaml

# Получение пароля Grafana
kubectl get secret -n monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d

# Доступ к Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Открыть: http://localhost:3000
# Логин: admin, Пароль: из команды выше
```

### Шаг 5: Развертывание Odoo

#### 5.0. Подготовка secrets-файлов

Для каждого окружения есть шаблон `k8s/overlays/<env>/values-secrets.example.yaml`.

```bash
cp k8s/overlays/dev/values-secrets.example.yaml k8s/overlays/dev/values-secrets.yaml
cp k8s/overlays/stage/values-secrets.example.yaml k8s/overlays/stage/values-secrets.yaml
cp k8s/overlays/prod/values-secrets.example.yaml k8s/overlays/prod/values-secrets.yaml
```

Заполните пароль БД и администратора Odoo. Файлы `values-secrets.yaml` добавлены в `.gitignore`, поэтому не попадут в репозиторий.

#### Development окружение
```bash
# Создание namespace
kubectl create namespace odoo-dev

# Деплой через Helm
helm install odoo-dev k8s/charts/odoo/ \
  -f k8s/overlays/dev/values.yaml \
  -f k8s/overlays/dev/values-secrets.yaml \
  --namespace odoo-dev \
  --wait \
  --timeout 15m

# Или через скрипт
./scripts/deploy.sh -e dev

# Проверка
kubectl get all -n odoo-dev

# Доступ
kubectl port-forward -n odoo-dev svc/odoo-dev 8069:8069
# Открыть: http://localhost:8069
```

#### Staging окружение
```bash
./scripts/deploy.sh -e stage

# Доступ
kubectl port-forward -n odoo-stage svc/odoo-stage 8070:8069
```

#### Production окружение
```bash
# ВАЖНО: Перед деплоем в прод!
vim k8s/overlays/prod/values-secrets.yaml
# Измените:
# - odoo.database.password
# - odoo.adminPassword
# - postgresql.auth.password

./scripts/deploy.sh -e prod

# Доступ
kubectl port-forward -n odoo-prod svc/odoo-prod 8071:8069
```

### Шаг 6: Настройка GitLab CI/CD

#### 6.1. Получить root пароль GitLab
```bash
ssh ubuntu@192.168.0.22
sudo cat /etc/gitlab/initial_root_password
```

#### 6.2. Доступ к GitLab
Откройте в браузере: http://192.168.0.22
- Username: root
- Password: из предыдущей команды

#### 6.3. Создание проекта
1. New Project → Create blank project
2. Project name: odoo-cluster
3. Visibility: Private
4. Create project

#### 6.4. Push кода
```bash
cd /home/user/infra
git remote add gitlab http://192.168.0.22/root/odoo-cluster.git
git push gitlab main
```

#### 6.5. Настройка CI/CD переменных
Settings → CI/CD → Variables:

```bash
# Получаем kubeconfig в base64
cat ~/.kube/config | base64

# Добавляем в GitLab:
# Name: KUBECONFIG_CONTENT
# Value: <base64 string>
# Protected: Yes
# Masked: No

# Получаем secrets в base64 (пример для dev)
cat k8s/overlays/dev/values-secrets.yaml | base64 -w 0

# Добавляем переменные:
# DEV_VALUES_SECRETS_B64
# STAGE_VALUES_SECRETS_B64
# PROD_VALUES_SECRETS_B64
```

#### 6.6. Регистрация Runner
```bash
# Получить registration token
# GitLab → Settings → CI/CD → Runners → Expand

# На k3s-master или k3s-node1
ssh ubuntu@192.168.0.20

sudo gitlab-runner register \
  --url "http://192.168.0.22" \
  --registration-token "YOUR_TOKEN_HERE" \
  --executor "docker" \
  --docker-image "alpine:latest" \
  --description "k3s-runner" \
  --tag-list "docker,kubernetes" \
  --docker-privileged
```

### Шаг 7: Проверка работоспособности

#### 7.1. Проверка Odoo
```bash
# Dev
kubectl get pods -n odoo-dev
kubectl logs -n odoo-dev -l app.kubernetes.io/name=odoo --tail=50

# Проверка БД подключения
kubectl exec -it -n odoo-dev deployment/odoo-dev-web -- psql \
  -h postgres-postgresql -U odoo -d odoo -c "SELECT version();"
```

#### 7.2. Проверка мониторинга
```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# http://localhost:9090

# Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# http://localhost:3000

# AlertManager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
# http://localhost:9093
```

#### 7.3. Проверка Ingress
```bash
kubectl get ingress -A
kubectl get svc -n ingress-nginx
```

### Шаг 8: Настройка DNS (опционально)

#### Локальная настройка (для тестирования)
Добавьте в `/etc/hosts`:
```
192.168.0.20 odoo-dev.local
192.168.0.20 odoo-stage.local
192.168.0.20 odoo-prod.local
192.168.0.20 grafana.local
192.168.0.20 prometheus.local
```

#### Настройка в локальной сети
Если у вас есть DNS сервер, добавьте A записи:
```
odoo-dev.local    → 192.168.0.20
odoo-stage.local  → 192.168.0.20
odoo-prod.local   → 192.168.0.20
grafana.local     → 192.168.0.20
prometheus.local  → 192.168.0.20
```

### Шаг 9: Тестирование

#### 9.1. Тестовое окружение
```bash
# Деплой тестового окружения
kubectl apply -f k8s/tests/test-deployment.yaml

# Проверка
kubectl get all -n odoo-test

# Доступ
kubectl port-forward -n odoo-test svc/odoo-test 8072:8069
```

#### 9.2. Нагрузочное тестирование

**k6:**
```bash
# Установка k6
brew install k6  # macOS
# или
wget https://github.com/grafana/k6/releases/download/v0.47.0/k6-v0.47.0-linux-amd64.tar.gz
tar -xzf k6-v0.47.0-linux-amd64.tar.gz
sudo mv k6-v0.47.0-linux-amd64/k6 /usr/local/bin/

# Запуск теста
k6 run k8s/tests/load-test.js
```

**Locust:**
```bash
# Установка
pip3 install locust

# Запуск с UI
locust -f k8s/tests/locustfile.py --host http://localhost:8069

# Headless режим
locust -f k8s/tests/locustfile.py \
  --host http://localhost:8069 \
  --headless \
  --users 50 \
  --spawn-rate 5 \
  --run-time 5m
```

## Troubleshooting

### Проблема: VM не создаются
```bash
# Проверьте логи Terraform
terraform apply -parallelism=1

# Проверьте доступ к Proxmox API
curl -k https://192.168.0.100:8006/api2/json/version
```

### Проблема: Ansible не может подключиться
```bash
# Проверьте SSH ключи
ssh ubuntu@192.168.0.20

# Проверьте cloud-init
ssh ubuntu@192.168.0.20 'sudo cloud-init status'
```

### Проблема: Pods не стартуют
```bash
# Проверьте события
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Проверьте логи
kubectl logs -n <namespace> <pod-name>

# Проверьте ресурсы
kubectl describe node
kubectl top nodes
```

### Проблема: Нет доступа к Ingress
```bash
# Проверьте MetalLB
kubectl get pods -n metallb-system

# Проверьте NGINX Ingress
kubectl get pods -n ingress-nginx

# Проверьте IP адреса
kubectl get svc -n ingress-nginx
kubectl get ingress -A
```

## Что дальше?

1. **Настройка бэкапов** - используйте Velero
2. **Настройка SSL сертификатов** - настройте Let's Encrypt
3. **Добавление custom модулей** - создайте каталог `custom_modules/`
4. **Настройка Slack уведомлений** - в prometheus-values.yaml
5. **Масштабирование** - добавьте больше worker нод

## Полезные ссылки

- [K3s документация](https://docs.k3s.io/)
- [Helm документация](https://helm.sh/docs/)
- [Odoo документация](https://www.odoo.com/documentation/17.0/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
