#!/bin/bash
# GitLab Runner Diagnostic Script
# Helps diagnose why GitLab Runner registration fails

set -e

GITLAB_IP="${GITLAB_IP:-10.12.14.17}"
RUNNER_TOKEN="${RUNNER_TOKEN:-}"

echo "=========================================="
echo "GitLab Runner Diagnostic Script"
echo "=========================================="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  Please run as root (sudo)"
    exit 1
fi

echo "1. Checking GitLab Runner installation..."
if command -v gitlab-runner &> /dev/null; then
    RUNNER_VERSION=$(gitlab-runner --version | head -n1)
    echo "   ✅ GitLab Runner installed: $RUNNER_VERSION"
else
    echo "   ❌ GitLab Runner not installed"
    echo "   Install with: curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash && apt install gitlab-runner -y"
    exit 1
fi
echo ""

echo "2. Checking GitLab connectivity..."
if curl -s -f -m 5 "http://${GITLAB_IP}" > /dev/null 2>&1; then
    echo "   ✅ GitLab is reachable at http://${GITLAB_IP}"
else
    echo "   ❌ Cannot reach GitLab at http://${GITLAB_IP}"
    echo "   Check:"
    echo "   - Network connectivity: ping ${GITLAB_IP}"
    echo "   - GitLab is running: ssh to GitLab server and check 'sudo gitlab-ctl status'"
    exit 1
fi
echo ""

echo "3. Checking runner service status..."
if systemctl is-active --quiet gitlab-runner; then
    echo "   ✅ GitLab Runner service is running"
    systemctl status gitlab-runner --no-pager -l | head -n5
else
    echo "   ⚠️  GitLab Runner service is not running"
    echo "   Start with: sudo systemctl start gitlab-runner"
fi
echo ""

echo "4. Checking existing runner configuration..."
if [ -f /etc/gitlab-runner/config.toml ]; then
    echo "   ✅ Runner config file exists"
    echo "   Current configuration:"
    echo "   ---"
    cat /etc/gitlab-runner/config.toml | grep -A 5 "\[\[runners\]\]" || true
    echo "   ---"
    
    # Check if runner is registered
    if gitlab-runner list 2>/dev/null | grep -q "k3s-runner"; then
        echo "   ✅ Runner is registered"
        gitlab-runner list
    else
        echo "   ⚠️  Runner config exists but runner not found in list"
    fi
else
    echo "   ⚠️  No runner configuration found (not registered yet)"
fi
echo ""

echo "5. Checking token format..."
if [ -z "$RUNNER_TOKEN" ]; then
    echo "   ⚠️  RUNNER_TOKEN not set"
    echo "   Set it with: export RUNNER_TOKEN='your-token-here'"
    echo "   Or pass as parameter: $0 RUNNER_TOKEN=your-token"
else
    if [[ "$RUNNER_TOKEN" =~ ^glrt- ]]; then
        echo "   ✅ Token format: New (authentication token - GitLab 15.6+)"
        echo "   Use: gitlab-runner register --token \"$RUNNER_TOKEN\""
    elif [[ "$RUNNER_TOKEN" =~ ^GR ]]; then
        echo "   ✅ Token format: Old (registration token)"
        echo "   Use: gitlab-runner register --registration-token \"$RUNNER_TOKEN\""
    else
        echo "   ⚠️  Unknown token format"
        echo "   Token should start with 'glrt-' (new) or 'GR' (old)"
    fi
fi
echo ""

echo "6. Testing runner verification..."
if [ -f /etc/gitlab-runner/config.toml ]; then
    if gitlab-runner verify 2>&1 | grep -q "is alive"; then
        echo "   ✅ Runner can connect to GitLab"
    else
        echo "   ❌ Runner cannot connect to GitLab"
        echo "   Error output:"
        gitlab-runner verify 2>&1 | tail -n5 || true
    fi
else
    echo "   ⚠️  Skipping (runner not registered)"
fi
echo ""

echo "7. Checking Docker (required for docker executor)..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo "   ✅ Docker installed: $DOCKER_VERSION"
    
    if docker ps > /dev/null 2>&1; then
        echo "   ✅ Docker daemon is accessible"
    else
        echo "   ❌ Cannot access Docker daemon"
        echo "   Check: sudo systemctl status docker"
    fi
else
    echo "   ⚠️  Docker not installed (required for docker executor)"
fi
echo ""

echo "8. Checking recent runner logs..."
if [ -f /etc/gitlab-runner/config.toml ]; then
    echo "   Recent log entries:"
    journalctl -u gitlab-runner -n 20 --no-pager | tail -n10 || true
else
    echo "   ⚠️  No logs (runner not registered)"
fi
echo ""

echo "=========================================="
echo "Diagnostic Summary"
echo "=========================================="
echo ""
echo "If registration is failing, check:"
echo ""
echo "1. Token is correct:"
echo "   - New format (glrt-...): Get from Admin Area → CI/CD → Runners → New instance runner"
echo "   - Old format (GR...): Get from Admin Area → CI/CD → Runners → Register an instance runner"
echo ""
echo "2. GitLab is accessible:"
echo "   curl http://${GITLAB_IP}"
echo ""
echo "3. Runner version is compatible:"
echo "   gitlab-runner --version"
echo ""
echo "4. Try manual registration:"
if [ -n "$RUNNER_TOKEN" ]; then
    if [[ "$RUNNER_TOKEN" =~ ^glrt- ]]; then
        echo "   sudo gitlab-runner register --non-interactive \\"
        echo "     --url \"http://${GITLAB_IP}\" \\"
        echo "     --token \"${RUNNER_TOKEN}\" \\"
        echo "     --executor \"docker\" \\"
        echo "     --description \"k3s-runner-$(hostname)\" \\"
        echo "     --tag-list \"docker,kubernetes\" \\"
        echo "     --docker-image \"docker:latest\" \\"
        echo "     --docker-privileged"
    else
        echo "   sudo gitlab-runner register --non-interactive \\"
        echo "     --url \"http://${GITLAB_IP}\" \\"
        echo "     --registration-token \"${RUNNER_TOKEN}\" \\"
        echo "     --executor \"docker\" \\"
        echo "     --description \"k3s-runner-$(hostname)\" \\"
        echo "     --tag-list \"docker,kubernetes\" \\"
        echo "     --docker-image \"docker:latest\" \\"
        echo "     --docker-privileged"
    fi
else
    echo "   (Set RUNNER_TOKEN first)"
fi
echo ""
echo "5. Check runner in GitLab UI:"
echo "   http://${GITLAB_IP}/admin/runners"
echo ""

