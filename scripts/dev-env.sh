#!/bin/bash
# Cloudways Developer Environment CLI
# Manages per-developer Docker environments with branch support

set -e

# Configuration
BASE_DIR="/opt/cloudways-dev"
CONFIG_DIR="$BASE_DIR/developers"
REPOS_DIR="$BASE_DIR/repos"
KEYS_DIR="$BASE_DIR/keys"
TEMPLATE_FILE="$BASE_DIR/docker-compose.template.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get branch for a repo from developer config
get_branch() {
    local dev=$1
    local repo=$2
    local default=${3:-main}
    
    if [ -f "$CONFIG_DIR/${dev}.yml" ]; then
        branch=$(yq -r ".branches.\"$repo\" // \"$default\"" "$CONFIG_DIR/${dev}.yml" 2>/dev/null)
        if [ "$branch" = "null" ] || [ -z "$branch" ]; then
            echo "$default"
        else
            echo "$branch"
        fi
    else
        echo "$default"
    fi
}

# Calculate port for a developer (based on hash of name)
get_port_offset() {
    local dev=$1
    # Generate a number between 0-99 based on developer name
    echo $(($(echo -n "$dev" | cksum | cut -d' ' -f1) % 100))
}

# Checkout branches for a developer
# NOTE: ansible-api-v2 is shared, so not included here
checkout_branches() {
    local dev=$1
    
    log_info "Checking out branches for $dev..."
    
    export GIT_SSH_COMMAND="ssh -i $KEYS_DIR/github_deploy_key -o StrictHostKeyChecking=no"
    
    for repo in cg-console-new cg-apiserver flexible-middleware flexible-operation-engine cg-event-service cg-comms-service; do
        if [ -d "$REPOS_DIR/$repo" ]; then
            branch=$(get_branch "$dev" "$repo")
            log_info "  $repo -> $branch"
            
            cd "$REPOS_DIR/$repo"
            git fetch origin 2>/dev/null || log_warn "Failed to fetch $repo"
            git checkout "$branch" 2>/dev/null || git checkout -b "$branch" "origin/$branch" 2>/dev/null || log_warn "Branch $branch not found for $repo"
            git pull origin "$branch" 2>/dev/null || true
        fi
    done
    
    cd "$BASE_DIR"
}

# Create developer databases
create_databases() {
    local dev=$1
    
    log_info "Creating databases for $dev..."
    
    # Wait for MySQL to be ready
    local retries=30
    while ! docker exec shared-mysql mysqladmin ping -h localhost -uroot -proot --silent 2>/dev/null; do
        retries=$((retries - 1))
        if [ $retries -eq 0 ]; then
            log_error "MySQL is not ready after 30 seconds"
            return 1
        fi
        sleep 1
    done
    
    docker exec shared-mysql mysql -uroot -proot -e "
        CREATE DATABASE IF NOT EXISTS cw_${dev}_platform CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE DATABASE IF NOT EXISTS cw_${dev}_middleware CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
        CREATE DATABASE IF NOT EXISTS cw_${dev}_comms CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    " 2>/dev/null
    
    # Create PostgreSQL database for events
    docker exec shared-postgres psql -U postgres -c "
        SELECT 'CREATE DATABASE cw_${dev}_events' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'cw_${dev}_events')\gexec
    " 2>/dev/null || true
    
    log_success "Databases created"
}

# Generate docker-compose file for developer
# NOTE: Ansible is shared, not per-developer
generate_compose() {
    local dev=$1
    local compose_file="$BASE_DIR/docker-compose.${dev}.yml"
    
    log_info "Generating docker-compose file..."
    
    # Get branches (ansible excluded - it's shared)
    local platform_branch=$(get_branch "$dev" "cg-console-new" "main")
    local mw_branch=$(get_branch "$dev" "cg-apiserver" "main")
    local flexible_branch=$(get_branch "$dev" "flexible-middleware" "main")
    local fmoe_branch=$(get_branch "$dev" "flexible-operation-engine" "main")
    local events_branch=$(get_branch "$dev" "cg-event-service" "main")
    local comms_branch=$(get_branch "$dev" "cg-comms-service" "main")
    
    # Generate compose file from template
    sed -e "s/DEVELOPER/${dev}/g" \
        -e "s/PLATFORM_BRANCH/${platform_branch}/g" \
        -e "s/MW_BRANCH/${mw_branch}/g" \
        -e "s/FLEXIBLE_BRANCH/${flexible_branch}/g" \
        -e "s/FMOE_BRANCH/${fmoe_branch}/g" \
        -e "s/EVENTS_BRANCH/${events_branch}/g" \
        -e "s/COMMS_BRANCH/${comms_branch}/g" \
        "$TEMPLATE_FILE" > "$compose_file"
    
    log_success "Generated $compose_file"
}

