#!/bin/bash
# Shared by every script in this directory. Sourced, never run.
#
# Holds the logging helpers, the three paths the scripts work from, and the
# generated secrets. The paths are derived from this file's own location, so
# nothing breaks when the repository is mounted somewhere other than
# /workspace.

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

error_exit() {
    log_error "$1"
    exit 1
}

DEV_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$DEV_DIR")"
BENCH_DIR="$DEV_DIR/frappe-bench"
ENV_FILE="$REPO_DIR/.devcontainer/.env"

# The secrets .devcontainer/init-env.sh generated on the host. Exported, so a
# bench command started from one of these scripts inherits them.
if [[ -f $ENV_FILE ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
fi

# Every service name below is a Compose service, not a host name to configure.
DB_HOST="${DB_HOST:-mariadb}"
DB_ROOT_USER="${DB_ROOT_USER:-root}"
S3_HOST="${S3_HOST:-http://seaweedfs:8333}"
S3_SIGV4="${S3_SIGV4:-aws:amz:us-east-1:s3}"

# Refuse early and clearly rather than letting bench fail three commands later.
require_bench() {
    [[ -d $BENCH_DIR ]] || error_exit "No bench at $BENCH_DIR. Run install-bench.sh first."
    [[ -f "$BENCH_DIR/sites/common_site_config.json" ]] ||
        error_exit "$BENCH_DIR is not a Frappe bench: no sites/common_site_config.json."
}

# The sites in the bench, one per line, assets excluded.
list_sites() {
    local dir
    for dir in "$BENCH_DIR"/sites/*/; do
        [[ -f "$dir/site_config.json" ]] && basename "$dir"
    done
}

require_secret() {
    local name="$1"
    [[ -n ${!name:-} ]] ||
        error_exit "$name is not set. Run: bash $REPO_DIR/.devcontainer/init-env.sh"
}
