# GitLab CI/CD Variables Configuration

## Required Variables

Add these variables in GitLab: **Settings > CI/CD > Variables**

### 1. Kubernetes Access

| Variable Name | Value | Type | Protected | Masked | Description |
|--------------|-------|------|-----------|--------|-------------|
| `KUBECONFIG_CONTENT` | `<base64 encoded kubeconfig>` | Variable | ✅ Yes | ❌ No | Base64-encoded k3s kubeconfig |

**How to get**: Run `bash scripts/setup-gitlab-runner-k3s.sh`

### 2. Docker Registry

| Variable Name | Value | Type | Protected | Masked | Description |
|--------------|-------|------|-----------|--------|-------------|
| `CI_REGISTRY` | `registry.gitlab.hd.local` | Variable | ❌ No | ❌ No | GitLab registry URL |
| `CI_REGISTRY_USER` | `<your-gitlab-username>` | Variable | ✅ Yes | ❌ No | GitLab username |
| `CI_REGISTRY_PASSWORD` | `<your-gitlab-token>` | Variable | ✅ Yes | ✅ Yes | GitLab access token |

**How to create token**: GitLab > User Settings > Access Tokens > Create with `read_registry`, `write_registry` scopes

### 3. Database Passwords

| Variable Name | Value | Type | Protected | Masked | Description |
|--------------|-------|------|-----------|--------|-------------|
| `POSTGRES_ODOO_PASSWORD` | `<strong-password>` | Variable | ✅ Yes | ✅ Yes | PostgreSQL odoo user password |
| `ODOO_ADMIN_PASSWORD` | `<strong-password>` | Variable | ✅ Yes | ✅ Yes | Odoo admin password |

**Note**: These should match passwords in Ansible vault and Kubernetes secrets

### 4. Domain Configuration (Optional)

| Variable Name | Value | Type | Protected | Masked | Description |
|--------------|-------|------|-----------|--------|-------------|
| `DOMAIN_BASE` | `hd.local` | Variable | ❌ No | ❌ No | Base domain for deployments |

## Variable Groups by Environment

### Development
- All variables with Protected = No
- Used for feature branch deployments

### Staging
- All variables with Protected = Yes
- Only available on `main` branch

### Production
- All variables with Protected = Yes
- Only available on tags (e.g., `v1.0.0`)

## Security Best Practices

1. **Never commit secrets** to git repository
2. **Use Protected variables** for production
3. **Rotate passwords** regularly
4. **Use Masked variables** for sensitive data (if length allows)
5. **Limit variable scope** to specific branches/tags

## Testing Variables

To test if variables are set correctly:

```yaml
test:variables:
  stage: test
  script:
    - echo "Registry: $CI_REGISTRY"
    - echo "Kubeconfig length: ${#KUBECONFIG_CONTENT}"
    - echo "Postgres password set: $([ -n "$POSTGRES_ODOO_PASSWORD" ] && echo 'Yes' || echo 'No')"
  only:
    - branches
```

## Troubleshooting

### KUBECONFIG_CONTENT not working
- Ensure it's base64 encoded: `echo "$KUBECONFIG" | base64 -w 0`
- Check that server URL points to k3s master IP (10.12.14.15)

### Registry authentication fails
- Verify CI_REGISTRY_USER has access to project
- Check token has correct scopes
- Ensure token hasn't expired

### Kubernetes deployment fails
- Check ServiceAccount `gitlab-runner` exists in `kube-system` namespace
- Verify ClusterRoleBinding is created
- Test kubeconfig manually: `kubectl --kubeconfig=<decoded> get nodes`
