#!/bin/bash
# Start all dev servers (similar to start-mac.sh but for Linux/Docker)

set -e

SCRIPT_DIR="/app"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-dev}"

echo "🚀 Starting all micro-frontend dev servers for: $DEPLOYMENT_NAME"
echo "=========================================="

# Function to start a dev server
start_server() {
    local name=$1
    local dir=$2
    local port=$3
    
    echo "→ Starting $name on port $port..."
    cd "$SCRIPT_DIR/$dir"
    
    if [ ! -f "package.json" ]; then
        echo "  ⚠️  No package.json found in $dir, skipping..."
        return
    fi
    
    # Start server in background, redirect output to log file
    REACT_APP_ENV=development npm run start:dev > "/tmp/${DEPLOYMENT_NAME}-${name}.log" 2>&1 &
    local pid=$!
    echo $pid > "/tmp/${DEPLOYMENT_NAME}-${name}.pid"
    echo "  ✓ Started $name (PID: $pid)"
}

# Start unified-design-system first (other packages depend on it)
start_server "unified" "packages/unified-design-system" 8080

# Start watch-types for unified (generates types on the fly)
echo "→ Starting unified watch-types..."
cd "$SCRIPT_DIR/packages/unified-design-system"
npm run watch-types > "/tmp/${DEPLOYMENT_NAME}-unified-watch.log" 2>&1 &
echo $! > "/tmp/${DEPLOYMENT_NAME}-unified-watch.pid"
echo "  ✓ Started watch-types"

# Wait a bit for unified to initialize
sleep 5

# Start all other micro-frontends in parallel
start_server "container" "packages/container" 8081
start_server "flexible" "packages/flexible" 8082
start_server "fmp" "packages/fmp-ux3" 8083
start_server "agencyos" "packages/agencyos-ux3" 8084
start_server "guests" "packages/guests-app-ux3" 8085

echo ""
echo "=========================================="
echo "✅ All dev servers started!"
echo "=========================================="
echo "📋 Logs available in /tmp/${DEPLOYMENT_NAME}-*.log"
echo "🔢 PIDs stored in /tmp/${DEPLOYMENT_NAME}-*.pid"
echo ""
echo "🌐 Access points:"
echo "  - Main App (Container): http://localhost:8081"
echo "  - Unified Design:       http://localhost:8080"
echo "  - Flexible:             http://localhost:8082"
echo "  - FMP:                  http://localhost:8083"
echo "  - AgencyOS:             http://localhost:8084"
echo "  - Guests:               http://localhost:8085"
echo ""

# Function to handle shutdown
cleanup() {
    echo "🛑 Shutting down all servers..."
    pkill -P $$ || true
    exit 0
}

trap cleanup SIGTERM SIGINT

# Keep container running and show logs
echo "📊 Tailing container logs (Ctrl+C to stop)..."
tail -f "/tmp/${DEPLOYMENT_NAME}-container.log" &

# Wait for all background processes
wait

