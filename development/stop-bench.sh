#!/bin/bash
# Stop all Frappe bench processes
# This script kills bench serve, watch, schedule, worker, and related processes

set -u  # Exit on undefined variable
set -o pipefail  # Exit on pipe failure
# Note: Not using 'set -e' to allow graceful handling of kill command errors

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Source common logging functions if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/common.sh" ]; then
    source "$SCRIPT_DIR/common.sh"
else
    # Fallback logging functions
    log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
    log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
    log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
fi

log_info "Stopping Frappe bench processes..."

# Function to kill processes by pattern
kill_processes() {
    local pattern=$1
    local description=$2

    pids=$(pgrep -f "$pattern" 2>/dev/null || true)

    if [ -n "$pids" ]; then
        log_info "Stopping $description..."
        echo "$pids" | xargs kill -TERM 2>/dev/null || true
        sleep 0.5

        # Check if processes are still running, force kill if needed
        pids=$(pgrep -f "$pattern" 2>/dev/null || true)
        if [ -n "$pids" ]; then
            log_warn "Force killing $description..."
            echo "$pids" | xargs kill -9 2>/dev/null || true
        fi
    fi
}

# Function to kill processes by port
kill_port() {
    local port=$1

    # Use netstat to find PID using the port
    local pid=$(netstat -tlnp 2>/dev/null | grep ":$port " | awk '{print $7}' | cut -d'/' -f1 | head -1)

    if [ -n "$pid" ] && [ "$pid" != "-" ]; then
        log_info "Killing process $pid using port $port..."
        kill -TERM "$pid" 2>/dev/null || true
        sleep 0.5

        # Check if still running, force kill if needed
        if kill -0 "$pid" 2>/dev/null; then
            log_warn "Force killing process $pid on port $port..."
            kill -9 "$pid" 2>/dev/null || true
        fi
    fi
}

# Kill processes by pattern first
kill_processes "bench serve" "bench serve"
kill_processes "bench watch" "bench watch"
kill_processes "bench schedule" "bench schedule"
kill_processes "bench worker" "bench worker"
kill_processes "bench_helper frappe worker" "frappe worker"
kill_processes "bench_helper frappe schedule" "frappe schedule"
kill_processes "socketio.js" "socketio server"
kill_processes "esbuild.*watch" "esbuild watch"
kill_processes "yarn run watch" "yarn watch"

# Wait a moment for processes to terminate
sleep 1

# Kill any remaining processes using Frappe ports (8000-8005 for web, 9000-9005 for socketio)
log_info "Checking for processes using Frappe ports..."
for port in 8000 8001 8002 8003 8004 8005 9000 9001 9002 9003 9004 9005; do
    kill_port "$port"
done

# Wait a moment for port-based kills to complete
sleep 1

# Verify all processes are stopped
remaining=$(ps aux | grep -E "bench serve|bench watch|bench schedule|bench worker|bench_helper frappe|socketio.js|esbuild.*watch" | grep -v grep | wc -l)

# Check if any Frappe ports are still in use
ports_in_use=$(netstat -tlnp 2>/dev/null | grep -E ":(8000|8001|8002|8003|8004|8005|9000|9001|9002|9003|9004|9005) " | wc -l)

if [ "$remaining" -eq 0 ] && [ "$ports_in_use" -eq 0 ]; then
    log_info "✓ All bench processes stopped successfully"
    log_info "✓ All Frappe ports (8000-8005, 9000-9005) are now free"
else
    if [ "$remaining" -gt 0 ]; then
        log_warn "Some processes may still be running:"
        ps aux | grep -E "bench serve|bench watch|bench schedule|bench worker|bench_helper frappe|socketio.js|esbuild" | grep -v grep | head -5
    fi
    if [ "$ports_in_use" -gt 0 ]; then
        log_warn "Some Frappe ports are still in use:"
        netstat -tlnp 2>/dev/null | grep -E ":(8000|8001|8002|8003|8004|8005|9000|9001|9002|9003|9004|9005) "
    fi
fi
