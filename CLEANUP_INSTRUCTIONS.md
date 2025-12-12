# 🧹 Cleanup All Deployments

## Run this on VPS to clean up everything:

```bash
ssh root@64.227.159.162

# Pull latest code with cleanup script
cd /opt/ods-deployments
git pull

# Run cleanup
./scripts/cleanup-all.sh
```

## What it does:

1. ✅ Stops all npm processes (dev servers)
2. ✅ Stops all Docker containers with 'ods' in name
3. ✅ Removes Docker containers
4. ✅ Removes Docker networks
5. ✅ Deletes PID files (/tmp/ods-*.pid)
6. ✅ Deletes log files (/tmp/ods-*.log)
7. ✅ Clears deployment directories
8. ✅ Clears registry database

## Verify cleanup:

```bash
# Check running containers
docker ps

# Check npm processes
ps aux | grep "npm run"

# Check CPU usage
top
```

---

## Architecture Restored ✅

Back to proper multi-tenant Docker setup:

```
INTERNET → Traefik (subdomain routing) → Docker Container (per deployment)
```

Each deployment:
- ✅ Build static files (`npm run build:dev`)
- ✅ Create Docker container with nginx
- ✅ Traefik routes `{name}.ods.rahuljoshi.info` → container
- ✅ Isolated from other deployments

