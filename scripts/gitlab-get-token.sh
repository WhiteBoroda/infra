#!/bin/bash

# Скрипт для получения runner token из GitLab

GITLAB_IP="${1:-192.168.0.22}"

echo "=== Инструкция по получению GitLab Runner Token ==="
echo ""

# Проверка доступности GitLab
if ! curl -s -o /dev/null -w "%{http_code}" "http://${GITLAB_IP}" | grep -q "200\|302"; then
    echo "⚠️  GitLab недоступен по адресу http://${GITLAB_IP}"
    echo "Проверьте, что GitLab запущен:"
    echo "  ssh yv@${GITLAB_IP} sudo gitlab-ctl status"
    exit 1
fi

echo "✅ GitLab доступен по адресу: http://${GITLAB_IP}"
echo ""

echo "Шаг 1: Получите root пароль"
echo "  ssh yv@${GITLAB_IP}"
echo "  sudo cat /etc/gitlab/initial_root_password"
echo ""
echo "  Если файл не найден (удалён через 24 часа), сбросьте пароль:"
echo "  sudo gitlab-rake \"gitlab:password:reset[root]\""
echo ""

echo "Шаг 2: Войдите в GitLab"
echo "  URL: http://${GITLAB_IP}"
echo "  User: root"
echo "  Password: (из команды выше)"
echo ""

echo "Шаг 3: Получите Runner Token"
echo ""
echo "ВАРИАНТ A - Instance Runner (рекомендуется):"
echo "  1. Нажмите на иконку Admin Area (гаечный ключ) в верхнем меню"
echo "  2. Выберите CI/CD → Runners"
echo "  3. Нажмите 'New instance runner'"
echo "  4. Выберите тип runner (Linux)"
echo "  5. Скопируйте Registration Token"
echo ""

echo "ВАРИАНТ B - Project Runner:"
echo "  1. Создайте новый проект или откройте существующий"
echo "  2. Settings → CI/CD"
echo "  3. Разверните секцию 'Runners'"
echo "  4. Скопируйте Project Registration Token"
echo ""

echo "Шаг 4: Добавьте токен в конфигурацию Ansible"
echo "  Отредактируйте файл: ansible/group_vars/all.yml"
echo "  Найдите строку: gitlab_runner_token: \"\""
echo "  Замените на: gitlab_runner_token: \"ВАШ_ТОКЕН\""
echo ""

echo "Шаг 5: Запустите установку GitLab Runner"
echo "  ./scripts/ansible-runner.sh gitlab-runner"
echo ""

echo "=== Полезные команды ==="
echo "Проверить статус GitLab:"
echo "  ssh yv@${GITLAB_IP} sudo gitlab-ctl status"
echo ""
echo "Перезапустить GitLab:"
echo "  ssh yv@${GITLAB_IP} sudo gitlab-ctl restart"
echo ""
echo "Просмотреть логи:"
echo "  ssh yv@${GITLAB_IP} sudo gitlab-ctl tail"
echo ""
