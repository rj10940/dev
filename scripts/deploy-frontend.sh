#!/bin/bash
# Frontend Deployment Automation Script
# Handles cloning, building, and deploying frontend with specific branches

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DEPLOYMENTS_DIR="${PROJECT_ROOT}/deployments"
REPOS_DIR="${PROJECT_ROOT}/repos"
REGISTRY_DB="${DEPLOYMENTS_DIR}/registry.db"
DOMAIN="ods.rahuljoshi.info"
MAX_DEPLOYMENTS_TOTAL=50
MAX_DEPLOYMENTS_PER_USER=3

# API Configuration
API_BASE_URL="https://rj8-dev-ux.cloudways.services"
API_V1_URL="${API_BASE_URL}/api/v1/"
API_V2_URL="${API_BASE_URL}/api/v2/"
CONSOLE_URL="${API_BASE_URL}/"

# GitHub Token for private packages (will be set from environment or parameter)
GITHUB_NPM_TOKEN="${GITHUB_NPM_TOKEN:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check and install sqlite3 if not available
ensure_sqlite3() {
    if ! command -v sqlite3 &> /dev/null; then
        log_warn "sqlite3 not found. Installing..."
        if command -v apt-get &> /dev/null; then
            apt-get update -qq && apt-get install -y sqlite3 >/dev/null 2>&1
            log_info "sqlite3 installed successfully"
        elif command -v yum &> /dev/null; then
            yum install -y sqlite >/dev/null 2>&1
            log_info "sqlite3 installed successfully"
        else
            log_error "Cannot install sqlite3 automatically. Please install manually: apt-get install sqlite3"
            log_warn "Continuing without deployment tracking..."
            export SKIP_REGISTRY=true
            return 1
        fi
    fi
    return 0
}

# Check and install Node.js if not available
ensure_nodejs() {
    local required_version=25
    
    # Check if Node.js exists
    if command -v node &> /dev/null; then
        local current_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$current_version" -ge "$required_version" ]; then
            log_info "Node.js version: $(node -v) ✓"
            log_info "npm version: $(npm -v)"
            return 0
        else
            log_warn "Node.js version $current_version found, but v${required_version}+ required. Upgrading..."
        fi
    else
        log_warn "Node.js not found. Installing Node.js v${required_version}..."
    fi
    
    # Install Node.js v25 (or latest)
    if command -v apt-get &> /dev/null; then
        log_info "Installing Node.js from NodeSource..."
        
        # Remove old Node.js if exists
        apt-get remove -y nodejs npm >/dev/null 2>&1 || true
        
        # Install Node.js v25 from NodeSource
        # Note: If v25 setup script doesn't exist yet, try current instead
        if curl -fsSL https://deb.nodesource.com/setup_25.x 2>/dev/null | bash - >/dev/null 2>&1; then
            log_info "Installing Node.js v25..."
        else
            log_warn "Node.js v25 setup not available, trying current version..."
            curl -fsSL https://deb.nodesource.com/setup_current.x | bash - >/dev/null 2>&1
        fi
        
        apt-get install -y nodejs >/dev/null 2>&1
        
        # Verify installation
        if command -v node &> /dev/null; then
            local installed_version=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
            log_info "Node.js installed successfully: $(node -v)"
            log_info "npm version: $(npm -v)"
            
            if [ "$installed_version" -lt "$required_version" ]; then
                log_warn "Installed version is v$installed_version (required: v${required_version}+)"
                log_warn "Continuing anyway - build may fail if incompatible"
            fi
        else
            log_error "Node.js installation failed"
            exit 1
        fi
    else
        log_error "Cannot install Node.js automatically (apt-get not found)."
        log_error "Please install Node.js v${required_version}+ manually:"
        log_error "  curl -fsSL https://deb.nodesource.com/setup_current.x | bash -"
        log_error "  apt-get install -y nodejs"
        exit 1
    fi
    
    # Check npm
    if ! command -v npm &> /dev/null; then
        log_error "npm not found after Node.js installation"
        exit 1
    fi
    
    return 0
}

