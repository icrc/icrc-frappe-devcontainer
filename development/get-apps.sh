#!/bin/bash
# =============================================================================
# Install into the bench every app declared in apps.json.
#
# The file is a JSON array of {url, branch}, the shape `bench init --apps_path`
# and frappe_docker's apps-example.json already use. Keeping it here rather
# than in the code is what makes this repository reusable: the apps are
# configuration, not part of the container.
#
# Why a script and not `bench init --apps_path`: bench honours that file only
# when it creates the bench, so an app added afterwards never lands without
# rebuilding everything. This runs against an existing bench and skips what is
# already there.
#
# Any git host works, because nothing here authenticates: an https URL uses
# whatever the mounted ~/.gitconfig is configured for (a credential helper, an
# Azure DevOps extraheader), and an ssh URL uses the forwarded agent.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

APPS_FILE="${APPS_FILE:-$DEV_DIR/apps.json}"
LOCAL_APPS_FILE="${LOCAL_APPS_FILE:-$DEV_DIR/apps.local.json}"

usage() {
    cat <<'EOF'
Usage: get-apps.sh [--file PATH] [--dry-run]

Install every app declared in apps.json, and in apps.local.json when it
exists, into the bench. An app already present is reported and skipped, so the
script is safe to re-run after adding an entry.

  --file PATH   read this file instead of apps.json
  --dry-run     print what would be fetched and exit
  -h            show this help

apps.json is a JSON array:

  [ { "url": "https://github.com/frappe/erpnext.git", "branch": "version-16" } ]

apps.local.json has the same shape and is gitignored. Private apps belong
there, so a personal app list never turns into a commit.

Exit status: 0 when every app is present at the end, 1 on a bad argument or a
malformed file, 2 when an app could not be fetched.
EOF
}

dry_run=false
while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
        usage
        exit 0
        ;;
    --dry-run)
        dry_run=true
        shift
        ;;
    --file)
        [[ -n ${2:-} ]] || {
            usage >&2
            exit 1
        }
        APPS_FILE="$2"
        LOCAL_APPS_FILE=""
        shift 2
        ;;
    *)
        usage >&2
        exit 1
        ;;
    esac
done

command -v jq >/dev/null || error_exit "jq is not installed. It is in the Dockerfile, so rebuild the container."
require_bench

# Both files, concatenated. A local entry for an app already in apps.json is
# harmless: the first one wins, because the second finds the app present.
read_entries() {
    local file
    for file in "$APPS_FILE" "$LOCAL_APPS_FILE"; do
        [[ -n $file && -f $file ]] || continue
        jq -e 'type == "array"' "$file" >/dev/null 2>&1 ||
            error_exit "$file is not a JSON array of {url, branch}."
        jq -r '.[] | [.url, (.branch // "")] | @tsv' "$file"
    done
}

# bench names an app after its repository, minus any .git suffix. That is the
# directory it lands in, and so the thing to test for before fetching.
app_name_from_url() {
    local url="$1"
    url="${url%.git}"
    url="${url%/}"
    basename "$url"
}

entries="$(read_entries)"
[[ -n $entries ]] || {
    log_warn "No apps declared in $APPS_FILE."
    exit 0
}

cd "$BENCH_DIR"

failed=0
while IFS=$'\t' read -r url branch; do
    [[ -n $url ]] || continue
    app="$(app_name_from_url "$url")"

    if [[ -d "apps/$app" ]]; then
        log_info "$app is already in the bench, skipping."
        continue
    fi

    if [[ $dry_run == true ]]; then
        log_info "would fetch $app from $url${branch:+ (branch $branch)}"
        continue
    fi

    log_info "Fetching $app from $url${branch:+ (branch $branch)}..."
    if [[ -n $branch ]]; then
        bench get-app --branch "$branch" "$url" || failed=1
    else
        bench get-app "$url" || failed=1
    fi

    if [[ -d "apps/$app" ]]; then
        log_info "$app installed."
    else
        log_error "$app was not installed. Check the URL, the branch, and that"
        log_error "  your ~/.gitconfig or ssh agent can reach that host."
        failed=1
    fi
done <<<"$entries"

[[ $failed -eq 0 ]] || exit 2

log_info "Apps in the bench: $(ls apps | tr '\n' ' ')"
