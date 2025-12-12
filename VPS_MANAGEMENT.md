# 🚨 VPS Management - Install Docker & Kill High CPU Processes

## SSH into VPS:
```bash
ssh root@64.227.159.162
cd /opt/ods-deployments
git pull
```

---

## 1️⃣ Install Docker

```bash
./scripts/install-docker.sh
```

**What it does:**
- ✅ Installs Docker Engine
- ✅ Installs Docker Compose V2
- ✅ Starts Docker service
- ✅ Tests installation
- ⏱️ Takes ~2-3 minutes

---

## 2️⃣ Check & Kill High CPU Processes

```bash
./scripts/kill-high-cpu.sh
```

**What it does:**
- 📊 Shows top 10 CPU consuming processes
- 📋 Lists all npm/node/webpack processes
- ❓ Asks if you want to kill them
- 🔪 Kills all npm/node processes if confirmed
- ✅ Shows new CPU usage after cleanup

---

## 🔍 Manual CPU Check:

```bash
# Real-time CPU monitoring
top

# Sort by CPU usage
ps aux --sort=-%cpu | head -20

# Find npm processes
ps aux | grep npm

# Find node processes
ps aux | grep node
```

---

## 🔪 Manual Process Killing:

```bash
# Kill all npm processes
pkill -9 -f "npm run"

# Kill all node processes
pkill -9 node

# Kill specific PID
kill -9 <PID>

# Kill processes from PID files
kill -9 $(cat /tmp/ods-*.pid)
rm /tmp/ods-*.pid
```

---

## ✅ After Cleanup:

1. Check CPU is normal:
   ```bash
   top
   # Should show <20% CPU usage
   ```

2. Verify no containers running:
   ```bash
   docker ps
   # Should be empty or only show traefik
   ```

3. Ready for fresh deployment!
   - GitHub Actions → Deploy new version
   - Will use Docker (low CPU)
   - Not dev servers (high CPU)

