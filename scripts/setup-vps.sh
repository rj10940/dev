#!/bin/bash
# VPS Initial Setup Script
# Sets up the VPS environment for ODS deployments

set -e

echo "============================================================"
echo "ODS Deployment System - VPS Initial Setup"
echo "============================================================"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then 
    echo "Please run as root or with sudo"
    exit 1
fi

# Update system
echo "→ Updating system packages..."
apt-get update
apt-get upgrade -y

# Install required packages
echo "→ Installing required packages..."
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    sqlite3 \
    jq \
    unzip

# Install Docker
echo "→ Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # Add current user to docker group
    if [ -n "$SUDO_USER" ]; then
        usermod -aG docker $SUDO_USER
        echo "  Added $SUDO_USER to docker group"
    fi
else
    echo "  Docker already installed"
fi

# Install Docker Compose
echo "→ Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    echo "  Docker Compose already installed"
fi

# Install Node.js (for npm builds)
echo "→ Installing Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
else
    echo "  Node.js already installed"
fi

# Create deployment directory
echo "→ Creating deployment directories..."
mkdir -p /opt/ods-deployments/{scripts,deployments,repos,traefik,nginx}
chown -R ${SUDO_USER:-$USER}:${SUDO_USER:-$USER} /opt/ods-deployments

# Configure firewall (if ufw is available)
if command -v ufw &> /dev/null; then
    echo "→ Configuring firewall..."
    ufw allow 22/tcp    # SSH
    ufw allow 80/tcp    # HTTP
    ufw allow 443/tcp   # HTTPS
    ufw allow 8080/tcp  # Traefik Dashboard
    echo "y" | ufw enable || true
fi

# Create systemd service for Docker (ensure it starts on boot)
echo "→ Enabling Docker service..."
systemctl enable docker
systemctl start docker

echo ""
echo "============================================================"
echo "✅ VPS Setup Complete!"
echo "============================================================"
echo ""
echo "📝 Installed:"
echo "   - Docker $(docker --version)"
echo "   - Docker Compose $(docker-compose --version)"
echo "   - Node.js $(node --version)"
echo "   - npm $(npm --version)"
echo ""
echo "📂 Deployment directory: /opt/ods-deployments"
echo ""
echo "🔄 Next steps:"
echo "   1. Clone/copy your deployment scripts to /opt/ods-deployments"
echo "   2. Run: cd /opt/ods-deployments && ./scripts/setup-traefik.sh"
echo "   3. Configure DNS for *.dev.cloudways.com"
echo "   4. Deploy your first frontend!"
echo ""
echo "⚠️  Note: If you added user to docker group, logout and login again"
echo ""

