# 🚀 ODS Deployment - Quick Deployment Guide

## Your Configuration

- **VPS IP:** `64.227.159.162`
- **VPS User:** `root`
- **Domain:** `ods.rahuljoshi.info`
- **Deployments accessible at:** `https://<name>.ods.rahuljoshi.info`

---

## ✅ Prerequisites Completed

- ✅ GitHub Secrets configured:
  - `DO_VPS_HOST`: `64.227.159.162`
  - `DO_VPS_SSH_KEY`: Private SSH key for root@64.227.159.162
  - `DO_VPS_USER`: `root`
- ✅ SSH key setup (GitHub Actions → VPS)
- ✅ SSH key setup (VPS → GitHub for private repos)

---

## 🌐 DNS Configuration Required

Add these DNS records to your `rahuljoshi.info` domain:

```
Type: A
Name: *.ods
Value: 64.227.159.162
TTL: 300

Type: A
Name: ods
Value: 64.227.159.162
TTL: 300

Type: A
Name: traefik.ods
Value: 64.227.159.162
TTL: 300
```

**Test after 5-30 minutes:**
```bash
nslookup test.ods.rahuljoshi.info
# Should return: 64.227.159.162
```

---

## 🚀 First Deployment

### Via GitHub Actions:

1. **Go to your repository on GitHub**
2. Click **Actions** tab
3. Select **"🚀 Deploy ODS Frontend"**
4. Click **"Run workflow"**
5. Fill in:
   ```
   Deployment name: rahul-test
   Branch: master
   Auto-destroy: 7 days
   ```
6. Click **"Run workflow"**
7. Wait ~5-10 minutes
8. Access: **`https://rahul-test.ods.rahuljoshi.info`**

### Via Direct SSH (Alternative):

```bash
# SSH as root
ssh root@64.227.159.162

# First time only - setup
cd /opt/ods-deployments
chmod +x scripts/*.sh
sudo ./scripts/setup-vps.sh  # If not done yet
./scripts/setup-traefik.sh

# Deploy
./scripts/deploy-frontend.sh deploy rahul-test master rahul 7
```

---

## 📊 Management Commands

### List all deployments
```bash
ssh root@64.227.159.162
cd /opt/ods-deployments
./scripts/deploy-frontend.sh list
```

### View logs
```bash
docker logs <deployment-name>-frontend -f
```

### Destroy a deployment
```bash
./scripts/deploy-frontend.sh destroy <deployment-name>
```

### Check Traefik dashboard
```
https://traefik.ods.rahuljoshi.info
```

---

## 🐛 Troubleshooting

### Deployment fails
```bash
# Check GitHub Actions logs first
# Then SSH to VPS:
ssh root@64.227.159.162
cd /opt/ods-deployments

# Check if scripts are there
ls -la scripts/

# Check Docker
docker ps
docker logs traefik

# Check deployment
./scripts/deploy-frontend.sh list
```

### SSL certificate issues
```bash
# Check Traefik logs
docker logs traefik | grep acme

# Verify DNS
nslookup your-deployment.ods.rahuljoshi.info
```

---

## 🎯 Expected Results

After successful deployment:

1. **Frontend accessible:** `https://rahul-test.ods.rahuljoshi.info`
2. **API calls go to:** `https://rj8-dev-ux.cloudways.services`
3. **SSL certificate:** Automatic (Let's Encrypt)
4. **Auto-destroy:** After 7 days (or configured duration)

---

## 🔒 Security Notes

- All connections use HTTPS
- Root access is secured via SSH key (no password)
- GitHub Actions can only run deployment scripts
- Each deployment is isolated in its own Docker network

---

## 📞 Support

1. Check GitHub Actions logs
2. SSH to VPS and check Docker logs
3. Run: `./scripts/check-system.sh`
4. Review deployment registry: `sqlite3 deployments/registry.db "SELECT * FROM deployments"`

---

**Ready to deploy!** 🚀

