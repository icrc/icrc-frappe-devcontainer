#!/bin/bash
# =============================================================================
# Create the bench, install the declared apps, and point it at the services.
#
# Run once after the container is first created. Everything project-specific
# lives in apps.json, not here.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
    cat <<'EOF'
Usage: install-bench.sh [VERSION]

Initialise frappe-bench, install the apps from apps.json, and configure it for
the MariaDB and Redis services in docker-compose.yml.

  VERSION   the Frappe branch or tag, e.g. v16.16.0 or version-16.
            Defaults to FRAPPE_VERSION from .devcontainer/.env
  -h        show this help

An existing bench is not touched: the script asks before removing it. To add
an app to a bench that already exists, edit apps.json and run get-apps.sh.

Exit status: 0 on success, 1 on a bad argument or a refusal, 2 on failure.
EOF
}

case "${1:-}" in
-h | --help)
    usage
    exit 0
    ;;
esac

FRAPPE_VERSION="${1:-${FRAPPE_VERSION:-v16.16.0}}"

log_info "Installing a Frappe bench (version $FRAPPE_VERSION)"

if [[ -d $BENCH_DIR ]]; then
    log_error "A bench already exists at $BENCH_DIR."
    log_warn "Removing it deletes every site and database in it."
    read -p "Remove and reinstall? (yes/no): " -r
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        rm -rf "$BENCH_DIR" || error_exit "Failed to remove $BENCH_DIR"
    else
        log_info "Nothing done. To add apps to the existing bench, run get-apps.sh."
        exit 1
    fi
fi

cd "$DEV_DIR"

log_info "Initialising the bench..."
bench init --skip-redis-config-generation --frappe-branch="$FRAPPE_VERSION" frappe-bench ||
    error_exit "bench init failed"

log_info "Installing the apps from apps.json..."
"$SCRIPT_DIR/get-apps.sh" || error_exit "Some apps could not be installed. Fix apps.json and re-run get-apps.sh."

"$SCRIPT_DIR/configure-bench.sh" || error_exit "Failed to configure the bench"

log_info "========================================="
log_info "Bench installed at $BENCH_DIR"
log_info "Frappe: $FRAPPE_VERSION"
log_info "Apps:   $(ls "$BENCH_DIR/apps" | tr '\n' ' ')"
log_info "========================================="
log_info "Next: ./create-site.sh dev.localhost, then ./start.sh"
