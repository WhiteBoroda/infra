# Testing Guide

This document describes the testing strategy and implementation for the Odoo Infrastructure project.

## Table of Contents

- [Overview](#overview)
- [Test Types](#test-types)
- [Running Tests Locally](#running-tests-locally)
- [CI/CD Integration](#cicd-integration)
- [Test Coverage](#test-coverage)
- [Adding New Tests](#adding-new-tests)

## Overview

Our testing strategy follows a multi-layered approach to ensure infrastructure reliability:

1. **Linting & Static Analysis** - Code quality and syntax validation
2. **Unit Tests** - Individual component testing
3. **Integration Tests** - Component interaction testing
4. **Container Tests** - Docker image validation
5. **Smoke Tests** - Post-deployment health checks
6. **Performance Tests** - Load and stress testing
7. **Security Tests** - Vulnerability scanning and compliance

## Test Types

### 1. Terraform Validation

**Location:** `terraform/`
**Purpose:** Validate Infrastructure as Code before provisioning

**Run locally:**
```bash
cd terraform
terraform init -backend=false
terraform validate
terraform fmt -check
```

**What it checks:**
- Terraform syntax validity
- Resource configuration correctness
- Code formatting standards

### 2. Ansible Testing with Molecule

**Location:** `ansible/roles/*/molecule/`
**Purpose:** Test Ansible roles in isolation

**Run locally:**
```bash
# Install Molecule
pip install molecule molecule-docker ansible-lint

# Test a specific role
cd ansible/roles/k3s
molecule test

# Test all roles
for role in ansible/roles/*/; do
    cd "$role"
    molecule test
    cd -
done
```

**Test scenarios:**
- Role execution in Docker container
- Idempotency verification
- Service validation
- Configuration verification

**Available role tests:**
- `k3s` - Kubernetes installation
- `gitlab` - GitLab setup
- `redis` - Redis installation
- `odoo_cluster` - Odoo deployment

### 3. Shell Script Testing

**Location:** `scripts/tests/`
**Purpose:** Validate bash scripts with BATS

**Run locally:**
```bash
# Install BATS
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local

# Run tests
cd scripts
bats tests/
```

**What it checks:**
- Script syntax validation (via shellcheck)
- Function existence
- Argument parsing
- Error handling
- Exit codes

**Test files:**
- `deploy.bats` - Deployment script tests
- `setup-infrastructure.bats` - Infrastructure setup tests

### 4. Helm Chart Tests

**Location:** `k8s/charts/odoo/templates/tests/`
**Purpose:** Validate Kubernetes deployments

**Run locally:**
```bash
# Deploy and test
helm upgrade --install odoo-test k8s/charts/odoo/ \
  -f k8s/overlays/dev/values.yaml \
  --namespace test \
  --create-namespace

# Run tests
helm test odoo-test --namespace test --logs

# Cleanup
helm uninstall odoo-test --namespace test
```

**Test pods:**
- `test-connection.yaml` - HTTP endpoint connectivity
- `test-database.yaml` - PostgreSQL connection
- `test-redis.yaml` - Redis connection (if enabled)

### 5. Container Structure Tests

**Location:** `docker/tests/container-structure-test.yaml`
**Purpose:** Validate Docker image contents and structure

**Run locally:**
```bash
# Install container-structure-test
curl -LO https://storage.googleapis.com/container-structure-test/latest/container-structure-test-linux-amd64
chmod +x container-structure-test-linux-amd64
sudo mv container-structure-test-linux-amd64 /usr/local/bin/container-structure-test

# Build image
docker build -t test-odoo:latest -f docker/Dockerfile.odoo .

# Run tests
container-structure-test test \
  --image test-odoo:latest \
  --config docker/tests/container-structure-test.yaml
```

**What it checks:**
- Required binaries existence (odoo-bin, python3, pip3)
- Directory structure
- File permissions
- Environment variables
- Exposed ports
- Python dependencies installation

### 6. Smoke Tests

**Location:** `scripts/smoke-tests.sh`
**Purpose:** Post-deployment validation

**Run locally:**
```bash
# Run smoke tests for dev environment
bash scripts/smoke-tests.sh odoo-dev

# Run for staging
bash scripts/smoke-tests.sh odoo-stage

# Run for production
bash scripts/smoke-tests.sh odoo-prod
```

**Test scenarios:**
1. Namespace existence
2. Pod health status
3. Service endpoint availability
4. PostgreSQL connectivity
5. Redis connectivity (if enabled)
6. HTTP endpoint accessibility
7. Persistent Volume Claims status
8. ConfigMaps and Secrets existence

### 7. Load/Performance Tests

**Location:** `k8s/tests/`
**Purpose:** Validate system performance under load

**K6 Load Test:**
```bash
k6 run --vus 10 --duration 30s k8s/tests/load-test.js
```

**Locust Load Test:**
```bash
locust -f k8s/tests/locustfile.py \
  --headless \
  --users 100 \
  --spawn-rate 10 \
  --run-time 5m \
  --host https://odoo-stage.local
```

### 8. Security Tests

**Trivy Container Scanning:**
```bash
trivy image --severity HIGH,CRITICAL registry.local/odoo:latest
```

**Kubernetes CIS Benchmark:**
```bash
kube-bench run --targets node,policies
```

## CI/CD Integration

All tests are automatically executed in the GitLab CI/CD pipeline:

### Pipeline Stages

```
lint → build → test → security → deploy-dev → deploy-stage → deploy-prod → performance-test
```

### Lint Stage

- `lint:yaml` - YAML validation
- `lint:helm` - Helm chart linting
- `lint:ansible` - Ansible playbook linting
- `lint:terraform` - Terraform validation
- `lint:shellcheck` - Shell script linting

### Test Stage

- `test:unit` - Python unit tests (if custom modules exist)
- `test:bats` - Shell script tests
- `test:integration` - Kubernetes manifest validation
- `test:container-structure` - Docker image validation
- `test:helm-tests` - Helm chart tests

### Security Stage

- `security:trivy` - Container vulnerability scanning
- `security:kube-bench` - Kubernetes security benchmarks

### Deploy Stages

Each deployment stage includes:
- Deployment to environment
- Smoke tests execution
- Environment stop (manual)

### Performance Test Stage

- `performance:k6` - K6 load tests (scheduled)
- `performance:locust` - Locust load tests (scheduled)

## Test Coverage

### Current Coverage Summary

| Layer | Coverage | Tests Available |
|-------|----------|----------------|
| Infrastructure (Terraform) | ✅ 100% | Validation, formatting |
| Configuration (Ansible) | ✅ 80% | Molecule tests for 4 key roles |
| Scripts | ✅ 100% | BATS tests, shellcheck |
| Kubernetes (Helm) | ✅ 90% | Template validation, test hooks |
| Containers (Docker) | ✅ 90% | Structure tests, Trivy scanning |
| Integration | ✅ 85% | Smoke tests, K8s validation |
| Performance | ✅ 100% | K6 and Locust tests |
| Security | ✅ 100% | Trivy, kube-bench |

## Adding New Tests

### Adding a New Molecule Test

```bash
# Navigate to role directory
cd ansible/roles/your_role

# Create molecule scenario
molecule init scenario -d docker

# Customize molecule/default/molecule.yml
# Add verification tasks in molecule/default/verify.yml
# Test the role
molecule test
```

### Adding a New BATS Test

```bash
# Create test file
cat > scripts/tests/your_script.bats << 'EOF'
#!/usr/bin/env bats

@test "your test description" {
    run your_command
    [ "$status" -eq 0 ]
}
EOF

# Make executable
chmod +x scripts/tests/your_script.bats

# Run test
bats scripts/tests/your_script.bats
```

### Adding a New Helm Test

```yaml
# Create k8s/charts/odoo/templates/tests/test-your-feature.yaml
apiVersion: v1
kind: Pod
metadata:
  name: "{{ include "odoo.fullname" . }}-test-your-feature"
  annotations:
    "helm.sh/hook": test
    "helm.sh/hook-delete-policy": before-hook-creation,hook-succeeded
spec:
  containers:
    - name: test
      image: appropriate/curl
      command: ['curl']
      args: ['http://{{ include "odoo.fullname" . }}:8069/your-endpoint']
  restartPolicy: Never
```

### Adding Container Structure Tests

Edit `docker/tests/container-structure-test.yaml`:

```yaml
commandTests:
  - name: 'your command test'
    command: 'your-command'
    args: ['--version']
    expectedOutput: ['version.*']

fileExistenceTests:
  - name: 'your file test'
    path: '/path/to/file'
    shouldExist: true
```

## Best Practices

1. **Test Locally First** - Always run tests locally before pushing
2. **Keep Tests Fast** - Unit tests should run in seconds
3. **Make Tests Reliable** - Avoid flaky tests
4. **Document Test Purpose** - Clear descriptions in test names
5. **Use Mocks Appropriately** - Mock external dependencies
6. **Test Edge Cases** - Don't just test happy paths
7. **Keep Tests Maintainable** - Refactor tests as code changes
8. **Monitor Test Coverage** - Aim for >80% coverage

## Troubleshooting

### Common Issues

**Molecule tests fail with Docker connection error:**
```bash
# Ensure Docker is running
sudo systemctl start docker
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

**BATS tests not found:**
```bash
# Install BATS
brew install bats-core  # macOS
apt-get install bats    # Ubuntu/Debian
```

**Container structure test fails:**
```bash
# Check image exists
docker images | grep odoo
# Rebuild if necessary
docker build -t test-odoo:latest -f docker/Dockerfile.odoo .
```

**Helm tests timeout:**
```bash
# Increase timeout
helm test odoo-test --timeout 10m
# Check pod logs
kubectl logs -n test $(kubectl get pods -n test -l helm.sh/chart=odoo -o name)
```

## Resources

- [Molecule Documentation](https://molecule.readthedocs.io/)
- [BATS Documentation](https://bats-core.readthedocs.io/)
- [Container Structure Test](https://github.com/GoogleContainerTools/container-structure-test)
- [Helm Test Documentation](https://helm.sh/docs/topics/chart_tests/)
- [K6 Documentation](https://k6.io/docs/)
- [Locust Documentation](https://docs.locust.io/)

## Support

For questions or issues with testing:
1. Check this documentation
2. Review CI/CD pipeline logs
3. Consult team documentation
4. Create an issue in the repository
