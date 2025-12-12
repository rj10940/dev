# 🚀 ODS Automated Deployment System - Frontend

**Complete automation for ODS frontend deployments with GitHub Actions**

---

## ✨ Features

- ✅ **Branch-based deployments** - Deploy any branch from platformui-frontend
- ✅ **GitHub Actions integration** - One-click deployments from GitHub UI
- ✅ **Automatic API configuration** - All requests → `rj8-dev-ux.cloudways.services`
- ✅ **Traefik reverse proxy** - Automatic HTTPS with Let's Encrypt
- ✅ **Sequential submodule cloning** - Ubuntu-compatible, no parallel operations
- ✅ **Deployment limits** - 50 total deployments, 3 per user
- ✅ **Auto-cleanup** - Deployments auto-delete after configured days
- ✅ **Zero code changes** - Works with main/master branches of all submodules

---

## 📋 What's Been Created

### File Structure
```
dev/
├── 📖 Documentation
│   ├── README.md              # This file - Overview
│   ├── QUICKSTART.md          # Quick start guide
│   └── SETUP_GUIDE.md         # Complete setup instructions
│
├── 🐳 Docker Configuration
│   ├── docker-compose.traefik.yml    # Traefik reverse proxy
│   ├── docker-compose.frontend.yml   # Frontend container
│   └── nginx/default.conf            # Nginx SPA configuration
│
├── 🔧 Scripts
│   ├── check-system.sh               # Pre-flight validation
│   ├── deploy-frontend.sh            # Main deployment script
│   ├── install-deps-ubuntu.sh        # Sequential npm install
│   ├── setup-traefik.sh              # Traefik initialization
│   ├── setup-vps.sh                  # VPS initial setup
│   └── test-local-build.sh           # Local testing
│
├── 🚀 GitHub Actions
│   └── .github/workflows/
│       └── deploy-frontend.yml       # Deployment workflow
│
└── ⚙️ Configuration
    ├── env.template                  # Environment template
    └── .gitignore                    # Git ignore rules
```

---

## 🎯 Quick Start

### 1️⃣ Test Locally (Recommended First Step)

```bash
cd /home/rahuljoshi/CW/dev

# Check system requirements
./scripts/check-system.sh

# Test build with master branch
./scripts/test-local-build.sh master
```

**Expected output:** `✅ Build Successful!`

### 2️⃣ Setup VPS (One-Time)

```bash
# SSH to your VPS
ssh user@your-vps-ip

# Copy files to VPS
# (from your local machine)
scp -r /home/rahuljoshi/CW/dev/* user@your-vps:/opt/ods-deployments/

# OR clone from GitHub
git clone https://github.com/your-org/ods-deployments.git /opt/ods-deployments

# Run setup
cd /opt/ods-deployments
sudo ./scripts/setup-vps.sh

# Setup Traefik
./scripts/setup-traefik.sh
```

### 3️⃣ Configure DNS

Add these records to your DNS provider:

```
Type: A     Name: *.dev.cloudways.com     Value: YOUR_VPS_IP
Type: A     Name: dev.cloudways.com       Value: YOUR_VPS_IP
Type: A     Name: traefik.dev.cloudways.com   Value: YOUR_VPS_IP
```

### 4️⃣ Configure GitHub Secrets

Repository → Settings → Secrets and variables → Actions:

| Secret | Value | Description |
|--------|-------|-------------|
| `VPS_SSH_KEY` | `-----BEGIN OPENSSH PRIVATE KEY-----...` | SSH private key |
| `VPS_HOST` | `123.45.67.89` | VPS IP or hostname |
| `VPS_USER` | `ubuntu` | SSH username |

### 5️⃣ Deploy!

**Via GitHub Actions (Recommended):**
1. Go to repository → **Actions** tab
2. Select **"🚀 Deploy ODS Frontend"**
3. Click **"Run workflow"**
4. Fill in:
   - **Deployment name:** `rahul-feature-123`
   - **Branch:** `feature/new-dashboard` (or `master`)
   - **Auto-destroy:** `7` days
5. Click **"Run workflow"**
6. Wait ~5-10 minutes ⏳
7. Access: `https://rahul-feature-123.dev.cloudways.com` 🎉

**Via SSH (Alternative):**
```bash
ssh user@your-vps
cd /opt/ods-deployments
./scripts/deploy-frontend.sh deploy rahul-test master rahul 7
```

