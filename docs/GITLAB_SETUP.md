# GitLab Setup Guide

## Step 1: Install GitLab

GitLab will be installed automatically by Ansible playbook on `192.168.0.22`.

```bash
cd ansible
ansible-playbook -i inventory.ini playbook.yml
```

This takes ~20-30 minutes. GitLab installation is the slowest part.

## Step 2: Get GitLab Root Password

After installation completes:

```bash
# SSH to GitLab server
ssh ubuntu@192.168.0.22

# Get initial root password
sudo cat /etc/gitlab/initial_root_password
```

**Save this password!** The file will be deleted after 24 hours.

## Step 3: Login to GitLab

1. Open in browser: `http://192.168.0.22`
2. Login:
   - Username: `root`
   - Password: from the file above

## Step 4: Change Root Password (Recommended)

1. Click on your avatar (top right) → **Edit profile**
2. Go to **Password** section
3. Set a new secure password

## Step 5: Get GitLab Runner Registration Token

### For Instance-Wide Runners (Recommended):

1. Go to **Admin Area** (wrench icon in left sidebar)
2. Navigate to **CI/CD** → **Runners**
3. Click **"Register an instance runner"** button
4. Copy the **registration token** (looks like: `GR1348941...`)

### For Project-Specific Runners:

1. Go to your **Project**
2. Navigate to **Settings** → **CI/CD**
3. Expand **Runners** section
4. Copy the **registration token**

## Step 6: Update Ansible Configuration

Edit `ansible/group_vars/all.yml`:

```yaml
gitlab_runner_token: "GR1348941PASTE_YOUR_TOKEN_HERE"
```

## Step 7: Register GitLab Runners

Run Ansible to register runners on k3s nodes:

```bash
cd ansible

# Register runners on k3s nodes
ansible-playbook -i inventory.ini playbook.yml --tags gitlab_runner

# Or pass token via command line
ansible-playbook -i inventory.ini playbook.yml \
  --tags gitlab_runner \
  --extra-vars "gitlab_runner_token=GR1348941YOUR_TOKEN"
```

## Step 8: Verify Runners

1. In GitLab Web UI, go to **Admin Area** → **CI/CD** → **Runners**
2. You should see registered runners:
   - `k3s-runner` from k3s-master (192.168.0.20)
   - `k3s-runner` from k3s-node1 (192.168.0.21)

## Step 9: Create Your First Project

1. Click **"New project"** → **"Create blank project"**
2. Project name: `odoo-cluster`
3. Visibility: **Private**
4. Initialize with README: ✓
5. Click **"Create project"**

## Step 10: Setup Git Remote

```bash
cd /home/user/infra

# Add GitLab remote
git remote add gitlab http://192.168.0.22/root/odoo-cluster.git

# Push to GitLab
git push gitlab main
```

## Step 11: Configure CI/CD Variables

In GitLab project:

1. Go to **Settings** → **CI/CD**
2. Expand **Variables** section
3. Add these variables:

| Key | Value | Protected | Masked |
|-----|-------|-----------|--------|
| `KUBECONFIG_CONTENT` | Base64 encoded kubeconfig | Yes | No |

To get kubeconfig in base64:
```bash
cat ~/.kube/config | base64 -w 0
```

## Step 12: Test CI/CD Pipeline

1. Make a small change in the repo
2. Commit and push:
   ```bash
   git add .
   git commit -m "test: Trigger CI/CD pipeline"
   git push gitlab main
   ```
3. Go to **CI/CD** → **Pipelines** in GitLab
4. Watch your pipeline run!

## Troubleshooting

### Can't access GitLab Web UI

```bash
# Check GitLab status
ssh ubuntu@192.168.0.22
sudo gitlab-ctl status

# Restart GitLab
sudo gitlab-ctl restart

# Check logs
sudo gitlab-ctl tail
```

### Runner registration fails

```bash
# On k3s node
ssh ubuntu@192.168.0.20

# Check runner status
sudo gitlab-runner status

# Verify runner can reach GitLab
curl http://192.168.0.22

# Check runner logs
sudo journalctl -u gitlab-runner -f
```

### Initial password file not found

If you waited too long and the file was deleted:

```bash
# Reset root password
ssh ubuntu@192.168.0.22
sudo gitlab-rake "gitlab:password:reset[root]"
# Enter new password when prompted
```

## New GitLab Runner Token System (GitLab 15.6+)

Starting GitLab 15.6, **registration tokens are deprecated**. If you're using newer GitLab:

### Create Runner Authentication Token:

1. Go to **Admin Area** → **CI/CD** → **Runners**
2. Click **"New instance runner"**
3. Select platform: **Linux**
4. Add tags: `docker`, `kubernetes`
5. Click **"Create runner"**
6. Copy the **runner authentication token** (starts with `glrt-`)

### Register with authentication token:

```bash
gitlab-runner register \
  --url "http://192.168.0.22" \
  --token "glrt-YOUR_AUTHENTICATION_TOKEN" \
  --executor "docker" \
  --description "k3s-runner" \
  --docker-image "docker:latest"
```

Update the Ansible role if using this method.

## Reference

- [GitLab Docs](https://docs.gitlab.com/)
- [GitLab Runner Docs](https://docs.gitlab.com/runner/)
- [GitLab CI/CD Examples](https://docs.gitlab.com/ee/ci/examples/)
