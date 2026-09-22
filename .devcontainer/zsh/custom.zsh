# Shortcuts for Frappe development. Sourced from ~/.zshrc by the Dockerfile.

DEV_DIR="/workspace/development"
BENCH_DIR="$DEV_DIR/frappe-bench"

# Navigation
alias godev="cd $DEV_DIR"
alias gobench="cd $BENCH_DIR"
alias goapps="cd $BENCH_DIR/apps"
alias gosites="cd $BENCH_DIR/sites"

# Bench lifecycle. Each one is the script of the same name in development/, so
# the alias and the script never say different things.
alias frstart="$DEV_DIR/start.sh"
alias frstop="$DEV_DIR/stop-bench.sh"
alias frmigrate="$DEV_DIR/migrate-site.sh"
alias frconsole="$DEV_DIR/console.sh"
alias frdb="$DEV_DIR/db-console.sh"
alias frcache="$DEV_DIR/clear-cache.sh"
alias frbuild="$DEV_DIR/build.sh"
alias frwatch="$DEV_DIR/watch.sh"
alias frapps="$DEV_DIR/get-apps.sh"
alias frstatus="$DEV_DIR/repo-status.sh"

# Git
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline -10'
alias gp='git pull'

alias logs="tail -f $BENCH_DIR/logs/bench-start.log"
alias bat='batcat'
