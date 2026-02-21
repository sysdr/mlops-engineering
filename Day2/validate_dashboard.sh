#!/bin/bash
# Validate dashboard metrics and check for duplicate services.
# Run after setup.sh has started the demo (or after at least one monitor iteration).
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

API_PORT="${API_PORT:-5000}"
FAIL=0

echo "=== Validating MLOps Day2 Demo ==="

# 1. Check metrics.json exists and has non-zero/updated values
if [ -f "metrics.json" ]; then
    echo "1. Checking metrics.json..."
    it=$(python3 -c "import json; m=json.load(open('metrics.json')); print(m.get('iteration', 0))" 2>/dev/null || echo "0")
    acc=$(python3 -c "import json; m=json.load(open('metrics.json')); print(m.get('accuracy', 0))" 2>/dev/null || echo "0")
    preds=$(python3 -c "import json; m=json.load(open('metrics.json')); print(m.get('total_predictions', 0))" 2>/dev/null || echo "0")
    if [ "${it:-0}" -gt 0 ] && python3 -c "exit(0 if float('${acc:-0}') > 0 else 1)" 2>/dev/null && [ "${preds:-0}" -gt 0 ]; then
        echo "   OK - Iteration=$it, Accuracy=$acc, Total predictions=$preds (dashboard values updated by demo)"
    else
        echo "   WARN - Metrics exist but values may be zero. Run demo and wait for at least one monitor check."
        [ "${it:-0}" -gt 0 ] || echo "   iteration is 0"
        [ "${preds:-0}" -gt 0 ] || echo "   total_predictions is 0"
    fi
else
    echo "1. metrics.json not found - start the demo (./setup.sh) and wait for first monitor iteration."
    FAIL=1
fi

# 2. Check only one process listening on API port
echo "2. Checking for duplicate services on port $API_PORT..."
count=$(lsof -i :$API_PORT 2>/dev/null | grep -c LISTEN || true)
count=$((count + 0))
if [ "$count" -eq 1 ]; then
    echo "   OK - Single service on port $API_PORT"
elif [ "$count" -gt 1 ]; then
    echo "   FAIL - Multiple processes on port $API_PORT. Run ./stop.sh and start again."
    FAIL=1
else
    echo "   INFO - No service on port $API_PORT (demo may be stopped)"
fi

# 3. Quick API test
if [ "$count" -ge 1 ]; then
    echo "3. Testing /predict endpoint..."
    if curl -sf -X POST -H "Content-Type: application/json" -d '{"features":[[1.0,0.5]]}' "http://localhost:$API_PORT/predict" | grep -q '"predictions"'; then
        echo "   OK - API responded with predictions"
    else
        echo "   FAIL - API did not return predictions"
        FAIL=1
    fi
fi

[ $FAIL -eq 0 ] && echo "=== Validation done ===" || { echo "=== Validation had warnings/failures ==="; exit $FAIL; }
