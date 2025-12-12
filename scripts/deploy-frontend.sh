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

# Initialize deployment registry
init_registry() {
    mkdir -p "$DEPLOYMENTS_DIR"
    
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
    
    # Check total deployments
    local total=$(sqlite3 "$REGISTRY_DB" \
        "SELECT COUNT(*) FROM deployments WHERE status='active'")
    
    if [ "$total" -ge "$MAX_DEPLOYMENTS_TOTAL" ]; then
        log_error "Total deployment limit reached ($MAX_DEPLOYMENTS_TOTAL active deployments)"
        exit 1
    fi
    
    # Check per-user limit
    local user_count=$(sqlite3 "$REGISTRY_DB" \
        "SELECT COUNT(*) FROM deployments WHERE owner='$owner' AND status='active'")
    
    if [ "$user_count" -ge "$MAX_DEPLOYMENTS_PER_USER" ]; then
        log_error "User limit reached: $owner has $user_count/$MAX_DEPLOYMENTS_PER_USER deployments"
        log_info "Please destroy an old deployment first:"
        sqlite3 "$REGISTRY_DB" \
            "SELECT name, created_at FROM deployments WHERE owner='$owner' AND status='active' ORDER BY created_at"
        exit 1
    fi
}

# Check if deployment exists
check_exists() {
    local name=$1
    local exists=$(sqlite3 "$REGISTRY_DB" \
        "SELECT COUNT(*) FROM deployments WHERE name='$name' AND status='active'")
    
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
    local repo_dir="${REPOS_DIR}/platformui-frontend"
    
    log_info "Initializing git submodules..."
    cd "$repo_dir"
    
    # Initialize submodules if not already done
    git submodule init
    
    # Update submodules to their master/main branches
    log_info "Updating submodules sequentially..."
    
    local submodules=(
        "packages/flexible"
        "packages/fmp-ux3"
        "packages/unified-design-system"
        "packages/guests-app-ux3"
        "packages/agencyos-ux3"
    )
    
    for submodule in "${submodules[@]}"; do
        if [ -d "$submodule" ]; then
            log_info "  → Updating $submodule..."
            cd "$repo_dir/$submodule"
            
            # Try master first, then main
            if git rev-parse --verify origin/master &>/dev/null; then
                git checkout master
                git pull origin master
            elif git rev-parse --verify origin/main &>/dev/null; then
                git checkout main
                git pull origin main
            else
                log_warn "  ! Could not determine default branch for $submodule"
            fi
            
            cd "$repo_dir"
        fi
    done
    
    log_info "Submodules updated successfully"
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
    local branch=$3
    local auto_destroy_days=${4:-7}
    
    local auto_destroy_at=""
    if [ "$auto_destroy_days" != "never" ]; then
        auto_destroy_at=$(date -d "+${auto_destroy_days} days" '+%Y-%m-%d %H:%M:%S')
    fi
    
    sqlite3 "$REGISTRY_DB" <<EOF
INSERT INTO deployments (name, owner, status, branch_platformui, auto_destroy_at, url, project_name)
VALUES (
    '$name',
    '$owner',
    'active',
    '$branch',
    '$auto_destroy_at',
    'https://${name}.${DOMAIN}',
    '${name}-ods'
);
EOF
    
    log_info "Deployment registered in database"
}

# Main deployment function
deploy() {
    local deployment_name=$1
    local branch=${2:-master}
    local owner=${3:-$(whoami)}
    local auto_destroy_days=${4:-7}
    
    log_info "=========================================="
    log_info "Starting Frontend Deployment"
    log_info "=========================================="
    log_info "Deployment: $deployment_name"
    log_info "Branch: $branch"
    log_info "Owner: $owner"
    log_info ""
    
    # Validations
    validate_name "$deployment_name"
    init_registry
    check_limits "$owner"
    check_exists "$deployment_name"
    
    # Update deployment status
    sqlite3 "$REGISTRY_DB" <<EOF
INSERT OR REPLACE INTO deployments (name, owner, status, branch_platformui)
VALUES ('$deployment_name', '$owner', 'creating', '$branch');
EOF
    
    # Deployment steps
    prepare_frontend_repo "$branch"
    update_submodules
    install_dependencies
    update_env_file "$deployment_name"
    build_frontend "$deployment_name"
    create_deployment_env "$deployment_name"
    start_containers "$deployment_name"
    register_deployment "$deployment_name" "$owner" "$branch" "$auto_destroy_days"
    
    log_info ""
    log_info "=========================================="
    log_info "✅ Deployment Complete!"
    log_info "=========================================="
    log_info "📍 URL: https://${deployment_name}.${DOMAIN}"
    log_info "🔗 API: $API_BASE_URL"
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
    
    # Update registry
    sqlite3 "$REGISTRY_DB" \
        "UPDATE deployments SET status='destroyed' WHERE name='$deployment_name'"
    
    log_info "✅ Deployment destroyed"
}

# List all deployments
list_deployments() {
    init_registry
    
    echo ""
    echo "=== Active Deployments ==="
    sqlite3 -header -column "$REGISTRY_DB" \
        "SELECT name, owner, url, branch_platformui, created_at FROM deployments WHERE status='active' ORDER BY created_at DESC"
    echo ""
}

# Main command router
case "${1:-}" in
    deploy)
        if [ -z "$2" ] || [ -z "$3" ]; then
            echo "Usage: $0 deploy <deployment-name> <branch-name> [owner] [auto-destroy-days]"
            exit 1
        fi
        deploy "$2" "$3" "${4:-$(whoami)}" "${5:-7}"
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
        echo "  deploy <name> <branch> [owner] [days]  - Deploy frontend with specified branch"
        echo "  destroy <name>                          - Destroy a deployment"
        echo "  list                                    - List all active deployments"
        echo ""
        echo "Example:"
        echo "  $0 deploy rahul-feature-123 feature/new-dashboard rahul 7"
        exit 1
        ;;
esac