---

## 📊 Management

### List All Deployments
```bash
./scripts/deploy-frontend.sh list
```

### View Logs
```bash
docker logs <deployment-name>-frontend -f
```

### Destroy Deployment
```bash
./scripts/deploy-frontend.sh destroy <deployment-name>
```

### Check System Status
```bash
./scripts/check-system.sh
```

### Access Traefik Dashboard
```
https://traefik.dev.cloudways.com
```

---

## 🔧 Configuration

### API Endpoints (Hardcoded)
All deployments automatically use:
- **API v1:** `https://rj8-dev-ux.cloudways.services/api/v1/`
- **API v2:** `https://rj8-dev-ux.cloudways.services/api/v2/`
- **Console:** `https://rj8-dev-ux.cloudways.services/`

### Submodules
All submodules use `master` or `main` branch:
- `packages/flexible`
- `packages/fmp-ux3`
- `packages/unified-design-system`
- `packages/guests-app-ux3`
- `packages/agencyos-ux3`

### Deployment Limits
- **Total:** 50 concurrent deployments
- **Per user:** 3 concurrent deployments
- **Auto-destroy:** Configurable (1-30 days or never)

---

## 🐛 Troubleshooting

### Build fails locally
```bash
# Check Node.js version
node --version  # Should be 20.x or higher

# Test dependencies installation
cd /home/rahuljoshi/CW/dev
./scripts/install-deps-ubuntu.sh master
```

### Deployment fails on VPS
```bash
# Check logs
ssh user@vps
cd /opt/ods-deployments
docker logs <deployment-name>-frontend

# Check Traefik
docker logs traefik

# Verify DNS
nslookup your-deployment.dev.cloudways.com
```

### SSL certificate issues
```bash
# Check certificate status
docker logs traefik | grep acme

# Verify DNS propagation (wait 5-30 minutes)
dig your-deployment.dev.cloudways.com
```

### Port conflicts
```bash
# Check what's using ports
lsof -i :80
lsof -i :443

# Stop conflicting services
sudo systemctl stop apache2  # or nginx
```

---

## 📚 Documentation

- **[QUICKSTART.md](./QUICKSTART.md)** - Fast-track guide with all details
- **[SETUP_GUIDE.md](./SETUP_GUIDE.md)** - Complete step-by-step setup
- **This README** - Overview and quick reference

---

## ✅ System Requirements

### Local Development
- Node.js 20.x or higher
- npm 10.x or higher
- Git
- Bash shell

### VPS/Server
- Ubuntu 20.04 or 22.04
- 4+ CPU cores
- 8+ GB RAM
- 50+ GB disk space
- Docker & Docker Compose
- Root/sudo access

---

## 🎯 What Makes This Special

1. **No Code Changes** - Works with existing repos at master/main
2. **Sequential Operations** - No parallel operations that fail on some systems
3. **Fully Automated** - One click from GitHub Actions
4. **Production-Ready** - Automatic HTTPS, health checks, monitoring
5. **Developer-Friendly** - Simple CLI, clear error messages
6. **Resource-Aware** - Limits prevent overloading the server

---

## 🚦 Current Status

- ✅ All scripts created and tested
- ✅ Local build test successful
- ✅ Submodules clone sequentially
- ✅ API configuration correct
- ✅ GitHub Actions workflow ready
- ✅ Docker configuration complete
- ⏳ Waiting for VPS setup
- ⏳ Waiting for DNS configuration

---

## 🔐 Security Notes

- SSH keys should be dedicated to this deployment system
- Traefik dashboard protected by subdomain (add auth if needed)
- Deployments isolated via Docker networks
- Auto-cleanup prevents resource exhaustion
- All connections use HTTPS with valid certificates

---

## 📞 Support

1. **Check documentation:** QUICKSTART.md, SETUP_GUIDE.md
2. **Run diagnostics:** `./scripts/check-system.sh`
3. **View logs:** `docker logs <container-name>`
4. **GitHub Actions logs:** Repository → Actions tab

---

## 🎉 Ready to Deploy!

Everything is complete and tested. Start with:

```bash
cd /home/rahuljoshi/CW/dev
./scripts/test-local-build.sh master
```

Then push to GitHub and deploy! 🚀

