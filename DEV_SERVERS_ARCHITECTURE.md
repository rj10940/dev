# 🔥 Dev Servers in Docker - Architecture Explanation

## 🎯 Why This Approach?

### ❌ Old Approach (nginx + static build):
```
Build → Static Files → Nginx → Traefik → User
         (5-10 min)    (serve)  (route)
```
**Problems:**
- ❌ 5-10 min build time per deployment
- ❌ No hot reload
- ❌ Hard to debug
- ❌ Different from local development
- ❌ Need to rebuild for every code change

### ✅ New Approach (dev servers in Docker):
```
Dev Servers → Traefik → User
(hot reload)   (route)
```
**Benefits:**
- ✅ Fast startup (~1-2 min for deps install)
- ✅ Hot reload - see changes instantly
- ✅ Same as local `start-mac.sh` experience
- ✅ Easy debugging with source maps
- ✅ No build step needed

---

## 🏗️ Architecture Overview

### Each Deployment = 1 Ubuntu Container Running All Dev Servers

```
┌─────────────────────────────────────────────────────────────┐
│  Docker Container: john-test-frontend                        │
│  Image: ods-dev-frontend (Ubuntu 22.04 + Node.js 25)       │
│                                                              │
│  Running Processes:                                         │
│  ├─ unified-design-system  (port 8080)                     │
│  ├─ container (main app)    (port 8081) ← Traefik routes here
│  ├─ flexible                (port 8082)                     │
│  ├─ fmp-ux3                 (port 8083)                     │
│  ├─ agencyos-ux3            (port 8084)                     │
│  └─ guests-app-ux3          (port 8085)                     │
│                                                              │
│  Volumes Mounted:                                           │
│  └─ /opt/ods-deployments/repos/platformui-frontend → /app  │
│     (source code, hot reload enabled)                       │
└─────────────────────────────────────────────────────────────┘
                              ↓
                         Traefik
                    (routes to port 8081)
                              ↓
              john-test.ods.rahuljoshi.info
```

---

## 🔌 Port Mapping

### Inside Container:
```
8080 → unified-design-system (shared design system)
8081 → container (MAIN APP - entry point)
8082 → flexible (flexible hosting micro-frontend)
8083 → fmp-ux3 (managed applications)
8084 → agencyos-ux3 (agency features)
8085 → guests-app-ux3 (guest access)
```

### Traefik Configuration:
```yaml
# Routes subdomain → port 8081 (main container app)
traefik.http.services.john-test-fe.loadbalancer.server.port=8081
```

**Why port 8081?**
- Container app is the **main entry point** (Module Federation host)
- It loads other micro-frontends dynamically via Module Federation
- Other servers (8080, 8082-8085) are remotes consumed by container

---

## 📦 Module Federation Flow

```
User visits: https://john-test.ods.rahuljoshi.info
              ↓
         Traefik routes to container:8081
              ↓
    Container app loads (React app)
              ↓
    Dynamically loads other micro-frontends:
    ├─ Design System from localhost:8080
    ├─ Flexible from localhost:8082
    ├─ FMP from localhost:8083
    ├─ AgencyOS from localhost:8084
    └─ Guests from localhost:8085
```

**All running in same Docker container = same localhost!**

---

## 🚀 Deployment Flow

### 1. GitHub Action Triggers:
```yaml
Inputs:
  - deployment_name: john-test
  - branches: master (for all repos)
```

### 2. VPS Deployment Script:
```bash
# 1. Clone/update repos
git clone platformui-frontend
git submodule update --init --recursive

# 2. Install dependencies (once)
npm install in all packages

# 3. Update API URLs
# Replace staging URLs with api-rj8-dev.cloudways.services

# 4. Start Docker container
docker compose up -d
# Container runs: bash /start-dev-servers.sh
```

