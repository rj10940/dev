#!/bin/bash
# Setup script - runs once when container starts
# Clones repos, installs dependencies, configures environment

set -e

echo "🚀 Setting up deployment: ${DEPLOYMENT_NAME}"
echo "=========================================="

# Configure SSH for GitHub
echo "🔑 Configuring SSH for GitHub access..."
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Ensure proper permissions on SSH keys
if [ -f /root/.ssh/id_rsa ]; then
    chmod 600 /root/.ssh/id_rsa
fi
if [ -f /root/.ssh/id_ed25519 ]; then
    chmod 600 /root/.ssh/id_ed25519
fi

# Add GitHub to known_hosts if not already present
if ! grep -q "github.com" /root/.ssh/known_hosts 2>/dev/null; then
    echo "  → Adding GitHub to known_hosts..."
    ssh-keyscan github.com >> /root/.ssh/known_hosts 2>/dev/null || true
fi

# Test SSH connection to GitHub
echo "  → Testing GitHub SSH connection..."
ssh -T git@github.com -o StrictHostKeyChecking=no 2>&1 | grep -q "successfully authenticated" && echo "  ✓ GitHub SSH access verified" || echo "  ⚠️  GitHub SSH test returned non-zero (this is often normal)"

# Configure Git (for cloning)
git config --global user.email "deploy@ods.local"
git config --global user.name "ODS Deploy"

# Clone platformui-frontend repository
echo "📦 Cloning platformui-frontend repository..."
cd /app
git clone git@github.com:cloudways-lab/platformui-frontend.git .
echo "  ✓ Repository cloned"

# Checkout specified branch
echo "🌿 Checking out branch: ${FRONTEND_BRANCH}"
git checkout "${FRONTEND_BRANCH}"
git pull origin "${FRONTEND_BRANCH}"

# Initialize and clone submodules
echo "📦 Initializing submodules..."
git submodule update --init --recursive --force

# Checkout submodule branches
echo "🌿 Checking out submodule branches..."
cd /app/packages/flexible && git checkout -f "${FLEXIBLE_BRANCH}" && git reset --hard "origin/${FLEXIBLE_BRANCH}"
cd /app/packages/fmp-ux3 && git checkout -f "${FMP_BRANCH}" && git reset --hard "origin/${FMP_BRANCH}"
cd /app/packages/unified-design-system && git checkout -f "${UNIFIED_BRANCH}" && git reset --hard "origin/${UNIFIED_BRANCH}"
cd /app/packages/agencyos-ux3 && git checkout -f "${AGENCYOS_BRANCH}" && git reset --hard "origin/${AGENCYOS_BRANCH}"
cd /app/packages/guests-app-ux3 && git checkout -f "${GUESTS_BRANCH}" && git reset --hard "origin/${GUESTS_BRANCH}"
cd /app

echo "✓ All branches checked out"

# Setup npm authentication for private packages
if [ -n "$GITHUB_NPM_TOKEN" ]; then
    echo "🔐 Setting up npm authentication..."
    
    for dir in packages/container packages/flexible packages/fmp-ux3 packages/unified-design-system packages/agencyos-ux3 packages/guests-app-ux3; do
        if [ -d "$dir" ]; then
            cat > "$dir/.npmrc" <<EOF
//npm.pkg.github.com/:_authToken=${GITHUB_NPM_TOKEN}
@cloudways-lab:registry=https://npm.pkg.github.com/
EOF
            echo "  ✓ Configured $dir"
        fi
    done
fi

# Update API URLs in .env files
echo "🔧 Updating API URLs..."
for package in packages/container packages/flexible packages/fmp-ux3 packages/unified-design-system packages/agencyos-ux3 packages/guests-app-ux3; do
    if [ -f "$package/.env.development" ]; then
        sed -i \
            -e 's|https://api4-staging\.cloudways\.com|https://api-rj8-dev.cloudways.services|g' \
            -e 's|https://newconsole4-staging\.cloudways\.com|https://api-rj8-dev.cloudways.services|g' \
            -e 's|https://newconsole3-staging\.cloudways\.com|https://api-rj8-dev.cloudways.services|g' \
            "$package/.env.development"
        echo "  ✓ Updated $package/.env.development"
    fi
done

# Install dependencies
echo "📦 Installing dependencies..."
echo "  This may take 2-3 minutes..."

install_package() {
    local package=$1
    local name=$2
    
    if [ -d "$package" ] && [ -f "$package/package.json" ]; then
        echo "  → Installing $name..."
        cd "/app/$package"
        npm install --legacy-peer-deps > "/tmp/install-${name}.log" 2>&1
        if [ $? -eq 0 ]; then
            echo "    ✓ $name installed"
        else
            echo "    ⚠️  $name failed (check /tmp/install-${name}.log)"
        fi
    fi
}

# Install in order (unified first, then others)
install_package "packages/unified-design-system" "unified"
install_package "packages/container" "container"
install_package "packages/flexible" "flexible"
install_package "packages/fmp-ux3" "fmp"
install_package "packages/agencyos-ux3" "agencyos"
install_package "packages/guests-app-ux3" "guests"

cd /app

echo ""
echo "=========================================="
echo "✅ Setup complete!"
echo "=========================================="
echo "📂 Source code: /app"
echo "🌿 Branches:"
echo "  - frontend: ${FRONTEND_BRANCH}"
echo "  - flexible: ${FLEXIBLE_BRANCH}"
echo "  - fmp: ${FMP_BRANCH}"
echo "  - unified: ${UNIFIED_BRANCH}"
echo "  - agencyos: ${AGENCYOS_BRANCH}"
echo "  - guests: ${GUESTS_BRANCH}"
echo ""