# Create new developer environment
cmd_create() {
    local dev=$1
    
    if [ -z "$dev" ]; then
        log_error "Developer name required"
        echo "Usage: $0 create <developer-name>"
        exit 1
    fi
    
    log_info "Creating environment for: $dev"
    
    # Check prerequisites
    if [ ! -f "$KEYS_DIR/github_deploy_key" ]; then
        log_error "Deploy key not found at $KEYS_DIR/github_deploy_key"
        log_info "Run: ./scripts/generate-deploy-key.sh"
        exit 1
    fi
    
    # Check if shared services are running
    if ! docker ps | grep -q shared-mysql; then
        log_warn "Shared services not running. Starting them..."
        docker compose -f "$BASE_DIR/shared/docker-compose.yml" up -d
        sleep 10
    fi
    
    # Create developer config if not exists
    if [ ! -f "$CONFIG_DIR/${dev}.yml" ]; then
        log_info "Creating default config for $dev..."
        cat > "$CONFIG_DIR/${dev}.yml" << EOF
# Developer Configuration: $dev
# Edit branches below, then run: ./dev-env.sh create $dev
# NOTE: ansible-api-v2 is shared across all developers (shared-ansible)

developer: $dev

branches:
  cg-console-new: main
  cg-apiserver: main
  flexible-middleware: main
  flexible-operation-engine: main
  cg-event-service: main
  cg-comms-service: main
  platformui-frontend: main

environment:
  APP_DEBUG: "true"
EOF
        log_success "Created config at $CONFIG_DIR/${dev}.yml"
        log_info "Edit the config file to set your branches, then run this command again"
        exit 0
    fi
    
    # Checkout branches
    checkout_branches "$dev"
    
    # Create databases
    create_databases "$dev"
    
    # Generate compose file
    generate_compose "$dev"
    
    # Start services
    log_info "Starting services..."
    docker compose -f "$BASE_DIR/docker-compose.${dev}.yml" up -d
    
    # Wait for services to be ready
    sleep 5
    
    # Run migrations
    log_info "Running migrations..."
    docker exec "${dev}-platform" php artisan migrate --force 2>/dev/null || log_warn "Platform migration failed"
    docker exec "${dev}-flexible" php artisan migrate --force 2>/dev/null || log_warn "Flexible migration failed"
    
    # Run seeders (only first time)
    log_info "Running seeders..."
    docker exec "${dev}-platform" php artisan db:seed 2>/dev/null || log_warn "Seeding skipped (may already be seeded)"
    
    log_success "Environment created for $dev!"
    echo ""
    echo "Access URLs:"
    echo "  Platform:    http://${dev}.dev.cw.local"
    echo "  API:         http://api-${dev}.dev.cw.local"
    echo "  Flexible:    http://flexible-${dev}.dev.cw.local"
    echo ""
    echo "Add to /etc/hosts:"
    echo "  DROPLET_IP  ${dev}.dev.cw.local api-${dev}.dev.cw.local flexible-${dev}.dev.cw.local"
}

# Update branch for a specific repo
cmd_update_branch() {
    local dev=$1
    local repo=$2
    local new_branch=$3
    
    if [ -z "$dev" ] || [ -z "$repo" ] || [ -z "$new_branch" ]; then
        log_error "Missing arguments"
        echo "Usage: $0 update-branch <developer> <repo> <branch>"
        exit 1
    fi
    
    log_info "Updating $repo to branch $new_branch for $dev"
    
    # Update config file
    yq -i ".branches.\"$repo\" = \"$new_branch\"" "$CONFIG_DIR/${dev}.yml"
    
    # Checkout new branch
    export GIT_SSH_COMMAND="ssh -i $KEYS_DIR/github_deploy_key -o StrictHostKeyChecking=no"
    cd "$REPOS_DIR/$repo"
    git fetch origin
    git checkout "$new_branch" 2>/dev/null || git checkout -b "$new_branch" "origin/$new_branch"
    git pull origin "$new_branch"
    
    # Map repo to container name
    local container_name
    case "$repo" in
        cg-console-new) container_name="${dev}-platform" ;;
        cg-apiserver) container_name="${dev}-middleware" ;;
        flexible-middleware) container_name="${dev}-flexible" ;;
        flexible-operation-engine) container_name="${dev}-fmoe" ;;
        ansible-api-v2) container_name="${dev}-ansible" ;;
        cg-event-service) container_name="${dev}-events" ;;
        cg-comms-service) container_name="${dev}-comms" ;;
        *) container_name="${dev}-${repo}" ;;
    esac
    
    # Restart container
    docker restart "$container_name" 2>/dev/null || log_warn "Container $container_name not found"
    
    log_success "Updated $repo to $new_branch"
}

