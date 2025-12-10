#!/bin/bash
# Setup script for DigitalOcean droplet
# Installs Docker, Docker Compose, and required utilities

set -e

echo "=========================================="
echo "Cloudways Dev Environment - Droplet Setup"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root (sudo)"
    exit 1
fi

echo ""
echo "[1/6] Updating system packages..."
apt-get update
apt-get upgrade -y

echo ""
echo "[2/6] Installing Docker..."
if command -v docker &> /dev/null; then
    echo "Docker already installed: $(docker --version)"
else
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker
    systemctl start docker
    echo "Docker installed: $(docker --version)"
fi

echo ""
echo "[3/6] Installing Docker Compose..."
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    echo "Docker Compose already installed"
else
    apt-get install -y docker-compose-plugin
    echo "Docker Compose installed: $(docker compose version)"
fi

echo ""
echo "[4/6] Installing utilities (jq, git, yq)..."
apt-get install -y jq git curl wget

# Install yq for YAML processing
if command -v yq &> /dev/null; then
    echo "yq already installed"
else
    wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
    chmod +x /usr/bin/yq
    echo "yq installed: $(yq --version)"
fi

echo ""
echo "[5/6] Creating directory structure..."
mkdir -p /opt/cloudways-dev/{keys,developers,repos,scripts,shared}

# Set permissions
chmod 755 /opt/cloudways-dev
chmod 700 /opt/cloudways-dev/keys

echo ""
echo "[6/6] Creating Docker network..."
if docker network inspect cw-shared &> /dev/null; then
    echo "Network 'cw-shared' already exists"
else
    docker network create cw-shared
    echo "Network 'cw-shared' created"
fi

echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Copy your deploy key to /opt/cloudways-dev/keys/github_deploy_key"
echo "2. Clone repositories to /opt/cloudways-dev/repos/"
echo "3. Copy configuration files to /opt/cloudways-dev/"
echo "4. Start shared services: docker compose -f /opt/cloudways-dev/shared/docker-compose.yml up -d"
echo ""

