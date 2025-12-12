#!/bin/bash
# Modified version of node_modules.sh for Ubuntu (sequential cloning)
# Based on: /home/rahuljoshi/CW/platformui-frontend/node_modules.sh

set -e

INSTALL_CMD="npm i"
TARGET_BRANCH="${1:-master}"
CURRENT_DIR="$(pwd)"

echo "============================================================"
echo "Cloudways Platform UI - Dependency Installation (Ubuntu)"
echo "============================================================"
echo "Target branch: $TARGET_BRANCH"
echo "Working directory: $CURRENT_DIR"
echo ""

# Package directories - these are git submodules
PACKAGES=(
    "packages/container"
    "packages/flexible"
    "packages/fmp-ux3"
    "packages/unified-design-system"
    "packages/guests-app-ux3"
    "packages/agencyos-ux3"
)

# Track success/failure
SUCCESS_COUNT=0
FAILED_PACKAGES=()

# Function to install a single package
install_package() {
    local package_dir="$1"
    local package_name="$(basename "$package_dir")"
    
    echo ""
    echo "============================================================"
    echo "Installing: $package_name"
    echo "============================================================"
    echo ""
    
    if [ ! -d "$package_dir" ]; then
        echo "❌ Directory not found: $package_dir"
        return 1
    fi
    
    cd "$package_dir"
    
    # Git operations (continue even if they fail)
    echo "→ Git operations..."
    git stash 2>&1 || echo "  No local changes to stash"
    git fetch origin 2>&1 || echo "  Fetch failed or not needed"
    git checkout "$TARGET_BRANCH" 2>&1 || echo "  Already on $TARGET_BRANCH"
    git pull origin "$TARGET_BRANCH" 2>&1 || echo "  Pull completed/skipped"
    git stash pop 2>&1 || echo "  No stash to pop"
    
    # Remove node_modules
    echo ""
    echo "→ Removing old node_modules..."
    rm -rf node_modules
    
    # Install dependencies
    echo ""
    echo "→ Running npm install..."
    if $INSTALL_CMD; then
        echo ""
        echo "✅ Installation completed for $package_name"
        cd "$CURRENT_DIR"
        return 0
    else
        echo ""
        echo "❌ Installation failed for $package_name"
        cd "$CURRENT_DIR"
        return 1
    fi
}

# Install each package sequentially
for package in "${PACKAGES[@]}"; do
    package_name=$(basename "$package")
    package_dir="$CURRENT_DIR/$package"
    
    if install_package "$package_dir"; then
        ((SUCCESS_COUNT++))
    else
        FAILED_PACKAGES+=("$package_name")
    fi
done

echo ""
echo "============================================================"
echo "📋 Installation Summary"
echo "============================================================"
echo ""
echo "Total packages: ${#PACKAGES[@]}"
echo "✅ Successful: $SUCCESS_COUNT"
echo "❌ Failed: ${#FAILED_PACKAGES[@]}"

if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    echo ""
    echo "Failed packages:"
    for pkg in "${FAILED_PACKAGES[@]}"; do
        echo "  • $pkg"
    done
    exit 1
fi

echo ""
echo "✅ All installations completed successfully!"
exit 0