# Initialize deployment registry
init_registry() {
    mkdir -p "$DEPLOYMENTS_DIR"
    
    # Try to ensure sqlite3 is available
    ensure_sqlite3 || return 0
    
    if [ "$SKIP_REGISTRY" = "true" ]; then
        log_warn "Registry disabled - sqlite3 not available"
        return 0
    fi
    
    if [ ! -f "$REGISTRY_DB" ]; then
        log_info "Creating deployment registry..."
        sqlite3 "$REGISTRY_DB" <<EOF
CREATE TABLE deployments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE NOT NULL,
    owner TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_accessed DATETIME DEFAULT CURRENT_TIMESTAMP,
    auto_destroy_at DATETIME,
    branch_platformui TEXT,
    url TEXT,
    project_name TEXT
);
EOF
    fi
}

# Check if deployment name is valid
validate_name() {
    local name=$1
    
    if [[ ! "$name" =~ ^[a-z0-9-]+$ ]]; then
        log_error "Invalid deployment name. Use only lowercase, numbers, and hyphens."
        exit 1
    fi
    
    if [ ${#name} -gt 50 ]; then
        log_error "Deployment name too long (max 50 characters)"
        exit 1
    fi
}

# Check deployment limits
check_limits() {
    local owner=$1
    
    # Skip if registry disabled
    if [ "$SKIP_REGISTRY" = "true" ]; then
        return 0
    fi
    
    # Check total deployments
    local total=$(sqlite3 "$REGISTRY_DB" \
        "SELECT COUNT(*) FROM deployments WHERE status='active'" 2>/dev/null || echo "0")
    
    if [ "$total" -ge "$MAX_DEPLOYMENTS_TOTAL" ]; then
        log_error "Total deployment limit reached ($MAX_DEPLOYMENTS_TOTAL active deployments)"
        exit 1
    fi
    
    # Check per-user limit
    local user_count=$(sqlite3 "$REGISTRY_DB" \
        "SELECT COUNT(*) FROM deployments WHERE owner='$owner' AND status='active'" 2>/dev/null || echo "0")
    
    if [ "$user_count" -ge "$MAX_DEPLOYMENTS_PER_USER" ]; then
        log_error "User limit reached: $owner has $user_count/$MAX_DEPLOYMENTS_PER_USER deployments"
        log_info "Please destroy an old deployment first:"
        sqlite3 "$REGISTRY_DB" \
            "SELECT name, created_at FROM deployments WHERE owner='$owner' AND status='active' ORDER BY created_at" 2>/dev/null
        exit 1
    fi
}

# Check if deployment exists
check_exists() {
    local name=$1
    
    # Skip if registry disabled
    if [ "$SKIP_REGISTRY" = "true" ]; then
        return 0
    fi
    
    local exists=$(sqlite3 "$REGISTRY_DB" \
        "SELECT COUNT(*) FROM deployments WHERE name='$name' AND status='active'" 2>/dev/null || echo "0")
    
    if [ "$exists" -gt 0 ]; then
        log_error "Deployment '$name' already exists"
        exit 1
    fi
}

# Clone/update platformui-frontend repository
prepare_frontend_repo() {
    local branch=$1
    local repo_url="git@github.com:cloudways-lab/platformui-frontend.git"
    local repo_dir="${REPOS_DIR}/platformui-frontend"
    
    mkdir -p "$REPOS_DIR"
    
    if [ ! -d "$repo_dir" ]; then
        log_info "Cloning platformui-frontend repository..."
        cd "$REPOS_DIR"
        git clone "$repo_url"
        cd "$repo_dir"
    else
        log_info "Updating platformui-frontend repository..."
        cd "$repo_dir"
        git fetch origin
    fi
    
    log_info "Checking out branch: $branch"
    git checkout "$branch"
    git pull origin "$branch"
    
    log_info "Repository prepared at: $repo_dir"
}

# Initialize and update git submodules
update_submodules() {
    local flexible_branch=${1:-master}
    local fmp_branch=${2:-master}
    local unified_branch=${3:-master}
    local agencyos_branch=${4:-master}
    local guests_branch=${5:-master}
    
    local repo_dir="${REPOS_DIR}/platformui-frontend"
    
    log_info "Initializing git submodules..."
    cd "$repo_dir"
    
    # Initialize and clone submodules
    log_info "Running git submodule update --init --recursive..."
    git submodule update --init --recursive
    
    log_info "Submodules initialized and cloned"
    
    # Setup npm authentication for private packages
    setup_npm_auth
    
    # Update submodules to specified branches
    log_info "Updating submodules to specified branches..."
    
    # Define submodules and their branches
    declare -A submodule_branches=(
        ["packages/flexible"]="$flexible_branch"
        ["packages/fmp-ux3"]="$fmp_branch"
        ["packages/unified-design-system"]="$unified_branch"
        ["packages/agencyos-ux3"]="$agencyos_branch"
        ["packages/guests-app-ux3"]="$guests_branch"
    )
    
    for submodule in "${!submodule_branches[@]}"; do
        local branch="${submodule_branches[$submodule]}"
        
        if [ -d "$submodule" ]; then
            log_info "  → Updating $submodule to branch: $branch..."
            cd "$repo_dir/$submodule"
            
            # Fetch all branches
            git fetch origin
            
            # Checkout specified branch
            if git rev-parse --verify "origin/$branch" &>/dev/null; then
                git checkout "$branch"
                git pull origin "$branch"
                log_info "     ✓ $submodule: $branch"
            else
                log_warn "     ! Branch '$branch' not found for $submodule, trying master/main..."
                if git rev-parse --verify origin/master &>/dev/null; then
                    git checkout master
                    git pull origin master
                elif git rev-parse --verify origin/main &>/dev/null; then
                    git checkout main
                    git pull origin main
                else
                    log_error "     ! Could not find suitable branch for $submodule"
                fi
            fi
            
            cd "$repo_dir"
        fi
    done
    
    log_info "Submodules updated successfully"
}

# Setup npm authentication for private packages
setup_npm_auth() {
    local repo_dir="${REPOS_DIR}/platformui-frontend"
    
    if [ -z "$GITHUB_NPM_TOKEN" ]; then
        log_warn "No GitHub NPM token provided - private packages may fail to install"
        log_info "Set GITHUB_NPM_TOKEN environment variable to authenticate"
        return 0
    fi
    
    log_info "Setting up npm authentication for private packages..."
    cd "$repo_dir"
    
    # Define micro frontend directories
    local microfrontend_dirs=(
        "packages/agencyos-ux3"
        "packages/container"
        "packages/flexible"
        "packages/fmp-ux3"
        "packages/guests-app-ux3"
        "packages/unified-design-system"
    )
    
    # Create .npmrc for each micro frontend
    for dir in "${microfrontend_dirs[@]}"; do
        if [ -d "$dir" ]; then
            log_info "  → Configuring $dir..."
            
            # Create .npmrc file
            cat > "$dir/.npmrc" <<EOF
//npm.pkg.github.com/:_authToken=${GITHUB_NPM_TOKEN}
@cloudways-lab:registry=https://npm.pkg.github.com/
EOF
            
            # Update .gitignore to protect token
            if [ -f "$dir/.gitignore" ]; then
                if ! grep -q "^\.npmrc$" "$dir/.gitignore" 2>/dev/null; then
                    echo ".npmrc" >> "$dir/.gitignore"
                fi
            else
                echo ".npmrc" > "$dir/.gitignore"
            fi
            
            log_info "     ✓ $dir configured"
        fi
    done
    
    log_info "npm authentication configured successfully"
}

# Install dependencies
install_dependencies() {
    local repo_dir="${REPOS_DIR}/platformui-frontend"
    
    log_info "Installing dependencies..."
    cd "$repo_dir"
    
    # Use our custom install script
    bash "${SCRIPT_DIR}/install-deps-ubuntu.sh" master
}

# Update .env file with correct API URLs
update_env_file() {
    local deployment_name=$1
    local repo_dir="${REPOS_DIR}/platformui-frontend"
    local container_dir="${repo_dir}/packages/container"
    
    log_info "Updating environment configuration..."
    
    # Create custom .env.development file
    cat > "${container_dir}/.env.development" <<EOF
REACT_APP_TYPE='dev'
REACT_APP_BASE_URL_MEMBER=${API_V1_URL}
REACT_APP_AUTH_URL_JWT=${API_V2_URL}
REACT_APP_ANGULAR_APP_URL=${CONSOLE_URL}
REACT_APP_COOKIE_CONST=cloudways.services
REACT_APP_INTERCOM_APP_ID=dp2f6zfx
REACT_APP_VIRALLOOP_APP_ID=yw44WOh_o0kHDruR990qPc5LVF8
PUBLIC_URL=/
BUILD_PATH=./dist
REACT_APP_GCE_PLACES_API=AIzaSyAy1fZSYBMFNmAJPO5MpbgWBaNi5SkxFn8
EOF
    
    log_info "Environment configured to use: $API_BASE_URL"
}

# Build frontend
build_frontend() {
    local deployment_name=$1
    local repo_dir="${REPOS_DIR}/platformui-frontend"
    local container_dir="${repo_dir}/packages/container"
    
    log_info "Building frontend application..."
    cd "$container_dir"
    
    # Build using development environment
    REACT_APP_ENV=development npm run build:dev
    
    log_info "Build completed successfully"
    log_info "Build output: ${container_dir}/dist"
}

# Create deployment environment file
create_deployment_env() {
    local deployment_name=$1
    
    cat > "${PROJECT_ROOT}/.env.${deployment_name}" <<EOF
DEV_NAME=${deployment_name}
SUBDOMAIN=${deployment_name}.${DOMAIN}
PROJECT_NAME=${deployment_name}-ods
REPO_PATH=${REPOS_DIR}/platformui-frontend/packages/container
EOF
    
    log_info "Deployment environment created: .env.${deployment_name}"
}

# Start Docker containers
start_containers() {
    local deployment_name=$1
    
    log_info "Starting Docker containers..."
    cd "$PROJECT_ROOT"
    
    docker-compose \
        --env-file ".env.${deployment_name}" \
        --project-name "${deployment_name}-ods" \
        -f docker-compose.frontend.yml \
        up -d --build
    
    log_info "Containers started successfully"
}

# Register deployment in database
register_deployment() {
    local name=$1
    local owner=$2
    local frontend_branch=$3
    local auto_destroy_days=$4
    local flexible_branch=${5:-master}
    local fmp_branch=${6:-master}
    local unified_branch=${7:-master}
    local agencyos_branch=${8:-master}
    local guests_branch=${9:-master}
    
    # Skip if registry disabled
    if [ "$SKIP_REGISTRY" = "true" ]; then
        log_warn "Registry disabled - deployment not tracked in database"
        return 0
    fi
    
    local auto_destroy_at=""
    if [ "$auto_destroy_days" != "never" ]; then
        auto_destroy_at=$(date -d "+${auto_destroy_days} days" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date -v+${auto_destroy_days}d '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
    fi
    
    # Create JSON of all branches
    local branches_json=$(cat <<EOF
{
  "platformui_frontend": "$frontend_branch",
  "flexible_ux3": "$flexible_branch",
  "fmp_ux3": "$fmp_branch",
  "unified_design_system": "$unified_branch",
  "agencyos_ux3": "$agencyos_branch",
  "guests_app_ux3": "$guests_branch"
}
EOF
    )
    
    sqlite3 "$REGISTRY_DB" <<EOF 2>/dev/null
INSERT INTO deployments (name, owner, status, branch_platformui, auto_destroy_at, url, project_name)
VALUES (
    '$name',
    '$owner',
    'active',
    '$(echo "$branches_json" | tr -d '\n')',
    '$auto_destroy_at',
    'https://${name}.${DOMAIN}',
    '${name}-ods'
);
EOF
    
    if [ $? -eq 0 ]; then
        log_info "Deployment registered in database"
    else
        log_warn "Could not register deployment in database (continuing anyway)"
    fi
}

# Main deployment function
deploy() {
    local deployment_name=$1
    local frontend_branch=${2:-master}
    local owner=${3:-$(whoami)}
    local auto_destroy_days=${4:-7}
    local flexible_branch=${5:-master}
    local fmp_branch=${6:-master}
    local unified_branch=${7:-master}
    local agencyos_branch=${8:-master}
    local guests_branch=${9:-master}
    
    log_info "=========================================="
    log_info "Starting Frontend Deployment"
    log_info "=========================================="
    log_info "Deployment: $deployment_name"
    log_info "Owner: $owner"
    log_info "Branches:"
    log_info "  - platformui-frontend: $frontend_branch"
    log_info "  - flexible-ux3: $flexible_branch"
    log_info "  - fmp-ux3: $fmp_branch"
    log_info "  - unified-design-system: $unified_branch"
    log_info "  - agencyos-ux3: $agencyos_branch"
    log_info "  - guests-app-ux3: $guests_branch"
    log_info ""
    
    # Validations
    validate_name "$deployment_name"
    init_registry
    check_limits "$owner"
    check_exists "$deployment_name"
    
    # Ensure Node.js is installed
    ensure_nodejs
    
    # Update deployment status
    sqlite3 "$REGISTRY_DB" <<EOF 2>/dev/null
INSERT OR REPLACE INTO deployments (name, owner, status, branch_platformui)
VALUES ('$deployment_name', '$owner', 'creating', '$frontend_branch');
EOF
    
    # Deployment steps
    prepare_frontend_repo "$frontend_branch"
    update_submodules "$flexible_branch" "$fmp_branch" "$unified_branch" "$agencyos_branch" "$guests_branch"
    install_dependencies
    update_env_file "$deployment_name"
    build_frontend "$deployment_name"
    create_deployment_env "$deployment_name"
    start_containers "$deployment_name"
    register_deployment "$deployment_name" "$owner" "$frontend_branch" "$auto_destroy_days" \
        "$flexible_branch" "$fmp_branch" "$unified_branch" "$agencyos_branch" "$guests_branch"
    
    log_info ""
    log_info "=========================================="
    log_info "✅ Deployment Complete!"
    log_info "=========================================="
    log_info "📍 URL: https://${deployment_name}.${DOMAIN}"
    log_info "🔗 API: $API_BASE_URL"
    log_info "🌿 Branches:"
    log_info "   - platformui-frontend: $frontend_branch"
    log_info "   - flexible-ux3: $flexible_branch"
    log_info "   - fmp-ux3: $fmp_branch"
    log_info "   - unified-design-system: $unified_branch"
    log_info "   - agencyos-ux3: $agencyos_branch"
    log_info "   - guests-app-ux3: $guests_branch"
    log_info "⏰ Auto-destroy: ${auto_destroy_days} days"
    log_info ""
}

# Destroy deployment
destroy() {
    local deployment_name=$1
    
    log_info "Destroying deployment: $deployment_name"
    
    cd "$PROJECT_ROOT"
    
    # Stop and remove containers
    docker-compose --project-name "${deployment_name}-ods" -f docker-compose.frontend.yml down -v 2>/dev/null || true
    
    # Remove environment file
    rm -f ".env.${deployment_name}"
    
    # Update registry if available
    if [ "$SKIP_REGISTRY" != "true" ] && [ -f "$REGISTRY_DB" ]; then
        sqlite3 "$REGISTRY_DB" \
            "UPDATE deployments SET status='destroyed' WHERE name='$deployment_name'" 2>/dev/null || true
    fi
    
    log_info "✅ Deployment destroyed"
}

# List all deployments
list_deployments() {
    init_registry
    
    if [ "$SKIP_REGISTRY" = "true" ]; then
        log_error "Registry not available. Cannot list deployments."
        log_info "Use 'docker ps' to see running containers"
        return 1
    fi
    
    echo ""
    echo "=== Active Deployments ==="
    sqlite3 -header -column "$REGISTRY_DB" \
        "SELECT name, owner, url, branch_platformui, created_at FROM deployments WHERE status='active' ORDER BY created_at DESC" 2>/dev/null
    echo ""
}

# Main command router
case "${1:-}" in
    deploy)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 deploy <deployment-name> <frontend-branch> [owner] [auto-destroy-days] [flexible-branch] [fmp-branch] [unified-branch] [agencyos-branch] [guests-branch]"
            exit 1
        fi
        deploy "$2" "$3" "${4:-$(whoami)}" "${5:-7}" "${6:-master}" "${7:-master}" "${8:-master}" "${9:-master}" "${10:-master}"
        ;;
    destroy)
        if [ -z "$2" ]; then
            echo "Usage: $0 destroy <deployment-name>"
            exit 1
        fi
        destroy "$2"
        ;;
    list)
        list_deployments
        ;;
    *)
        echo "Usage: $0 {deploy|destroy|list}"
        echo ""
        echo "Commands:"
        echo "  deploy <name> <frontend-branch> [owner] [days] [flexible] [fmp] [unified] [agencyos] [guests]"
        echo "      - Deploy frontend with specified branches for all submodules"
        echo "  destroy <name>"
        echo "      - Destroy a deployment"
        echo "  list"
        echo "      - List all active deployments"
        echo ""
        echo "Example:"
        echo "  $0 deploy rahul-feature-123 feature/new-dashboard rahul 7 master master master master master"
        echo "  $0 deploy rahul-test master rahul 7 feature/ui-update master main develop master"
        exit 1
        ;;
esac

