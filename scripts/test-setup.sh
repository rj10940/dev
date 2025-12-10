#!/bin/bash
# Test script to verify the dev environment setup

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }

echo "=========================================="
echo "Cloudways Dev Environment - Setup Test"
echo "=========================================="
echo ""

# Check directory structure
echo "Checking directory structure..."
for dir in keys developers repos scripts shared; do
    if [ -d "/opt/cloudways-dev/$dir" ]; then
        pass "/opt/cloudways-dev/$dir exists"
    else
        fail "/opt/cloudways-dev/$dir missing"
    fi
done

# Check required tools
echo ""
echo "Checking required tools..."
for cmd in docker jq yq git; do
    if command -v $cmd &> /dev/null; then
        pass "$cmd installed"
    else
        fail "$cmd not installed"
    fi
done

# Check Docker Compose
if docker compose version &> /dev/null; then
    pass "docker compose v2 installed"
else
    fail "docker compose v2 not installed"
fi

# Check Docker network
echo ""
echo "Checking Docker network..."
if docker network inspect cw-shared &> /dev/null; then
    pass "cw-shared network exists"
else
    warn "cw-shared network missing (will be created)"
fi

# Check deploy key
echo ""
echo "Checking deploy key..."
if [ -f "/opt/cloudways-dev/keys/github_deploy_key" ]; then
    pass "Deploy key exists"
else
    warn "Deploy key missing - run ./scripts/generate-deploy-key.sh"
fi

# Check shared services
echo ""
echo "Checking shared services..."
for container in shared-mysql shared-redis shared-postgres traefik; do
    if docker ps --filter "name=$container" --filter "status=running" | grep -q $container; then
        pass "$container running"
    else
        warn "$container not running"
    fi
done

# Check configuration files
echo ""
echo "Checking configuration files..."
for file in docker-compose.template.yml shared/docker-compose.yml; do
    if [ -f "/opt/cloudways-dev/$file" ]; then
        pass "$file exists"
    else
        fail "$file missing"
    fi
done

# Check scripts
echo ""
echo "Checking scripts..."
for script in dev-env.sh setup-droplet.sh generate-deploy-key.sh clone-repos.sh; do
    if [ -x "/opt/cloudways-dev/scripts/$script" ]; then
        pass "$script executable"
    else
        warn "$script not executable or missing"
    fi
done

echo ""
echo "=========================================="
echo "Test Complete"
echo "=========================================="
echo ""
echo "If any items failed, refer to SETUP.md for instructions."

