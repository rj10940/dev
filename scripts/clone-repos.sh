#!/bin/bash
# Clone all Cloudways repositories using deploy key

set -e

REPOS_DIR="/opt/cloudways-dev/repos"
KEYS_DIR="/opt/cloudways-dev/keys"
KEY_FILE="$KEYS_DIR/github_deploy_key"

echo "=========================================="
echo "Cloudways Dev Environment - Clone Repos"
echo "=========================================="

# Check if deploy key exists
if [ ! -f "$KEY_FILE" ]; then
    echo "ERROR: Deploy key not found at $KEY_FILE"
    echo "Run ./generate-deploy-key.sh first"
    exit 1
fi

# Set SSH command to use deploy key
export GIT_SSH_COMMAND="ssh -i $KEY_FILE -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

# Create repos directory
mkdir -p "$REPOS_DIR"
cd "$REPOS_DIR"

# Define repositories to clone
# Format: "git_url|directory_name"
REPOS=(
    "git@github.com:cloudways-lab/cg-console-new.git|cg-console-new"
    "git@github.com:cloudways-lab/cg-apiserver.git|cg-apiserver"
    "git@github.com:cloudways-lab/flexible-middleware.git|flexible-middleware"
    "git@github.com:cloudways-lab/flexible-operation-engine.git|flexible-operation-engine"
    "git@github.com:cloudways-lab/ansible-api-v2.git|ansible-api-v2"
    "git@github.com:cloudways-lab/cg-event-service.git|cg-event-service"
    "git@github.com:cloudways-lab/cg-comms-service.git|cg-comms-service"
    "git@github.com:cloudways-lab/platformui-frontend.git|platformui-frontend"
)

# Alternative Bitbucket repos (uncomment if needed)
# REPOS=(
#     "git@bitbucket.org:cloudways_dev/cg-console-new.git|cg-console-new"
#     "git@bitbucket.org:cloudways_dev/cg-apiserver.git|cg-apiserver"
#     ...
# )

echo ""
echo "Cloning repositories to $REPOS_DIR"
echo ""

for repo_entry in "${REPOS[@]}"; do
    IFS='|' read -r git_url dir_name <<< "$repo_entry"
    
    if [ -d "$REPOS_DIR/$dir_name" ]; then
        echo "[$dir_name] Already exists, pulling latest..."
        cd "$REPOS_DIR/$dir_name"
        git fetch --all
        cd "$REPOS_DIR"
    else
        echo "[$dir_name] Cloning from $git_url..."
        git clone "$git_url" "$dir_name" || {
            echo "WARNING: Failed to clone $dir_name, skipping..."
            continue
        }
    fi
done

echo ""
echo "=========================================="
echo "Clone Complete!"
echo "=========================================="
echo ""
echo "Repositories cloned to: $REPOS_DIR"
ls -la "$REPOS_DIR"
echo ""

