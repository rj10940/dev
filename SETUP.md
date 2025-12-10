# Cloudways Developer Environment Setup Guide

## Overview

This guide walks through setting up a shared Docker-based developer environment on a DigitalOcean droplet where each developer gets isolated containers with their own branch configurations.

---

## Step 1: Generate Deploy Key

Run the key generation script:

```bash
chmod +x scripts/generate-deploy-key.sh
sudo ./scripts/generate-deploy-key.sh
```

This creates:
- `/opt/cloudways-dev/keys/github_deploy_key` (private key)
- `/opt/cloudways-dev/keys/github_deploy_key.pub` (public key)
- `/opt/cloudways-dev/keys/config` (SSH config)

---

## Step 2: Add Deploy Key to GitHub

### Option A: Per-Repository Deploy Keys

For each repository, add the deploy key:

1. Go to the repo on GitHub
2. Settings → Deploy Keys → Add deploy key
3. Title: `cloudways-dev-droplet`
4. Paste the content of `github_deploy_key.pub`
5. Check "Allow write access" if needed

Repositories to add:
- [ ] cloudways-lab/cg-console-new (or bitbucket cloudways_dev/cg-console-new)
- [ ] cloudways-lab/cg-apiserver
- [ ] cloudways-lab/flexible-middleware
- [ ] cloudways-lab/flexible-operation-engine
- [ ] cloudways-lab/ansible-api-v2
- [ ] cloudways-lab/cg-event-service
- [ ] cloudways-lab/cg-comms-service
- [ ] cloudways-lab/platformui-frontend

### Option B: Organization Machine User (Recommended)

1. Create a GitHub account: `cloudways-dev-bot@yourcompany.com`
2. Add to your GitHub organization with read access to all repos
3. Add the SSH key to this user's account: Settings → SSH Keys
4. Authorize the key for SSO if required

---

## Step 3: Provision DigitalOcean Droplet

### Recommended Specs

| Developers | Droplet Size | RAM | CPUs | Cost/Month |
|------------|--------------|-----|------|------------|
| 2-3 | s-4vcpu-8gb | 8GB | 4 | $48 |
| 4-6 | s-8vcpu-16gb | 16GB | 8 | $96 |
| 7-10 | m-4vcpu-32gb | 32GB | 4 | $168 |

### Create via CLI

```bash
# Install doctl if not present
# brew install doctl  # macOS
# snap install doctl  # Ubuntu

# Authenticate
doctl auth init

# Create droplet
doctl compute droplet create cloudways-dev \
  --size s-8vcpu-16gb \
  --image ubuntu-22-04-x64 \
  --region nyc1 \
  --ssh-keys YOUR_SSH_KEY_ID \
  --tag-names "dev,cloudways"
```

### Create via Web Console

1. Go to https://cloud.digitalocean.com/droplets/new
2. Choose Ubuntu 22.04 LTS
3. Select size based on team size (16GB recommended)
4. Choose a datacenter near your team
5. Add your SSH key for access
6. Name it `cloudways-dev`

---

## Step 4: Install Dependencies on Droplet

SSH into the droplet and run:

```bash
ssh root@DROPLET_IP
```

Then run the setup script:

```bash
curl -fsSL https://raw.githubusercontent.com/your-repo/dev-environment/main/scripts/setup-droplet.sh | bash
```

Or manually:

```bash
# Update system
apt-get update && apt-get upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | bash

# Install Docker Compose v2
apt-get install -y docker-compose-plugin

# Install utilities
apt-get install -y jq git

# Install yq (YAML processor)
wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
chmod +x /usr/bin/yq

# Create directory structure
mkdir -p /opt/cloudways-dev/{keys,developers,repos,scripts}

# Add current user to docker group
usermod -aG docker $USER
```

---

## Step 5: Clone Repositories

```bash
cd /opt/cloudways-dev/repos
export GIT_SSH_COMMAND="ssh -i /opt/cloudways-dev/keys/github_deploy_key -o StrictHostKeyChecking=no"

# Clone all repos
git clone git@github.com:cloudways-lab/cg-console-new.git
git clone git@github.com:cloudways-lab/cg-apiserver.git
git clone git@github.com:cloudways-lab/flexible-middleware.git
git clone git@github.com:cloudways-lab/flexible-operation-engine.git
git clone git@github.com:cloudways-lab/ansible-api-v2.git
git clone git@github.com:cloudways-lab/cg-event-service.git
git clone git@github.com:cloudways-lab/cg-comms-service.git
git clone git@github.com:cloudways-lab/platformui-frontend.git
```

---

## Step 6: Start Shared Services

```bash
cd /opt/cloudways-dev
docker compose -f shared/docker-compose.yml up -d
```

This starts:
- MySQL 8.0 (shared-mysql)
- Redis 7 (shared-redis)
- PostgreSQL 15 (shared-postgres)
- Traefik reverse proxy

---

## Step 7: Create Developer Environment

```bash
# Create your environment
./scripts/dev-env.sh create rahul

# Edit your branches (optional)
nano /opt/cloudways-dev/developers/rahul.yml

# Re-run to apply
./scripts/dev-env.sh create rahul
```

---

## Usage

### Create New Developer Environment

```bash
./scripts/dev-env.sh create <developer-name>
```

### Update Branch for a Repo

```bash
./scripts/dev-env.sh update-branch <developer> <repo> <branch>

# Example:
./scripts/dev-env.sh update-branch rahul cg-console-new feature/new-feature
```

### Pull Latest Code

```bash
./scripts/dev-env.sh pull <developer>
```

### View Logs

```bash
./scripts/dev-env.sh logs <developer>
```

### Check Status

```bash
./scripts/dev-env.sh status <developer>
```

### Destroy Environment

```bash
./scripts/dev-env.sh destroy <developer>
```

---

## Access URLs

Each developer gets unique URLs:

| Service | URL Pattern |
|---------|-------------|
| Platform UI | `http://<developer>.dev.cw.local` |
| API | `http://api-<developer>.dev.cw.local` |

Add to your local `/etc/hosts`:
```
DROPLET_IP  rahul.dev.cw.local api-rahul.dev.cw.local
DROPLET_IP  john.dev.cw.local api-john.dev.cw.local
```

Or use the Traefik dashboard at `http://DROPLET_IP:8080`

---

## Troubleshooting

### Container won't start
```bash
docker logs <developer>-platform
```

### Database connection issues
```bash
docker exec shared-mysql mysql -uroot -proot -e "SHOW DATABASES;"
```

### Branch checkout failed
```bash
cd /opt/cloudways-dev/repos/<repo>
git fetch --all
git branch -a  # List all branches
```

### Reset developer environment
```bash
./scripts/dev-env.sh destroy <developer>
./scripts/dev-env.sh create <developer>
```

