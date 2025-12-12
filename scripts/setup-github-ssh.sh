#!/bin/bash
# One-time setup script to configure GitHub SSH access for root user
# Run this on the VPS as root: sudo ./setup-github-ssh.sh

set -e

echo "🔧 Setting up GitHub SSH access for root user"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root: sudo ./setup-github-ssh.sh"
    exit 1
fi

# Create .ssh directory for root
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# Check if key already exists
if [ -f "/root/.ssh/github_access" ]; then
    echo "✅ SSH key already exists at /root/.ssh/github_access"
    echo ""
    read -p "Regenerate key? (y/n): " regenerate
    if [ "$regenerate" != "y" ]; then
        echo "Using existing key..."
    else
        echo "Generating new key..."
        ssh-keygen -t ed25519 -C "vps-root-github-access" -f /root/.ssh/github_access -N ""
    fi
else
    echo "📝 Generating new SSH key..."
    ssh-keygen -t ed25519 -C "vps-root-github-access" -f /root/.ssh/github_access -N ""
    echo "✅ SSH key generated"
fi

echo ""
echo "📋 Your PUBLIC key (add this to GitHub):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat /root/.ssh/github_access.pub
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "👉 Add this key to GitHub:"
echo "   1. Go to: https://github.com/settings/keys"
echo "   2. Click 'New SSH key'"
echo "   3. Title: VPS Root - ODS Deployments (64.227.159.162)"
echo "   4. Key: (paste the key above)"
echo "   5. Click 'Add SSH key'"
echo ""

read -p "Press Enter after adding the key to GitHub..."

# Configure SSH for GitHub
echo ""
echo "⚙️  Configuring SSH..."

cat > /root/.ssh/config <<EOF
Host github.com
    HostName github.com
    User git
    IdentityFile /root/.ssh/github_access
    IdentitiesOnly yes
    StrictHostKeyChecking no
EOF

chmod 600 /root/.ssh/config
chmod 600 /root/.ssh/github_access
chmod 644 /root/.ssh/github_access.pub

echo "✅ SSH config created"
echo ""

# Test connection
echo "🧪 Testing GitHub connection..."
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "✅ SUCCESS! GitHub authentication works!"
    echo ""
    echo "🎉 Setup complete! You can now deploy."
else
    echo "⚠️  Connection test inconclusive. Try manually:"
    echo "   ssh -T git@github.com"
    echo ""
    echo "If you see 'Hi username! You've successfully authenticated', it works!"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Try cloning a private repo: git clone git@github.com:cloudways-lab/platformui-frontend.git /tmp/test"
echo "  2. Run deployment from GitHub Actions"
echo ""

