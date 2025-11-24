#!/bin/bash

# Универсальный скрипт для запуска Ansible playbook с разными параметрами

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

show_help() {
    echo "Использование: $0 [команда]"
    echo ""
    echo "Команды:"
    echo "  all           - Запустить все роли на всех хостах"
    echo "  k3s           - Установить/обновить k3s кластер"
    echo "  odoo          - Развернуть Odoo (разные модули на разных нодах)"
    echo "  monitoring    - Развернуть standalone мониторинг (на 192.168.0.23)"
    echo "  grafana       - Развернуть мониторинг в k3s (Prometheus + Grafana)"
    echo "  ingress       - Установить NGINX Ingress и cert-manager"
    echo "  dashboard     - Установить Kubernetes Dashboard (GUI)"
    echo "  gitlab        - Установить GitLab"
    echo "  gitlab-runner - Установить GitLab Runner"
    echo "  redis         - Настроить Redis"
    echo ""
    echo "Примеры:"
    echo "  $0 odoo           # Развернуть только Odoo"
    echo "  $0 grafana        # Развернуть только мониторинг в k3s"
    echo "  $0 all            # Запустить всё"
    exit 0
}

# Проверка наличия ansible
if ! command -v ansible-playbook &> /dev/null; then
    echo "Ошибка: ansible-playbook не установлен"
    exit 1
fi

case "${1:-}" in
    all)
        echo "=== Запуск всех ролей ==="
        ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
        ;;
    k3s)
        echo "=== Установка/обновление k3s ==="
        ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags k3s
        ;;
    odoo)
        echo "=== Развертывание Odoo ==="
        ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags odoo --limit k3s_master
        ;;
    monitoring)
        echo "=== Развертывание standalone мониторинга ==="
        ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags monitoring --limit monitoring
        ;;
    grafana)
        echo "=== Развертывание мониторинга в k3s ==="
        ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags grafana --limit k3s_master
        ;;
    ingress)
        echo "=== Установка NGINX Ingress ==="
        ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags ingress --limit k3s_master
        ;;
    dashboard)
        echo "=== Установка Kubernetes Dashboard ==="
        ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags dashboard --limit k3s_master
        ;;
    gitlab)
        echo "=== Установка GitLab ==="
        ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags gitlab --limit gitlab
        ;;
    gitlab-runner)
        echo "=== Установка GitLab Runner ==="
        ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags gitlab_runner
        ;;
    redis)
        echo "=== Настройка Redis ==="
        ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags redis --limit redis
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Неизвестная команда: ${1:-}"
        echo "Используйте '$0 help' для списка команд"
        exit 1
        ;;
esac

echo ""
echo "=== Готово ==="
