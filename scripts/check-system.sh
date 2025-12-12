#!/bin/bash
# Validation script to check if everything is ready for deployment

echo "============================================================"
echo "ODS Deployment System - Pre-flight Check"
echo "============================================================"
echo ""

ERRORS=0
WARNINGS=0

# Check if running on VPS or locally
if [ -d "/opt/ods-deployments" ]; then
    LOCATION="VPS"
    PROJECT_ROOT="/opt/ods-deployments"
else
    LOCATION="LOCAL"
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

echo "📍 Location: $LOCATION"
echo "📂 Project root: $PROJECT_ROOT"
echo ""

# Check required commands
echo "🔍 Checking required commands..."
commands=("docker" "docker-compose" "git" "node" "npm" "sqlite3")
for cmd in "${commands[@]}"; do
    if command -v $cmd &> /dev/null; then
        version=$($cmd --version 2>&1 | head -1)
        echo "  ✅ $cmd: $version"
    else
        echo "  ❌ $cmd: NOT FOUND"
        ((ERRORS++))
    fi
done
echo ""

# Check Docker is running
echo "🐳 Checking Docker..."
if docker ps &> /dev/null; then
    echo "  ✅ Docker is running"
    container_count=$(docker ps -q | wc -l)
    echo "  ℹ️  Running containers: $container_count"
else
    echo "  ❌ Docker is not running or permission denied"
    ((ERRORS++))
fi
echo ""

# Check Docker networks
echo "🌐 Checking Docker networks..."
if docker network ls | grep -q "traefik-public"; then
    echo "  ✅ traefik-public network exists"
else
    echo "  ⚠️  traefik-public network not found"
    echo "     Run: docker network create traefik-public"
    ((WARNINGS++))
fi
echo ""

# Check Traefik
echo "🚦 Checking Traefik..."
if docker ps | grep -q "traefik"; then
    echo "  ✅ Traefik container is running"
    traefik_status=$(docker inspect traefik --format='{{.State.Status}}')
    echo "     Status: $traefik_status"
else
    echo "  ⚠️  Traefik is not running"
    echo "     Run: ./scripts/setup-traefik.sh"
    ((WARNINGS++))
fi
echo ""

# Check scripts are executable
echo "📝 Checking scripts..."
cd "$PROJECT_ROOT"
for script in scripts/*.sh; do
    if [ -x "$script" ]; then
        echo "  ✅ $(basename $script) is executable"
    else
        echo "  ❌ $(basename $script) is NOT executable"
        echo "     Run: chmod +x $script"
        ((ERRORS++))
    fi
done
echo ""

# Check required files
echo "📄 Checking required files..."
required_files=(
    "docker-compose.traefik.yml"
    "docker-compose.frontend.yml"
    "nginx/default.conf"
    "env.template"
    ".github/workflows/deploy-frontend.yml"
)
for file in "${required_files[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file NOT FOUND"
        ((ERRORS++))
    fi
done
echo ""

# Check platformui-frontend repository
echo "📦 Checking repositories..."
if [ "$LOCATION" == "LOCAL" ]; then
    if [ -d "/home/rahuljoshi/CW/platformui-frontend" ]; then
        echo "  ✅ platformui-frontend found at /home/rahuljoshi/CW/platformui-frontend"
    else
        echo "  ❌ platformui-frontend NOT FOUND"
        ((ERRORS++))
    fi
elif [ -d "$PROJECT_ROOT/repos/platformui-frontend" ]; then
    echo "  ✅ platformui-frontend cloned in repos/"
    cd "$PROJECT_ROOT/repos/platformui-frontend"
    current_branch=$(git branch --show-current)
    echo "     Current branch: $current_branch"
else
    echo "  ⚠️  platformui-frontend not cloned yet (will be cloned on first deployment)"
    ((WARNINGS++))
fi
echo ""

# Check database
echo "🗄️  Checking deployment registry..."
if [ -f "$PROJECT_ROOT/deployments/registry.db" ]; then
    echo "  ✅ Registry database exists"
    deployment_count=$(sqlite3 "$PROJECT_ROOT/deployments/registry.db" \
        "SELECT COUNT(*) FROM deployments WHERE status='active'" 2>/dev/null || echo "0")
    echo "     Active deployments: $deployment_count"
else
    echo "  ℹ️  Registry database not created yet (will be created on first deployment)"
fi
echo ""

# Check ports
echo "🔌 Checking ports..."
ports=(80 443 8080)
for port in "${ports[@]}"; do
    if command -v lsof &> /dev/null; then
        if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            process=$(lsof -Pi :$port -sTCP:LISTEN | grep LISTEN | awk '{print $1}' | head -1)
            echo "  ℹ️  Port $port: IN USE by $process"
        else
            echo "  ✅ Port $port: Available"
        fi
    else
        echo "  ⚠️  Cannot check port $port (lsof not installed)"
    fi
done
echo ""

# Summary
echo "============================================================"
echo "📊 Summary"
echo "============================================================"
echo ""
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ All checks passed! System is ready for deployment."
    echo ""
    echo "Next steps:"
    if [ "$LOCATION" == "LOCAL" ]; then
        echo "  1. Test local build: ./scripts/test-local-build.sh master"
        echo "  2. Push to GitHub"
        echo "  3. Setup VPS and deploy"
    else
        echo "  1. Configure GitHub secrets (VPS_SSH_KEY, VPS_HOST, VPS_USER)"
        echo "  2. Deploy via GitHub Actions or SSH"
        echo "  3. Access: https://your-deployment.dev.cloudways.com"
    fi
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  $WARNINGS warning(s) found. System should work but check warnings above."
    exit 0
else
    echo "❌ $ERRORS error(s) and $WARNINGS warning(s) found."
    echo "   Please fix the errors before deploying."
    exit 1
fi

