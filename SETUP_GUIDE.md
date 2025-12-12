# ODS Deployment System - Complete Setup Guide

## 🎯 Overview

Automated deployment system for ODS Frontend with:
- ✅ GitHub Actions for one-click deployments
- ✅ Traefik for automatic HTTPS and subdomain routing
- ✅ Branch-based deployments
- ✅ API calls pointing to: `rj8-dev-ux.cloudways.services`
- ✅ Per-user deployment limits (3 per user, 50 total)

---

## 📋 Prerequisites

1. **VPS/Server Requirements:**
   - Ubuntu 20.04 or 22.04
   - 4+ CPU cores
   - 8+ GB RAM
   - 50+ GB disk space
   - Root/sudo access

2. **Domain:**
   - Domain name (e.g., `dev.cloudways.com`)
   - Access to DNS management

3. **GitHub:**
   - Repository with this code
   - GitHub Actions enabled
   - SSH key for VPS access

---

## 🚀 Initial Setup (One-Time)

### Step 1: VPS Setup

SSH to your VPS and run:

```bash
# Download and run setup script
curl -fsSL https://raw.githubusercontent.com/your-org/ods-deployments/main/scripts/setup-vps.sh -o setup-vps.sh
chmod +x setup-vps.sh
sudo ./setup-vps.sh
```

This installs:
- Docker & Docker Compose
- Node.js & npm
- Required system packages
- Creates `/opt/ods-deployments` directory

### Step 2: Deploy Code to VPS

```bash
# SSH to VPS
ssh user@your-vps-ip

# Clone the deployment repository
cd /opt
sudo git clone https://github.com/your-org/ods-deployments.git
sudo chown -R $USER:$USER ods-deployments
cd ods-deployments
```

### Step 3: Setup Traefik

```bash
cd /opt/ods-deployments
chmod +x scripts/*.sh
./scripts/setup-traefik.sh
```

This will:
- Create Docker network
- Start Traefik with automatic HTTPS
- Configure Let's Encrypt

### Step 4: Configure DNS

Add these DNS records to your domain:

```
Type: A
Name: *.dev
Value: YOUR_VPS_IP
TTL: 300

Type: A
Name: dev
Value: YOUR_VPS_IP
TTL: 300

Type: A
Name: traefik.dev
Value: YOUR_VPS_IP
TTL: 300
```

Wait 5-30 minutes for DNS propagation.

### Step 5: Configure GitHub Secrets

Go to your GitHub repository → Settings → Secrets and add:

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `VPS_SSH_KEY` | Private SSH key for VPS | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `VPS_HOST` | VPS IP or hostname | `123.45.67.89` or `dev.cloudways.com` |
| `VPS_USER` | SSH username | `ubuntu` or `root` |

---

## 👤 Developer Usage

### Method 1: GitHub Actions (Recommended)

1. **Go to GitHub Actions:**
   - Navigate to your repository
   - Click "Actions" tab
   - Select "🚀 Deploy ODS Frontend"

2. **Click "Run workflow"**

3. **Fill in the form:**
   ```
   Deployment name: rahul-new-feature
   Branch: feature/new-dashboard
   Auto-destroy: 7 days
   ```

4. **Click "Run workflow"** button

5. **Wait ~5-10 minutes**
   - Watch the workflow progress
   - Check the summary for deployment URL

6. **Access your deployment:**
   ```
   https://rahul-new-feature.dev.cloudways.com
   ```

### Method 2: Direct VPS Deployment

SSH to VPS and run:

```bash
cd /opt/ods-deployments
./scripts/deploy-frontend.sh deploy <name> <branch> <owner> [days]

# Example:
./scripts/deploy-frontend.sh deploy rahul-test master rahul 7
```

---

## 📊 Monitoring & Management

### List All Deployments

```bash
cd /opt/ods-deployments
./scripts/deploy-frontend.sh list
```

Output:
```
=== Active Deployments ===
name                  owner   url                                           branch  created_at
--------------------  ------  --------------------------------------------  ------  -------------------
rahul-feature-123     rahul   https://rahul-feature-123.dev.cloudways.com   master  2025-01-10 14:30:00
john-bugfix-456       john    https://john-bugfix-456.dev.cloudways.com     develop 2025-01-10 15:45:00
```

### View Deployment Logs

```bash
# View frontend logs
docker logs <deployment-name>-frontend -f

# Example:
docker logs rahul-feature-123-frontend -f
```

### Destroy a Deployment

```bash
cd /opt/ods-deployments
./scripts/deploy-frontend.sh destroy <deployment-name>

# Example:
./scripts/deploy-frontend.sh destroy rahul-feature-123
```

### Access Traefik Dashboard

```
https://traefik.dev.cloudways.com
```

Shows all active routes and SSL certificate status.

---

## 🔧 How It Works

### 1. Deployment Flow

