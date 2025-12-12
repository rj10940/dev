# 🎛️ Traefik Dashboard Access Guide

## 🌐 Access Methods

### Method 1: Via Subdomain (After DNS Setup)
Once you configure DNS:
```
https://traefik.ods.rahuljoshi.info
```

This will show:
- All active routers
- All services
- All deployments
- Health status
- SSL certificates

---

### Method 2: Direct IP Access (Works Now!)
```
http://64.227.159.162:8080
```

**⚠️ Note:** Port 8080 is currently open to public! 
**Recommendation:** Add authentication or close this port after DNS is configured.

---

## 📊 What You'll See in Dashboard

### 1. **HTTP Routers**
Shows all active routes:
```
dashboard@docker          → traefik.ods.rahuljoshi.info
test3-fe@docker          → test3.ods.rahuljoshi.info  
user-deployment-fe@docker → user-deployment.ods.rahuljoshi.info
```

### 2. **Services**
Shows backend services and their health:
```
test3-fe@docker → http://172.18.0.2:80 (healthy)
```

### 3. **Entrypoints**
```
web (80)       → HTTP
websecure (443) → HTTPS
```

---

## 🔒 Secure Dashboard (Recommended)

Currently dashboard has `--api.insecure=true` which means no authentication.

### To add basic auth:

```bash
# On VPS
ssh root@64.227.159.162

# Generate password hash
docker run --rm httpd:alpine htpasswd -nb admin YOUR_PASSWORD

# Add to docker-compose.traefik.yml labels:
- "traefik.http.middlewares.dashboard-auth.basicauth.users=admin:$$apr1$$..."
- "traefik.http.routers.dashboard.middlewares=dashboard-auth"
```

---

## 📋 Quick Commands

### Check Active Deployments:
```bash
curl -s http://64.227.159.162:8080/api/http/routers | \
  jq '.[] | select(.provider == "docker") | {name, rule, status}'
```

### Check Service Health:
```bash
curl -s http://64.227.159.162:8080/api/http/services | \
  jq '.[] | select(.provider == "docker")'
```

### Check All Containers:
```bash
ssh root@64.227.159.162 "docker ps"
```

---

## 🎯 Current Deployments Visible:

Based on the dashboard, you currently have:

1. **traefik** (Traefik itself)
   - Subdomain: `traefik.ods.rahuljoshi.info`
   - Status: Running
   - Router: `dashboard@docker`

2. **test3-frontend** (Test deployment)
   - Subdomain: `test3.ods.rahuljoshi.info`
   - Status: Healthy
   - Router: `test3-fe@docker`
   - Backend: `http://172.18.0.2:80`

---

## 🚀 After GitHub Actions Deploy:

When someone deploys via GitHub Actions with deployment name `john-feature`:

The dashboard will automatically show:
```
Router: john-feature-fe@docker
Rule:   Host(`john-feature.ods.rahuljoshi.info`)
Service: john-feature-fe@docker
Status: enabled
Backend: http://172.18.0.X:80
```

**Real-time updates!** No manual registration needed - Traefik auto-discovers containers.

---

## 🧪 Test Dashboard Access Now:

```bash
# Open in browser:
http://64.227.159.162:8080

# Or use curl:
curl http://64.227.159.162:8080/api/overview | jq '.'
```

---

## 📍 DNS Configuration Reminder:

To access via subdomain:
```
Type: A Record
Host: *.ods.rahuljoshi.info
Value: 64.227.159.162
```

This will enable:
- `https://traefik.ods.rahuljoshi.info` → Dashboard
- `https://test3.ods.rahuljoshi.info` → Test deployment
- `https://any-name.ods.rahuljoshi.info` → Future deployments

