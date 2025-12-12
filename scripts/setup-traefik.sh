#!/bin/bash
# Traefik Setup Script
# Run this once on the VPS to initialize Traefik

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "============================================================"
echo "Setting up Traefik"
echo "============================================================"
echo ""

# Create traefik directory for SSL certificates
echo "→ Creating Traefik directories..."
mkdir -p "${PROJECT_ROOT}/traefik/letsencrypt"

# Create acme.json with correct permissions
echo "→ Creating acme.json for Let's Encrypt..."
touch "${PROJECT_ROOT}/traefik/letsencrypt/acme.json"
chmod 600 "${PROJECT_ROOT}/traefik/letsencrypt/acme.json"

# Create Docker network
echo "→ Creating traefik-public network..."
docker network create traefik-public 2>/dev/null || echo "  Network already exists"

# Set domain in environment
echo "→ Setting up environment..."
export DOMAIN="rahuljoshi.info"

# Start Traefik
echo "→ Starting Traefik..."
cd "$PROJECT_ROOT"
docker compose -f docker-compose.traefik.yml up -d

echo ""
echo "============================================================"
echo "✅ Traefik Setup Complete!"
echo "============================================================"
echo ""
echo "📍 Traefik Dashboard: http://$(hostname -I | awk '{print $1}'):8080"
echo "   (will be available at https://traefik.ods.rahuljoshi.info once DNS is configured)"
echo ""
echo "📝 Next steps:"
echo "   1. Configure DNS: *.ods.rahuljoshi.info → 64.227.159.162"
echo "   2. Wait for DNS propagation (5-30 minutes)"
echo "   3. Deploy your first frontend!"
echo ""

