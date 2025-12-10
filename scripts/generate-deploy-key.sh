#!/bin/bash
# Generate SSH deploy key for GitHub access
# This key bypasses SSO/SAML requirements

set -e

KEYS_DIR="/opt/cloudways-dev/keys"
KEY_NAME="github_deploy_key"

echo "=========================================="
echo "GitHub Deploy Key Generator"
echo "=========================================="

# Create keys directory if not exists
mkdir -p "$KEYS_DIR"

# Check if key already exists
if [ -f "$KEYS_DIR/$KEY_NAME" ]; then
    echo "WARNING: Deploy key already exists at $KEYS_DIR/$KEY_NAME"
    read -p "Do you want to regenerate? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo "Keeping existing key."
        exit 0
    fi
    # Backup existing key
    mv "$KEYS_DIR/$KEY_NAME" "$KEYS_DIR/$KEY_NAME.backup.$(date +%Y%m%d%H%M%S)"
    mv "$KEYS_DIR/$KEY_NAME.pub" "$KEYS_DIR/$KEY_NAME.pub.backup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
fi

# Generate new ED25519 key (more secure than RSA)
echo "Generating new ED25519 deploy key..."
ssh-keygen -t ed25519 -C "cloudways-dev-environment" -f "$KEYS_DIR/$KEY_NAME" -N ""

# Set proper permissions
chmod 600 "$KEYS_DIR/$KEY_NAME"
chmod 644 "$KEYS_DIR/$KEY_NAME.pub"

# Create SSH config for GitHub
echo "Creating SSH config..."
cat > "$KEYS_DIR/config" << 'EOF'
Host github.com
  HostName github.com
  User git
  IdentityFile /root/.ssh/github_deploy_key
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host bitbucket.org
  HostName bitbucket.org
  User git
  IdentityFile /root/.ssh/github_deploy_key
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF

chmod 644 "$KEYS_DIR/config"

echo ""
echo "=========================================="
echo "Deploy key generated successfully!"
echo "=========================================="
echo ""
echo "Public key location: $KEYS_DIR/$KEY_NAME.pub"
echo ""
echo "PUBLIC KEY CONTENT (add this to GitHub):"
echo "=========================================="
cat "$KEYS_DIR/$KEY_NAME.pub"
echo ""
echo "=========================================="
echo ""
echo "NEXT STEPS:"
echo "1. Copy the public key above"
echo "2. For each repo, go to: Settings → Deploy Keys → Add deploy key"
echo "3. Paste the key and give it a title like 'cloudways-dev-droplet'"
echo "4. (Optional) Check 'Allow write access' if developers need to push"
echo ""
echo "OR for org-wide access:"
echo "1. Create a machine user account in GitHub"
echo "2. Add this SSH key to the machine user's account"
echo "3. Add the machine user to your organization with read access"
echo ""

