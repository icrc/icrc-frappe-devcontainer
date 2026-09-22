#!/bin/bash
# =============================================================================
# Move the bench to another Frappe version, end to end.
#
# Records the new version in .devcontainer/.env, so install-bench.sh agrees
# with the installed bench without this script having to rewrite it.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
    cat <<'EOF'
Usage: switch-frappe-version.sh VERSION

Check out VERSION in apps/frappe, update the Python dependencies, migrate
every site and offer to rebuild the assets. VERSION is a tag or a branch,
e.g. v16.16.0, version-16, develop.

FRAPPE_VERSION in .devcontainer/.env is updated too, so a later
install-bench.sh builds the same version.

Exit status: 0 on success, 1 on a bad argument, 2 on failure.
EOF
}

NEW_VERSION="${1:-}"
case "$NEW_VERSION" in
"" | -h | --help)
    usage
    [[ -n $NEW_VERSION ]] && exit 0 || exit 1
    ;;
esac

require_bench
FRAPPE_APP_DIR="$BENCH_DIR/apps/frappe"
[[ -d $FRAPPE_APP_DIR ]] || error_exit "No frappe app at $FRAPPE_APP_DIR"

log_info "Switching Frappe to $NEW_VERSION"

cd "$FRAPPE_APP_DIR"
CURRENT_VERSION="$(git describe --tags --exact-match 2>/dev/null || git rev-parse --abbrev-ref HEAD)"
log_info "Currently on $CURRENT_VERSION"
if [[ $CURRENT_VERSION == "$NEW_VERSION" ]]; then
    log_info "Already there. Nothing to do."
    exit 0
fi

if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    log_error "apps/frappe has uncommitted changes:"
    git status --short
    read -p "Stash them and continue? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        git stash push -m "before switching to $NEW_VERSION"
    else
        error_exit "Commit or stash them first."
    fi
fi

git fetch --all --tags || error_exit "Fetch failed"
git checkout "$NEW_VERSION" || error_exit "No such tag or branch: $NEW_VERSION"
if git show-ref --verify --quiet "refs/heads/$NEW_VERSION"; then
    git pull origin "$NEW_VERSION" || log_warn "Could not pull, continuing."
fi
NEW_CURRENT="$(git describe --tags --exact-match 2>/dev/null || git rev-parse --abbrev-ref HEAD)"
log_info "Now on $NEW_CURRENT"

cd "$BENCH_DIR"
log_info "Updating the Python dependencies..."
./env/bin/pip install -q -U -e apps/frappe || log_warn "Dependency update failed, continuing."

# One migration per site, reported individually: a failure on one site is not
# a reason to skip the others, and it is the thing to fix by hand.
mapfile -t SITES < <(ls -d sites/*/ 2>/dev/null | grep -v "sites/assets" | sed 's|sites/||;s|/$||' || true)
if [[ ${#SITES[@]} -eq 0 ]]; then
    log_warn "No sites to migrate. Create one with create-site.sh."
else
    for site in "${SITES[@]}"; do
        log_info "Migrating $site..."
        bench --site "$site" migrate || log_error "  $site failed to migrate, fix it by hand."
    done
    bench --site all clear-cache 2>/dev/null || log_warn "Could not clear the cache."
fi

# The new version is what a fresh install should build from now on.
if [[ -f $ENV_FILE ]]; then
    if grep -q '^FRAPPE_VERSION=' "$ENV_FILE"; then
        sed -i "s|^FRAPPE_VERSION=.*|FRAPPE_VERSION=$NEW_VERSION|" "$ENV_FILE"
    else
        echo "FRAPPE_VERSION=$NEW_VERSION" >>"$ENV_FILE"
    fi
    log_info "FRAPPE_VERSION in .devcontainer/.env is now $NEW_VERSION"
fi

read -p "Rebuild the assets now? It takes a few minutes. (yes/no): " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    bench build || log_warn "Build failed. Run ./build.sh when ready."
fi

log_info "========================================="
log_info "Was: $CURRENT_VERSION"
log_info "Now: $NEW_CURRENT"
log_info "Sites migrated: ${#SITES[@]}"
log_info "========================================="
log_info "To go back: ./switch-frappe-version.sh $CURRENT_VERSION"
