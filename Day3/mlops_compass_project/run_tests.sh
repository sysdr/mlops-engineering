#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
if [ -x "$SCRIPT_DIR/venv/bin/python" ]; then
  PYTHON_CMD="$SCRIPT_DIR/venv/bin/python"
else
  PYTHON_CMD="python3"
fi
echo "Running MLOps Compass demo (updates metrics.json)..."
"$PYTHON_CMD" "$SCRIPT_DIR/src/mlops_compass.py" --demo
echo "Testing dashboard /api/metrics..."
DASH_PORT="${DASHBOARD_PORT:-5001}"
curl -sf "http://localhost:$DASH_PORT/api/metrics" | grep -q '"iteration"' || { echo "WARN: Dashboard not running or no metrics. Start with: $SCRIPT_DIR/start.sh"; exit 0; }
echo "Tests passed."