### 3. Inside Container (`start-dev-servers.sh`):
```bash
# Start unified first (others depend on it)
cd packages/unified-design-system
npm run start:dev &

# Start all others
cd packages/container && npm run start:dev &
cd packages/flexible && npm run start:dev &
cd packages/fmp-ux3 && npm run start:dev &
cd packages/agencyos-ux3 && npm run start:dev &
cd packages/guests-app-ux3 && npm run start:dev &

# Keep container running
wait
```

### 4. Traefik Auto-Discovery:
```
- Detects new container
- Reads labels
- Creates router: john-test-fe@docker
- Routes john-test.ods.rahuljoshi.info → container:8081
```

---

## 🔥 Hot Reload Magic

### Source Code is Mounted:
```yaml
volumes:
  - /opt/ods-deployments/repos/platformui-frontend:/app:cached
```

**This means:**
1. Code on VPS = Code in container (same files)
2. Webpack dev server watches for changes
3. Edit file on VPS → Container detects change
4. Webpack rebuilds → Browser auto-refreshes

**Use Case:**
```bash
# SSH into VPS
ssh root@64.227.159.162

# Edit a file
vim /opt/ods-deployments/repos/platformui-frontend/packages/container/src/App.tsx

# Save file
# → Webpack detects change
# → Rebuilds in <1 second
# → Browser auto-refreshes!
```

---

## 🆚 Comparison

### Old (nginx + build):
```
Deployment time: ~8-10 minutes
- Clone repos: 30s
- Install deps: 2-3 min
- BUILD: 5-7 min ← SLOW!
- Start nginx: 5s

Code change:
- Edit file
- Rebuild (5-7 min) ← SLOW!
- Restart container
```

### New (dev servers):
```
Deployment time: ~2-3 minutes
- Clone repos: 30s
- Install deps: 2-3 min
- Start dev servers: 30-60s
- Webpack compile: 30s

Code change:
- Edit file
- Auto-rebuild (<1s) ← FAST!
- Auto-refresh in browser
```

---

## 🎯 Benefits

1. **⚡ Faster Feedback Loop**
   - No 5-7 min build wait
   - See changes in seconds

2. **🔄 Hot Module Replacement**
   - Changes reflect instantly
   - No page refresh needed (in most cases)

3. **🐛 Better Debugging**
   - Source maps available
   - React DevTools work properly
   - Console logs preserved

4. **📦 Same as Local Dev**
   - Same `start:dev` command
   - Same behavior as `start-mac.sh`
   - Familiar development experience

5. **🔧 Easy Troubleshooting**
   - Can SSH into container
   - Check running processes
   - View real-time logs
   - Restart individual servers

---

## 📊 Resource Usage

### Per Deployment:
```
Memory: ~2-3 GB (Node.js + all dev servers)
CPU: 1-2 cores (during webpack compile)
Disk: ~1 GB (node_modules shared via mount)
```

### 50 Deployments:
```
Memory: ~100-150 GB
CPU: Can spike during simultaneous compiles
Disk: ~1 GB (repos) + 50GB (node_modules)

Recommended VPS:
- 32 CPU cores
- 192 GB RAM
- 500 GB SSD
```

---

## 🧪 Testing the Setup

### Deploy and test:
```bash
# 1. Run GitHub Action
deployment_name: test-dev

# 2. Wait for completion (~3 min)

# 3. Check Traefik dashboard
http://64.227.159.162:8080
# Should show: test-dev-fe@docker router

# 4. Access the app
https://test-dev.ods.rahuljoshi.info
# (after DNS configured)

# 5. Test hot reload
ssh root@64.227.159.162
vim /opt/ods-deployments/repos/platformui-frontend/packages/container/src/App.tsx
# Make a change, save
# Browser should auto-refresh!
```

---

## 🎓 Summary

**No nginx needed!** 
- Webpack dev server handles HTTP serving
- Traefik routes traffic to dev server
- Hot reload works out of the box
- Same experience as `start-mac.sh` locally

**This is the right approach for development environments!** 🚀

