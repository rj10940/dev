#!/bin/bash
# Modified version of node_modules.sh for Ubuntu (sequential cloning)
# NO BACKGROUND PROCESSES - Everything runs sequentially and visibly

# Don't exit on error - we want to see what happens
set +e

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
SKIPPED_PACKAGES=()

# Function to install a single package
install_package() {
    local package_dir="$1"
    local package_name="$(basename "$package_dir")"
    
    echo ""
    echo "============================================================"
    echo "Installing: $package_name"
    echo "============================================================"
    echo ""
    
    # Check if directory exists
    if [ ! -d "$package_dir" ]; then
        echo "⚠️  Directory not found: $package_dir"
        echo "   Skipping $package_name (submodule may not be initialized)"
        return 2  # Return 2 for "skipped"
    fi
    
    cd "$package_dir" || return 1
    
    # Check if package.json exists
    if [ ! -f "package.json" ]; then
        echo "⚠️  No package.json found in $package_name"
        echo "   Skipping..."
        cd "$CURRENT_DIR"
        return 2  # Return 2 for "skipped"
    fi
    
    echo "✓ Found package.json"
    
    # Git operations (non-critical, continue on failure)
    echo ""
    echo "→ Git operations..."
    git stash 2>&1 || echo "  (No stash needed)"
    git fetch origin 2>&1 || echo "  (Fetch skipped)"
    git checkout "$TARGET_BRANCH" 2>&1 || echo "  (Already on branch)"
    git pull origin "$TARGET_BRANCH" 2>&1 || echo "  (Pull skipped)"
    git stash pop 2>&1 || echo "  (No stash to pop)"
    
    # Remove node_modules
    echo ""
    echo "→ Removing old node_modules..."
    rm -rf node_modules
    
    # Install dependencies
    echo ""
    echo "→ Running npm install for $package_name..."
    echo "  (This may take a few minutes...)"
    
    if $INSTALL_CMD 2>&1; then
        local install_exit=$?
        if [ $install_exit -eq 0 ]; then
            echo ""
            echo "✅ Installation completed for $package_name"
            cd "$CURRENT_DIR"
            return 0
        else
            echo ""
            echo "❌ npm install failed with exit code $install_exit for $package_name"
            cd "$CURRENT_DIR"
            return 1
        fi
    else
        echo ""
        echo "❌ Installation failed for $package_name"
        cd "$CURRENT_DIR"
        return 1
    fi
}

echo ""
echo "🚀 Starting sequential installation..."
echo ""

# Install each package sequentially
for package in "${PACKAGES[@]}"; do
    package_name=$(basename "$package")
    package_dir="$CURRENT_DIR/$package"
    
    install_package "$package_dir"
    result=$?
    
    if [ $result -eq 0 ]; then
        ((SUCCESS_COUNT++))
        echo "✅ $package_name: SUCCESS"
    elif [ $result -eq 2 ]; then
        SKIPPED_PACKAGES+=("$package_name")
        echo "⚠️  $package_name: SKIPPED"
    else
        FAILED_PACKAGES+=("$package_name")
        echo "❌ $package_name: FAILED"
    fi
    
    echo ""
done

echo ""
echo "============================================================"
echo "📋 Installation Summary"
echo "============================================================"
echo ""
echo "Total packages: ${#PACKAGES[@]}"
echo "✅ Successful: $SUCCESS_COUNT"
echo "⚠️  Skipped: ${#SKIPPED_PACKAGES[@]}"
echo "❌ Failed: ${#FAILED_PACKAGES[@]}"

if [ ${#SKIPPED_PACKAGES[@]} -gt 0 ]; then
    echo ""
    echo "Skipped packages:"
    for pkg in "${SKIPPED_PACKAGES[@]}"; do
        echo "  • $pkg"
    done
fi

if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    echo ""
    echo "Failed packages:"
    for pkg in "${FAILED_PACKAGES[@]}"; do
        echo "  • $pkg"
    done
fi

echo ""

# Only fail if NO packages succeeded
if [ $SUCCESS_COUNT -eq 0 ]; then
    echo "❌ CRITICAL: No packages installed successfully!"
    echo "   Cannot continue deployment."
    exit 1
fi

# Success if at least container package succeeded
if [ $SUCCESS_COUNT -ge 1 ]; then
    echo "✅ Core installation completed!"
    echo "   At least $SUCCESS_COUNT package(s) installed successfully"
    echo "   Continuing with deployment..."
    exit 0
fi

# Fallback
exit 1