# Pull latest code for all repos
cmd_pull() {
    local dev=$1
    
    if [ -z "$dev" ]; then
        log_error "Developer name required"
        exit 1
    fi
    
    checkout_branches "$dev"
    
    # Restart all containers
    docker compose -f "$BASE_DIR/docker-compose.${dev}.yml" restart
    
    log_success "Pulled latest code and restarted services"
}

# Show status of developer environment
cmd_status() {
    local dev=$1
    
    if [ -z "$dev" ]; then
        # Show all developers
        log_info "Developer environments:"
        docker ps --filter "name=-platform" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    else
        # Show specific developer
        log_info "Environment status for: $dev"
        docker ps --filter "name=${dev}-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        
        echo ""
        log_info "Branches:"
        if [ -f "$CONFIG_DIR/${dev}.yml" ]; then
            yq '.branches' "$CONFIG_DIR/${dev}.yml"
        fi
    fi
}

# Show logs for developer services
cmd_logs() {
    local dev=$1
    local service=$2
    
    if [ -z "$dev" ]; then
        log_error "Developer name required"
        exit 1
    fi
    
    if [ -n "$service" ]; then
        docker logs -f "${dev}-${service}"
    else
        docker compose -f "$BASE_DIR/docker-compose.${dev}.yml" logs -f
    fi
}

# Destroy developer environment
cmd_destroy() {
    local dev=$1
    
    if [ -z "$dev" ]; then
        log_error "Developer name required"
        exit 1
    fi
    
    log_warn "This will destroy environment for: $dev"
    read -p "Are you sure? (y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "Cancelled"
        exit 0
    fi
    
    # Stop and remove containers
    docker compose -f "$BASE_DIR/docker-compose.${dev}.yml" down -v 2>/dev/null || true
    
    # Drop databases
    docker exec shared-mysql mysql -uroot -proot -e "
        DROP DATABASE IF EXISTS cw_${dev}_platform;
        DROP DATABASE IF EXISTS cw_${dev}_middleware;
        DROP DATABASE IF EXISTS cw_${dev}_comms;
    " 2>/dev/null || true
    
    docker exec shared-postgres psql -U postgres -c "DROP DATABASE IF EXISTS cw_${dev}_events;" 2>/dev/null || true
    
    # Remove compose file
    rm -f "$BASE_DIR/docker-compose.${dev}.yml"
    
    log_success "Environment destroyed for $dev"
    log_info "Config file kept at $CONFIG_DIR/${dev}.yml"
}

# Restart developer services
cmd_restart() {
    local dev=$1
    local service=$2
    
    if [ -z "$dev" ]; then
        log_error "Developer name required"
        exit 1
    fi
    
    if [ -n "$service" ]; then
        docker restart "${dev}-${service}"
    else
        docker compose -f "$BASE_DIR/docker-compose.${dev}.yml" restart
    fi
    
    log_success "Services restarted"
}

# Execute command in container
cmd_exec() {
    local dev=$1
    local service=$2
    shift 2
    local cmd="$@"
    
    if [ -z "$dev" ] || [ -z "$service" ]; then
        log_error "Developer and service required"
        echo "Usage: $0 exec <developer> <service> <command>"
        exit 1
    fi
    
    docker exec -it "${dev}-${service}" $cmd
}

# Show help
cmd_help() {
    echo "Cloudways Developer Environment CLI"
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  create <developer>                    Create new developer environment"
    echo "  destroy <developer>                   Remove developer environment"
    echo "  update-branch <dev> <repo> <branch>   Update branch for a repository"
    echo "  pull <developer>                      Pull latest code for all repos"
    echo "  status [developer]                    Show environment status"
    echo "  logs <developer> [service]            Show logs"
    echo "  restart <developer> [service]         Restart services"
    echo "  exec <developer> <service> <cmd>      Execute command in container"
    echo "  help                                  Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 create rahul"
    echo "  $0 update-branch rahul cg-console-new feature/new-dashboard"
    echo "  $0 pull rahul"
    echo "  $0 logs rahul platform"
    echo "  $0 exec rahul platform php artisan migrate"
}

# Main command router
case "${1:-help}" in
    create)
        cmd_create "$2"
        ;;
    destroy)
        cmd_destroy "$2"
        ;;
    update-branch)
        cmd_update_branch "$2" "$3" "$4"
        ;;
    pull)
        cmd_pull "$2"
        ;;
    status)
        cmd_status "$2"
        ;;
    logs)
        cmd_logs "$2" "$3"
        ;;
    restart)
        cmd_restart "$2" "$3"
        ;;
    exec)
        cmd_exec "$2" "$3" "${@:4}"
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        log_error "Unknown command: $1"
        cmd_help
        exit 1
        ;;
esac

