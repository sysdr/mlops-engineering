#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
if [ -x "$SCRIPT_DIR/venv/bin/python" ]; then
  PYTHON_CMD="$SCRIPT_DIR/venv/bin/python"
else
  PYTHON_CMD="python3"
fi
# Seed metrics once, then start updater (refreshes all values every 1 sec)
"$PYTHON_CMD" "$SCRIPT_DIR/src/mlops_compass.py" --demo 2>/dev/null || true
DAY3_SCRIPT_DIR="$SCRIPT_DIR" nohup "$PYTHON_CMD" "$SCRIPT_DIR/metrics_updater.py" &> updater.log &
echo $! > updater.pid
sleep 0.5
DAY3_SCRIPT_DIR="$SCRIPT_DIR" DASHBOARD_PORT="5001" nohup "$PYTHON_CMD" "$SCRIPT_DIR/dashboard/dashboard.py" &> dashboard.log &
echo $! > dashboard.pid
echo "Started metrics updater and dashboard at http://localhost:5001"
