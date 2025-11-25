#!/bin/bash

# Скрипт для развертывания Odoo и мониторинга в k3s

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "=== Развертывание Odoo и мониторинга в k3s ==="
echo ""

# Проверка наличия ansible
if ! command -v ansible-playbook &> /dev/null; then
    echo "Ошибка: ansible-playbook не установлен"
    exit 1
fi

# Проверка наличия inventory
if [ ! -f "ansible/inventory.ini" ]; then
    echo "Ошибка: ansible/inventory.ini не найден"
    exit 1
fi

echo "1. Развертывание Odoo кластера..."
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml \
    --tags odoo \
    --limit k3s_master

echo ""
echo "2. Развертывание мониторинга (Prometheus + Grafana)..."
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml \
    --tags grafana \
    --limit k3s_master

echo ""
echo "=== Развертывание завершено ==="
echo ""
echo "Проверьте статус:"
echo "  ssh yv@10.12.14.15"
echo "  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml"
echo "  kubectl get pods -n odoo"
echo "  kubectl get pods -n monitoring"
echo "  kubectl get svc -n odoo"
echo "  kubectl get svc -n monitoring"
echo ""
echo "Доступ к сервисам:"
echo "  Odoo: kubectl get svc -n odoo odoo (LoadBalancer IP)"
echo "  Grafana: Deployed in Kubernetes (check ingress)"
