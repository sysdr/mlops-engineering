#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
DASH_PORT="${DASHBOARD_PORT:-5001}"
FAIL=0
echo "=== Validating MLOps Day3 Dashboard ==="
if [ -f "metrics.json" ]; then
  it=$(python3 -c "import json; m=json.load(open('metrics.json')); print(m.get('iteration', 0))" 2>/dev/null || echo "0")
  acc=$(python3 -c "import json; m=json.load(open('metrics.json')); print(m.get('accuracy', 0))" 2>/dev/null || echo "0")
  preds=$(python3 -c "import json; m=json.load(open('metrics.json')); print(m.get('total_predictions', 0))" 2>/dev/null || echo "0")
  if [ "${it:-0}" -gt 0 ] && [ "${preds:-0}" -gt 0 ]; then
    echo "   OK - Iteration=$it, Accuracy=$acc, Total questions=$preds"
  else
    echo "   WARN - Run demo first: $SCRIPT_DIR/venv/bin/python src/mlops_compass.py --demo"
    [ "${it:-0}" -gt 0 ] || echo "   iteration is 0"; [ "${preds:-0}" -gt 0 ] || echo "   total_predictions is 0"
    FAIL=1
  fi
else
  echo "   metrics.json not found. Run: python3 src/mlops_compass.py --demo"
  FAIL=1
fi
count=$(lsof -i :$DASH_PORT 2>/dev/null | grep -c LISTEN || true)
count=$((count + 0))
if [ "$count" -gt 1 ]; then
  echo "   FAIL - Multiple processes on port $DASH_PORT. Run ./stop.sh"; FAIL=1
elif [ "$count" -eq 1 ]; then
  echo "   OK - Single dashboard on port $DASH_PORT"
fi
[ $FAIL -eq 0 ] && echo "=== Validation done ===" || { echo "=== Validation had warnings ==="; exit $FAIL; }
