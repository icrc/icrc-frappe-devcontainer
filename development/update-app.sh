#!/bin/bash
# Switch a Frappe app to a specific tag/branch
# Works around `bench switch-to-branch` failing on tags by doing the git
# checkout directly, then installing dependencies, migrating, and rebuilding.

set -e  # Exit on error
set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Configuration
NEW_VERSION="${1:-}"
APP_NAME="${2:-}"

# Usage info
usage() {
    echo "Usage: $0 <version> <app>"
    echo ""
    echo "Examples:"
    echo "  $0 v2.8.10 raven        # Switch raven to tag v2.8.10"
    echo "  $0 v1.5.0  hrms         # Switch hrms to tag v1.5.0"
    echo "  $0 develop raven        # Switch raven to develop branch"
    exit 1
}

# Validate arguments
if [ -z "$NEW_VERSION" ] || [ -z "$APP_NAME" ]; then
    log_error "Both version and app name are required"
    usage
fi

APP_DIR="$BENCH_DIR/apps/$APP_NAME"

if [ ! -d "$APP_DIR" ]; then
    error_exit "App directory not found: $APP_DIR"
fi

log_info "========================================="
log_info "Updating $APP_NAME to: $NEW_VERSION"
log_info "========================================="

# Step 1: Get current version
cd "$APP_DIR"
CURRENT_VERSION=$(git describe --tags --exact-match 2>/dev/null || git rev-parse --abbrev-ref HEAD)
log_info "Current version: $CURRENT_VERSION"

if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
    log_info "Already on version $NEW_VERSION. Nothing to do."
    exit 0
fi

# Step 2: Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    log_error "You have uncommitted changes in $APP_NAME:"
    git status --short
    read -p "Stash changes and continue? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Stashing changes..."
        git stash push -m "Auto-stash before switching to $NEW_VERSION"
    else
        error_exit "Please commit or stash your changes before switching versions"
    fi
fi

# Step 3: Fetch latest tags and branches
log_info "Fetching latest from remote..."
if ! git fetch --all --tags; then
    error_exit "Failed to fetch from remote"
fi

# Step 4: Checkout the new version
log_info "Checking out $NEW_VERSION..."
if ! git checkout "$NEW_VERSION"; then
    error_exit "Failed to checkout $NEW_VERSION. Make sure the tag/branch exists."
fi

# Pull latest if it's a branch (not a tag)
if git show-ref --verify --quiet "refs/heads/$NEW_VERSION"; then
    log_info "Pulling latest changes from branch $NEW_VERSION..."
    git pull origin "$NEW_VERSION" || log_warn "Failed to pull latest changes (continuing)"
fi

NEW_CURRENT=$(git describe --tags --exact-match 2>/dev/null || git rev-parse --abbrev-ref HEAD)
log_info "Switched to: $NEW_CURRENT"

# Step 5: Install/update Python dependencies
cd "$BENCH_DIR"
log_info "Installing/updating Python dependencies..."
if ! ./env/bin/pip install -q -U -e "apps/$APP_NAME"; then
    log_warn "Failed to update Python dependencies (continuing)"
fi

# Step 6: Install Node dependencies if package.json exists
if [ -f "$APP_DIR/package.json" ]; then
    log_info "Installing Node dependencies..."
    (cd "$APP_DIR" && yarn install --silent 2>/dev/null) || log_warn "Failed to install Node dependencies (continuing)"
fi

# Step 7: Migrate sites
log_info "Migrating sites..."
SITES=$(ls -d sites/*/ 2>/dev/null | grep -v "sites/assets" | sed 's|sites/||g' | sed 's|/$||g' || true)

if [ -z "$SITES" ]; then
    log_warn "No sites found"
else
    for site in $SITES; do
        log_info "Migrating site: $site"
        if bench --site "$site" migrate; then
            log_info "Successfully migrated: $site"
        else
            log_error "Failed to migrate: $site"
        fi
    done
fi

# Step 8: Clear cache
log_info "Clearing cache..."
bench --site all clear-cache 2>/dev/null || log_warn "Failed to clear cache (continuing)"

# Step 9: Build assets
log_info "Building assets..."
if bench build --app "$APP_NAME"; then
    log_info "Assets built successfully"
else
    log_warn "Asset build failed. Run 'bench build' manually."
fi

# Summary
log_info "========================================="
log_info "Updated $APP_NAME: $CURRENT_VERSION -> $NEW_CURRENT"
log_info "========================================="
