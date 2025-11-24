# Управление секретами для Helm overlays

## Почему вынесли пароли из values.yaml

- В репозитории больше нет захардкоженных паролей/логинов.
- Любая установка Helm теперь требует отдельного файла `values-secrets.yaml` или передачи значений через переменные окружения.
- Шаблон `secret.yaml` использует `required`, поэтому сборка остановится, если пароль не задан.

## Как работать локально

1. Скопируйте пример для нужного окружения:
   ```bash
   cp k8s/overlays/dev/values-secrets.example.yaml k8s/overlays/dev/values-secrets.yaml
   ```
2. Заполните реальные значения (файл добавлен в `.gitignore`, в репозиторий не попадёт).
3. При установке Helm добавьте `-f k8s/overlays/<env>/values-secrets.yaml`.

## Как работать в GitLab CI

1. Добавьте переменные в **Settings → CI/CD → Variables**:
   - `DEV_VALUES_SECRETS_B64`
   - `STAGE_VALUES_SECRETS_B64`
   - `PROD_VALUES_SECRETS_B64`
2. В значение помещайте base64 от соответствующего `values-secrets.yaml`.
3. Pipeline автоматически сгенерирует `values-secrets.ci.yaml` и прокинет его в `helm upgrade`.
4. Никакие секреты не лежат в репозитории.

## Структура файла values-secrets.yaml

```yaml
odoo:
  database:
    password: "<odoo db password>"
  adminPassword: "<odoo admin password>"

postgresql:
  auth:
    password: "<postgresql superuser password>"
```

> По необходимости можно расширить файл дополнительными секретами (например, Redis).


