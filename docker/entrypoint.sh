#!/bin/bash
# docker/entrypoint.sh

set -e

# Функція для перевірки Redis
wait_for_redis() {
    echo "Waiting for Redis..."
    while ! redis-cli -h ${ODOO_SESSION_REDIS_HOST:-redis} -p ${ODOO_SESSION_REDIS_PORT:-6379} ping > /dev/null 2>&1; do
        echo "Redis is unavailable - sleeping"
        sleep 1
    done
    echo "Redis is up!"
}

# Функція для перевірки PostgreSQL
wait_for_postgres() {
    echo "Waiting for PostgreSQL..."
    while ! pg_isready -h ${HOST:-postgres} -p 5432 -U ${USER:-odoo} > /dev/null 2>&1; do
        echo "PostgreSQL is unavailable - sleeping"
        sleep 1
    done
    echo "PostgreSQL is up!"
}

# Перевірка сервісів
wait_for_postgres
wait_for_redis

# Запуск Odoo
exec "$@"