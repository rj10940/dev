#!/bin/bash
# Local Test Script - Test the deployment locally before pushing to VPS

set -e

echo "============================================================"
echo "ODS Frontend - Local Build Test"
echo "============================================================"
echo ""

# Configuration
PLATFORMUI_REPO="/home/rahuljoshi/CW/platformui-frontend"
TEST_BRANCH="${1:-master}"

if [ ! -d "$PLATFORMUI_REPO" ]; then
    echo "❌ platformui-frontend not found at: $PLATFORMUI_REPO"
    exit 1
fi

echo "📦 Repository: $PLATFORMUI_REPO"
echo "🌿 Branch: $TEST_BRANCH"
echo ""

# Go to repo
cd "$PLATFORMUI_REPO"

# Checkout branch
echo "→ Checking out branch: $TEST_BRANCH"
git checkout "$TEST_BRANCH"
git pull origin "$TEST_BRANCH"

# Update submodules
echo "→ Updating submodules..."
git submodule update --init --recursive

# Install dependencies
echo "→ Installing dependencies..."
bash node_modules.sh "$TEST_BRANCH"

# Update .env for testing
echo "→ Configuring environment..."
cd packages/container

cat > .env.development <<EOF
REACT_APP_TYPE='dev'
REACT_APP_BASE_URL_MEMBER=https://rj8-dev-ux.cloudways.services/api/v1/
REACT_APP_AUTH_URL_JWT=https://rj8-dev-ux.cloudways.services/api/v2/
REACT_APP_ANGULAR_APP_URL=https://rj8-dev-ux.cloudways.services/
REACT_APP_COOKIE_CONST=cloudways.services
REACT_APP_INTERCOM_APP_ID=dp2f6zfx
REACT_APP_VIRALLOOP_APP_ID=yw44WOh_o0kHDruR990qPc5LVF8
PUBLIC_URL=/
BUILD_PATH=./dist
REACT_APP_GCE_PLACES_API=AIzaSyAy1fZSYBMFNmAJPO5MpbgWBaNi5SkxFn8
EOF

# Build
echo "→ Building frontend..."
REACT_APP_ENV=development npm run build:dev

echo ""
echo "============================================================"
echo "✅ Build Successful!"
echo "============================================================"
echo ""
echo "📁 Build output: $PLATFORMUI_REPO/packages/container/dist"
echo "🔗 API configured: https://rj8-dev-ux.cloudways.services"
echo ""
echo "To test locally:"
echo "  cd $PLATFORMUI_REPO/packages/container/dist"
echo "  python3 -m http.server 8000"
echo "  Open: http://localhost:8000"
echo ""