```
GitHub Actions
     ↓
SSH to VPS
     ↓
Clone platformui-frontend (specific branch)
     ↓
Update git submodules (flexible, fmp, etc.)
     ↓
Install dependencies (npm install)
     ↓
Update .env.development (API URLs)
     ↓
Build frontend (npm run build:dev)
     ↓
Create Docker container (nginx)
     ↓
Traefik detects container
     ↓
Request SSL certificate
     ↓
Route traffic: subdomain.dev.cloudways.com → container
```

### 2. API Configuration

All API calls are automatically configured to:
- **API v1:** `https://rj8-dev-ux.cloudways.services/api/v1/`
- **API v2:** `https://rj8-dev-ux.cloudways.services/api/v2/`
- **Console:** `https://rj8-dev-ux.cloudways.services/`

This is set in the `.env.development` file during build.

### 3. Submodules

All submodules are checked out to their `master` or `main` branch:
- `packages/flexible`
- `packages/fmp-ux3`
- `packages/unified-design-system`
- `packages/guests-app-ux3`
- `packages/agencyos-ux3`

### 4. Deployment Limits

- **Total:** 50 concurrent deployments
- **Per User:** 3 concurrent deployments
- **Auto-cleanup:** Deployments auto-delete after configured days

---

## 🐛 Troubleshooting

### Deployment Failed

1. **Check GitHub Actions logs:**
   - Go to Actions tab
   - Click on failed workflow
   - Check each step for errors

2. **Common issues:**
   - **SSH connection failed:** Check `VPS_SSH_KEY` secret
   - **Port already in use:** Destroy old deployment first
   - **Build failed:** Check if branch exists and is valid

### SSL Certificate Not Working

1. **Check DNS propagation:**
   ```bash
   nslookup your-deployment.dev.cloudways.com
   ```

2. **Check Traefik logs:**
   ```bash
   docker logs traefik
   ```

3. **Verify Let's Encrypt rate limits:**
   - Max 50 certificates per domain per week
   - Use staging for testing

### Frontend Not Loading

1. **Check container status:**
   ```bash
   docker ps | grep <deployment-name>
   ```

2. **Check frontend logs:**
   ```bash
   docker logs <deployment-name>-frontend
   ```

3. **Verify build output:**
   ```bash
   ls -la /opt/ods-deployments/repos/platformui-frontend/packages/container/dist
   ```

### API Calls Failing

1. **Check API URL in browser console:**
   - Open Developer Tools → Network tab
   - Check if requests go to `rj8-dev-ux.cloudways.services`

2. **Verify .env.development:**
   ```bash
   cat /opt/ods-deployments/repos/platformui-frontend/packages/container/.env.development
   ```

---

## 📁 File Structure

```
/opt/ods-deployments/
├── README.md
├── SETUP_GUIDE.md (this file)
├── docker-compose.traefik.yml
├── docker-compose.frontend.yml
├── env.template
├── .env.deployment-name (generated per deployment)
├── scripts/
│   ├── setup-vps.sh
│   ├── setup-traefik.sh
│   ├── install-deps-ubuntu.sh
│   └── deploy-frontend.sh
├── .github/
│   └── workflows/
│       └── deploy-frontend.yml
├── nginx/
│   └── default.conf
├── traefik/
│   └── letsencrypt/
│       └── acme.json
├── deployments/
│   └── registry.db (SQLite database)
└── repos/
    └── platformui-frontend/ (cloned repos)
```

---

## 🔒 Security Notes

1. **SSH Keys:**
   - Use dedicated SSH key for GitHub Actions
   - Restrict key to specific commands if possible
   - Rotate keys regularly

2. **Firewall:**
   - Only expose ports: 22 (SSH), 80 (HTTP), 443 (HTTPS)
   - Consider using port 8080 only from specific IPs for Traefik dashboard

3. **Deployment Limits:**
   - Enforced to prevent resource exhaustion
   - Monitored via SQLite database

4. **Auto-cleanup:**
   - Old deployments auto-delete to free resources
   - Set appropriate retention based on your needs

---

## 🎓 Quick Reference

### Deploy Frontend
```bash
# Via GitHub Actions
Actions → Deploy ODS Frontend → Run workflow

# Via SSH
./scripts/deploy-frontend.sh deploy <name> <branch> <owner> [days]
```

### List Deployments
```bash
./scripts/deploy-frontend.sh list
```

### Destroy Deployment
```bash
./scripts/deploy-frontend.sh destroy <name>
```

### View Logs
```bash
docker logs <deployment-name>-frontend -f
```

### Restart Deployment
```bash
docker restart <deployment-name>-frontend
```

### Update Traefik
```bash
cd /opt/ods-deployments
docker-compose -f docker-compose.traefik.yml pull
docker-compose -f docker-compose.traefik.yml up -d
```

---

## 📞 Support

For issues or questions:
1. Check troubleshooting section above
2. Review GitHub Actions workflow logs
3. Check VPS logs: `docker logs <container-name>`
4. Contact DevOps team

---

## 🔄 Updates

To update the deployment system:

```bash
cd /opt/ods-deployments
git pull origin main
chmod +x scripts/*.sh
```

Existing deployments will continue to work with old scripts.

