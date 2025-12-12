# 🧪 Testing GitHub Action Deployment

## What Happens When You Run the GitHub Action:

### 1. **GitHub Action Triggers** (`workflow_dispatch`)
You provide:
- Deployment name: `john-test`
- Branch names for repos
- Auto-destroy days

### 2. **SSH to VPS and Run Script**
```bash
cd /opt/ods-deployments
./scripts/deploy-frontend.sh deploy john-test master john 7 master master master master master
```

### 3. **Script Execution Flow:**

```bash
# 1. Clone/update repos
prepare_frontend_repo "master"
update_submodules "master" "master" "master" "master" "master"

# 2. Install dependencies  
install_dependencies

# 3. Update API URLs
update_env_file "john-test"  
# Updates all .env.development files to point to api-rj8-dev.cloudways.services

# 4. Build frontend
build_frontend "john-test"
# Runs: npm run build:dev in container package
# Output: /opt/ods-deployments/repos/platformui-frontend/packages/container/dist

# 5. Create deployment env
create_deployment_env "john-test"
# Creates: /opt/ods-deployments/.env.john-test
# Contains:
#   DEV_NAME=john-test
#   SUBDOMAIN=john-test.ods.rahuljoshi.info
#   PROJECT_NAME=john-test-ods
#   REPO_PATH=/opt/ods-deployments/repos/platformui-frontend/packages/container

# 6. Start Docker container
start_containers "john-test"
# Runs: docker compose --env-file .env.john-test -f docker-compose.frontend.yml up -d
# Creates container: john-test-frontend
# With labels:
#   traefik.enable=true
#   traefik.http.routers.john-test-fe.rule=Host(`john-test.ods.rahuljoshi.info`)
#   traefik.http.routers.john-test-fe.entrypoints=websecure
#   traefik.http.routers.john-test-fe.tls.certresolver=letsencrypt
#   traefik.http.services.john-test-fe.loadbalancer.server.port=80
```

### 4. **Traefik Auto-Discovery** (Happens Automatically!)

Within seconds, Traefik:
1. Detects new container via Docker socket
2. Reads labels from container
3. Creates router: `john-test-fe@docker`
4. Creates service: `john-test-fe@docker`
5. Requests SSL cert from Let's Encrypt
6. Starts routing traffic

**NO manual registration needed!**

---

## 🎯 Verification Steps:

### After GitHub Action Completes:

#### 1. Check Container Created:
```bash
ssh root@64.227.159.162
docker ps | grep john-test
# Should show: john-test-frontend (healthy)
```

#### 2. Check Traefik Dashboard:
```bash
# Via browser:
http://64.227.159.162:8080

# Via API:
curl -s http://64.227.159.162:8080/api/http/routers | \
  jq '.[] | select(.name | contains("john-test"))'
# Should show: john-test-fe@docker router
```

#### 3. Check DNS Resolution (after DNS configured):
```bash
dig john-test.ods.rahuljoshi.info
# Should show: 64.227.159.162
```

#### 4. Test Access:
```bash
# HTTP (will redirect to HTTPS):
curl -I http://john-test.ods.rahuljoshi.info

# HTTPS:
curl -I https://john-test.ods.rahuljoshi.info
# Should show: 200 OK (after DNS propagation)
```

---

## 📊 Expected Dashboard View:

After deploying `john-test`, `sarah-feature`, and `mike-bugfix`:

```
HTTP Routers (docker provider):
┌─────────────────────────┬────────────────────────────────────────┬────────────────┐
│ Name                    │ Rule                                   │ Status         │
├─────────────────────────┼────────────────────────────────────────┼────────────────┤
│ dashboard@docker        │ Host(`traefik.ods.rahuljoshi.info`)   │ enabled        │
│ john-test-fe@docker     │ Host(`john-test.ods.rahuljoshi.info`) │ enabled        │
│ sarah-feature-fe@docker │ Host(`sarah-feature.ods.rahuljoshi..`)│ enabled        │
│ mike-bugfix-fe@docker   │ Host(`mike-bugfix.ods.rahuljoshi...`) │ enabled        │
│ test3-fe@docker         │ Host(`test3.ods.rahuljoshi.info`)     │ enabled        │
└─────────────────────────┴────────────────────────────────────────┴────────────────┘

HTTP Services (docker provider):
┌─────────────────────────┬─────────────────────┬──────────┐
│ Name                    │ Backend             │ Status   │
├─────────────────────────┼─────────────────────┼──────────┤
│ john-test-fe@docker     │ http://172.18.0.4   │ UP       │
│ sarah-feature-fe@docker │ http://172.18.0.5   │ UP       │
│ mike-bugfix-fe@docker   │ http://172.18.0.6   │ UP       │
│ test3-fe@docker         │ http://172.18.0.2   │ UP       │
└─────────────────────────┴─────────────────────┴──────────┘
```

---

## ✅ Auto-Registration Confirmed:

**Yes, GitHub Actions will automatically register with Traefik!**

The magic is in the Docker labels in `docker-compose.frontend.yml`:
- Traefik watches Docker socket
- When container starts with `traefik.enable=true`
- Traefik reads labels and creates routes
- **Zero manual intervention required!**

---

## 🚀 Ready to Test:

1. **Trigger GitHub Action** with any deployment name
2. Wait for workflow to complete (~5-10 minutes)
3. **Check Dashboard**: `http://64.227.159.162:8080`
4. **See new router** appear automatically!

---

## 🔍 Monitoring in Real-Time:

While deployment is running, watch Traefik logs:
```bash
ssh root@64.227.159.162
docker logs -f traefik

# You'll see:
# "Creating router: john-test-fe@docker"
# "Creating service: john-test-fe@docker"
# "Requesting certificate for john-test.ods.rahuljoshi.info"
```

**Everything happens automatically!** 🎉

