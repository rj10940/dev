# 🔑 GitHub Token Setup

## ✅ Token Integration Complete!

Your GitHub NPM token has been integrated into the deployment system.

**⚠️ IMPORTANT:** The actual token should be stored as a GitHub Secret (see below), never committed to code.

---

## 🎯 How It Works

### Automatic .npmrc Configuration

When deploying, the script automatically creates `.npmrc` files for ALL micro-frontends:

```
packages/
├── container/.npmrc          ✅ Created
├── flexible/.npmrc           ✅ Created
├── fmp-ux3/.npmrc            ✅ Created
├── unified-design-system/.npmrc  ✅ Created
├── agencyos-ux3/.npmrc       ✅ Created
└── guests-app-ux3/.npmrc     ✅ Created
```

Each `.npmrc` contains:
```
//npm.pkg.github.com/:_authToken=YOUR_GITHUB_TOKEN_HERE
@cloudways-lab:registry=https://npm.pkg.github.com/
```

This allows npm to install private packages from `@cloudways-lab` organization.

---

## 🚀 Usage Options

### Option 1: Add as GitHub Secret (Recommended) ⭐

1. Go to repository → **Settings** → **Secrets and variables** → **Actions**
2. Click **"New repository secret"**
3. Name: `GITHUB_NPM_TOKEN`
4. Value: `ghp_FHvKb...` (your token)
5. Click **"Add secret"**

**Then in workflow:** Token is used automatically (no need to enter it)

---

### Option 2: Enter Token in Workflow (Manual)

When running workflow:
```
Deployment name: rahul-test
platformui-frontend: master
...
github_npm_token: ghp_YOUR_TOKEN_HERE
```

---

### Option 3: Set on VPS (For direct SSH deployments)

```bash
ssh root@64.227.159.162

# Set environment variable
export GITHUB_NPM_TOKEN="ghp_YOUR_TOKEN_HERE"

# Deploy
cd /opt/ods-deployments
./scripts/deploy-frontend.sh deploy rahul-test master rahul 7
```

Or add to root's profile:
```bash
echo 'export GITHUB_NPM_TOKEN="ghp_YOUR_TOKEN_HERE"' >> /root/.bashrc
```

---

## 🔒 Security

The token is:
- ✅ **Never committed to git** (.npmrc files are in .gitignore)
- ✅ **Passed securely** via environment variables
- ✅ **Cleaned up** after deployment (removed from logs)
- ✅ **Scoped** to read:packages only

---

## ⚠️ Important Notes

1. **Token scope required:** `read:packages`
2. **SSO authorization:** Must authorize for `cloudways-lab` organization
3. **Token expiration:** Check GitHub for expiry date
4. **Rotate regularly:** For security, rotate every 90 days

---

## 🎯 Recommended Setup

**Add token as GitHub Secret** (Option 1) so:
- ✅ All team members can deploy
- ✅ No need to enter token each time
- ✅ Token is centrally managed
- ✅ Easy to rotate (just update secret)

---

**Token is ready to use!** 🚀

