#!/bin/bash
# Cleanup all deployments and processes

echo "🧹 Cleaning up all deployments..."

# Stop all running npm processes
echo "→ Stopping all npm processes..."
pkill -f "npm run start" || true
pkill -f "node.*webpack" || true

# Remove all PID files
echo "→ Removing PID files..."
rm -f /tmp/ods-*.pid

# Remove all log files
echo "→ Removing log files..."
rm -f /tmp/ods-*.log

# Stop all Docker containers with 'ods' in the name
echo "→ Stopping Docker containers..."
docker ps -a --filter "name=ods" --format "{{.Names}}" | xargs -r docker stop
docker ps -a --filter "name=ods" --format "{{.Names}}" | xargs -r docker rm

# Remove Docker networks
echo "→ Removing Docker networks..."
docker network ls --filter "name=ods" --format "{{.Name}}" | xargs -r docker network rm

# Clean up deployment directories
echo "→ Cleaning deployment directories..."
rm -rf /opt/ods-deployments/deployments/*

# Clear registry database
echo "→ Clearing registry..."
if [ -f "/opt/ods-deployments/deployments/registry.db" ]; then
    sqlite3 /opt/ods-deployments/deployments/registry.db "DELETE FROM deployments;" 2>/dev/null || true
fi

echo "✅ Cleanup complete!"
echo ""
echo "Current system status:"
echo "→ Docker containers: $(docker ps --filter 'name=ods' | wc -l) running"
echo "→ npm processes: $(pgrep -f 'npm run start' | wc -l) running"
echo "→ CPU usage: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"

