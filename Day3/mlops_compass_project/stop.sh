#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || true
[ -f updater.pid ] && kill "$(cat updater.pid)" 2>/dev/null || true
[ -f dashboard.pid ] && kill "$(cat dashboard.pid)" 2>/dev/null || true
pkill -f "metrics_updater.py" 2>/dev/null || true
pkill -f "dashboard/dashboard.py" 2>/dev/null || true
rm -f updater.pid dashboard.pid
echo "Stopped metrics updater and dashboard."
