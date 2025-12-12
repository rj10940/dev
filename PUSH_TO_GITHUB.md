# Push to GitHub - Instructions

## 📋 Repository Setup

You need to create a GitHub repository and push this code. Here's how:

---

## Option 1: Create New Repository on GitHub

### Step 1: Create Repository on GitHub.com

1. Go to **https://github.com/new**
2. Repository name: `ods-deployment-system` (or any name you prefer)
3. Description: `Automated ODS Frontend Deployment System`
4. Visibility: **Private** (recommended) or Public
5. **DON'T** initialize with README, .gitignore, or license
6. Click **Create repository**

### Step 2: Push Your Code

GitHub will show you commands. Use these:

```bash
cd /home/rahuljoshi/CW/dev

# Add remote (replace YOUR-USERNAME with your GitHub username)
git remote add origin git@github.com:YOUR-USERNAME/ods-deployment-system.git

# Or if you want to use HTTPS:
# git remote add origin https://github.com/YOUR-USERNAME/ods-deployment-system.git

# Rename branch to main (if needed)
git branch -M main

# Push
git push -u origin main
```

**Example with actual username:**
```bash
# If your GitHub username is 'rahuljoshi44'
git remote add origin git@github.com:rahuljoshi44/ods-deployment-system.git
git branch -M main
git push -u origin main
```

---

## Option 2: Use Existing Repository

If you want to add this to an existing repo:

```bash
cd /home/rahuljoshi/CW/dev

# Add remote
git remote add origin git@github.com:YOUR-ORG/YOUR-REPO.git

# Push to a specific branch
git push origin local:ods-deployment

# Or push to main
git branch -M main
git push -u origin main
```

---

## ✅ After Pushing

### 1. Verify Workflow File

Go to your repository on GitHub:
- Navigate to **Actions** tab
- You should see: **"🚀 Deploy ODS Frontend"** workflow

### 2. Enable Actions (if needed)

If Actions are disabled:
- Go to **Settings** → **Actions** → **General**
- Select: **Allow all actions and reusable workflows**
- Click **Save**

### 3. Test the Workflow

- Click **Actions** tab
- Click **"🚀 Deploy ODS Frontend"**
- Click **"Run workflow"** button (right side)
- Fill in:
  ```
  Deployment name: test-deploy
  Branch: master
  Auto-destroy: 1 day
  ```
- Click **"Run workflow"**
- Watch it run!

---

## 🐛 If Push Fails

### SSH Key Issues

```bash
# Check if you have SSH key for GitHub
ls -la ~/.ssh/id_ed25519.pub

# If not, generate one:
ssh-keygen -t ed25519 -C "your-email@example.com"
cat ~/.ssh/id_ed25519.pub

# Add to GitHub:
# GitHub → Settings → SSH and GPG keys → New SSH key
```

### HTTPS Authentication

If using HTTPS and it asks for password:

```bash
# GitHub no longer accepts passwords
# Use Personal Access Token instead:

# 1. Create token: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
# 2. Generate new token with 'repo' scope
# 3. Copy the token
# 4. Use as password when pushing

# Or configure credential helper:
git config --global credential.helper store
# Then push - it will ask once and remember
```

---

## 📝 Repository Structure After Push

Your GitHub repo will contain:

```
ods-deployment-system/
├── .github/workflows/
│   └── deploy-frontend.yml       ← GitHub Actions workflow
├── scripts/
│   ├── deploy-frontend.sh        ← Main deployment script
│   ├── setup-traefik.sh          ← Traefik setup
│   └── ...                       ← Other helper scripts
├── docker-compose.traefik.yml
├── docker-compose.frontend.yml
├── README.md
├── DEPLOYMENT_GUIDE.md
└── ...
```

---

## 🚀 Next Steps After Pushing

1. **Configure DNS** (if not done yet):
   ```
   *.ods.rahuljoshi.info  →  64.227.159.162
   ```

2. **Setup VPS** (first time only):
   ```bash
   ssh root@64.227.159.162
   
   # Clone your repo
   cd /opt
   git clone git@github.com:YOUR-USERNAME/ods-deployment-system.git ods-deployments
   
   # Or if already have scripts from GitHub Actions:
   # They will be copied automatically on first deployment
   ```

3. **Trigger First Deployment**:
   - Go to GitHub → Actions
   - Run workflow
   - Deploy name: `rahul-test`
   - Branch: `master`

4. **Access**:
   - Wait ~5-10 minutes
   - Open: `https://rahul-test.ods.rahuljoshi.info`

---

## ✅ Verification Checklist

Before first deployment, ensure:

- ✅ Code pushed to GitHub
- ✅ GitHub Secrets configured (DO_VPS_HOST, DO_VPS_SSH_KEY, DO_VPS_USER)
- ✅ DNS records added (*.ods.rahuljoshi.info → 64.227.159.162)
- ✅ SSH key on VPS for GitHub access (VPS → GitHub)
- ✅ GitHub Actions enabled in repository

---

## 📞 Need Help?

Common issues and solutions in **DEPLOYMENT_GUIDE.md**

**Ready to push and deploy!** 🚀

