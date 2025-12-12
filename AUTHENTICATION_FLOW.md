# 🔐 Authentication Flow - SSH Keys & Access Tokens

## 🎯 Complete Authentication Setup

### 2 Types of Authentication Needed:

1. **SSH Keys** - For cloning private repos from GitHub
2. **NPM Token** - For installing private npm packages (`@cloudways-lab`)

---

## 🔑 1. SSH Keys (Git Cloning)

### How It Works:
```
VPS (/root/.ssh)
  └─ id_ed25519 (GitHub SSH key)
       ↓ (mounted read-only into container)
Container (/root/.ssh)
  └─ id_ed25519 (same key)
       ↓ (used to clone)
GitHub (cloudways-lab/platformui-frontend)
```

### Configuration in docker-compose.frontend.yml:
```yaml
volumes:
  - /root/.ssh:/root/.ssh:ro  # Mount VPS SSH keys (read-only)
```

### Usage in Container:
```bash
# Inside setup-deployment.sh
git clone git@github.com:cloudways-lab/platformui-frontend.git
# Uses mounted SSH key automatically ✅
```

### Prerequisites on VPS:
✅ **Already done!** You ran `./scripts/setup-github-ssh.sh` earlier
- Generated SSH key on VPS
- Added public key to GitHub
- Tested SSH connection

---

## 🎫 2. NPM Token (Private Packages)

### Flow:
```
GitHub Actions Secret (GH_NPM_TOKEN)
  ↓ (exported in workflow)
VPS Environment (GITHUB_NPM_TOKEN)
  ↓ (passed to docker compose)
Container Environment (GITHUB_NPM_TOKEN)
  ↓ (used in setup-deployment.sh)
.npmrc files in all packages
```

### GitHub Actions Workflow:
```yaml
env:
  GH_NPM_TOKEN: ${{ secrets.GH_NPM_TOKEN }}
run: |
  export GITHUB_NPM_TOKEN="${{ secrets.GH_NPM_TOKEN }}"
  ./scripts/deploy-frontend.sh deploy ...
```

### Deployment Script:
```bash
# deploy-frontend.sh creates .env file
cat > ".env.${deployment_name}" <<EOF
GITHUB_NPM_TOKEN=${GITHUB_NPM_TOKEN}
EOF
```

### Docker Compose:
```yaml
environment:
  - GITHUB_NPM_TOKEN=${GITHUB_NPM_TOKEN:-}  # From .env file
```

### Container Setup:
```bash
# setup-deployment.sh creates .npmrc files
if [ -n "$GITHUB_NPM_TOKEN" ]; then
  cat > "$dir/.npmrc" <<EOF
//npm.pkg.github.com/:_authToken=${GITHUB_NPM_TOKEN}
@cloudways-lab:registry=https://npm.pkg.github.com/
EOF
fi
```

---

## 🔒 Security

### SSH Keys:
- ✅ Mounted **read-only** (`:ro`)
- ✅ Can't be modified by container
- ✅ Shared across all containers safely
- ✅ Never leaves VPS

### NPM Token:
- ✅ Stored as GitHub Secret
- ✅ Passed via environment variables
- ✅ Not logged or exposed
- ✅ Temporary - only exists during deployment
- ✅ Each container gets its own copy in .npmrc
- ✅ .npmrc files are inside container (not on VPS)

---

## 🧪 Verification Steps

### Check SSH Keys on VPS:
```bash
ssh root@64.227.159.162

# Check SSH key exists
ls -la /root/.ssh/
# Should show: id_ed25519, id_ed25519.pub, known_hosts

# Test GitHub access
ssh -T git@github.com
# Should show: "successfully authenticated"
```

### Check NPM Token:
```bash
# Check GitHub Secret is set
# Go to: https://github.com/rj10940/dev/settings/secrets/actions
# Should show: GH_NPM_TOKEN ✓
```

### Test in Container (after deployment):
```bash
# SSH into VPS
ssh root@64.227.159.162

# Check container has SSH keys
docker exec john-test-frontend ls -la /root/.ssh/
# Should show: id_ed25519, known_hosts

# Check container has npm token
docker exec john-test-frontend cat /app/packages/container/.npmrc
# Should show: //npm.pkg.github.com/:_authToken=ghp_...

# Test GitHub access from container
docker exec john-test-frontend ssh -T git@github.com
# Should work ✅
```

---

## 📋 Prerequisites Checklist:

### On VPS: ✅
- [x] SSH key generated (`/root/.ssh/id_ed25519`)
- [x] Public key added to GitHub (cloudways-lab org)
- [x] GitHub in known_hosts
- [x] Tested: `ssh -T git@github.com` works

### On GitHub Repository: ✅
- [x] Secret `GH_NPM_TOKEN` added (value: `ghp_FHvKb...`)
- [x] Secrets `DO_VPS_HOST`, `DO_VPS_SSH_KEY`, `DO_VPS_USER` configured

### In Deployment System: ✅
- [x] SSH keys mounted in docker-compose
- [x] NPM token passed via environment
- [x] setup-deployment.sh configures both

---

## 🎯 Complete Authentication Flow:

### When GitHub Action Runs:

```bash
1. GitHub Actions
   ├─ Reads GH_NPM_TOKEN secret
   └─ Exports as GITHUB_NPM_TOKEN

2. SSH to VPS
   ├─ Exports GITHUB_NPM_TOKEN
   └─ Runs deploy-frontend.sh

3. Deployment Script
   ├─ Creates .env.john-test
   └─ Includes GITHUB_NPM_TOKEN

4. Docker Compose
   ├─ Reads .env.john-test
   ├─ Mounts /root/.ssh (SSH keys)
   └─ Passes GITHUB_NPM_TOKEN env var

5. Container Starts
   ├─ SSH keys: /root/.ssh (mounted from VPS)
   └─ NPM token: $GITHUB_NPM_TOKEN (env var)

6. setup-deployment.sh Runs
   ├─ Uses SSH keys → git clone (works ✅)
   └─ Uses NPM token → creates .npmrc (works ✅)

7. npm install Runs
   ├─ Reads .npmrc
   └─ Installs @cloudways-lab packages (works ✅)
```

---

## ✅ Summary:

**Both authentication methods ready!**

1. **SSH Keys**: Mounted from VPS `/root/.ssh` → Container `/root/.ssh`
2. **NPM Token**: Passed from GitHub Secret → VPS → Container → .npmrc files

**No manual intervention needed!** Everything flows automatically. 🚀

