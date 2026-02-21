#!/bin/bash

# --- Configuration ---
PYTHON_VERSION="3.9" # Or your preferred Python version
VENV_DIR="venv"
API_PORT=5000
DASHBOARD_PORT=5001
MONITOR_INTERVAL=5 # seconds
DRIFT_ITERATIONS=3 # After this many checks, data drift starts

# --- Colors for console output ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

echo -e "${GREEN}### MLOps Day 2: Non-Deterministic Systems Demo ###${NC}"

# --- Generate stop.sh (always refresh so it includes dashboard when present) ---
echo -e "${YELLOW}Generating stop.sh...${NC}"
cat << 'STOPEOF' > stop.sh
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || true
[ -f api.pid ] && kill "$(cat api.pid)" 2>/dev/null || true
[ -f monitor.pid ] && kill "$(cat monitor.pid)" 2>/dev/null || true
[ -f dashboard.pid ] && kill "$(cat dashboard.pid)" 2>/dev/null || true
pkill -f "flask run.*5000" 2>/dev/null || true
pkill -f "monitor/monitor.py" 2>/dev/null || true
pkill -f "dashboard/dashboard.py" 2>/dev/null || true
rm -f api.pid monitor.pid dashboard.pid
echo "Stopped API, Monitor and Dashboard."
STOPEOF
chmod +x stop.sh

# --- Cleanup previous run (if any) ---
echo -e "${YELLOW}Cleaning up previous run...${NC}"
./stop.sh > /dev/null 2>&1

# --- Trap for cleanup on exit/interrupt ---
trap './stop.sh; echo -e "\n${RED}Demo stopped.${NC}"' EXIT INT TERM

# --- Check for Docker ---
if command -v docker &> /dev/null && command -v docker-compose &> /dev/null; then
    echo -e "${GREEN}Docker and Docker Compose found. Offering Docker option.${NC}"
    USE_DOCKER="false"
    read -p "Do you want to run with Docker? (y/N): " docker_choice
    if [[ "$docker_choice" =~ ^[Yy]$ ]]; then
        USE_DOCKER="true"
    fi
else
    echo -e "${YELLOW}Docker or Docker Compose not found. Running natively.${NC}"
    USE_DOCKER="false"
fi

# --- Helper function for console dashboard ---
function display_dashboard() {
    echo -e "\n${GREEN}--- MLOps Demo Dashboard ---${NC}"
    echo -e "${YELLOW}Dashboard: http://localhost:${DASHBOARD_PORT}${NC}"
    echo -e "${YELLOW}API Service: http://localhost:${API_PORT}/predict${NC}"
    echo -e "${YELLOW}Monitor Log: monitor.log | API Log: api.log | Metrics: metrics.json${NC}"
    if [ -f "metrics.json" ]; then
        echo -e "${GREEN}Current metrics (updated by monitor):${NC}"
        python3 -c "
import json, sys
try:
    with open('metrics.json') as f: m = json.load(f)
    it = m.get('iteration', 0)
    acc = m.get('accuracy', 0)
    preds = m.get('total_predictions', 0)
    print('  Iteration:', it)
    print('  Accuracy:', '{:.2f}%'.format(100 * acc))
    print('  Drift active:', m.get('drift_active', False))
    print('  Total predictions:', preds)
    if it == 0 and acc == 0 and preds == 0:
        print('  (Run demo: monitor will update these values)', file=sys.stderr)
except Exception: print('  (waiting for first monitor update)', file=sys.stderr)
" 2>/dev/null || true
    else
        echo -e "${YELLOW}Metrics will appear after first monitor check.${NC}"
    fi
    if [ "$USE_DOCKER" == "true" ]; then
        echo -e "${YELLOW}Docker Containers: mlops-day2-api, mlops-day2-monitor${NC}"
    fi
    echo -e "${GREEN}----------------------------${NC}"
    echo -e "Monitor output will appear below:"
    tail -f monitor.log &
    TAIL_PID=$!
}

if [ "$USE_DOCKER" == "true" ]; then
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${YELLOW}docker-compose.yml not found. Running natively.${NC}"
        USE_DOCKER="false"
    fi
fi

if [ "$USE_DOCKER" == "true" ]; then
    echo -e "${GREEN}Building Docker images and starting containers...${NC}"
    # Create necessary directories for Docker bind mounts
    mkdir -p app monitor

    # Generate initial model before Docker build (or ensure Dockerfile handles it)
    echo -e "${YELLOW}Generating initial model for Docker...${NC}"
    python3 -c "from sklearn.datasets import make_classification; from sklearn.linear_model import LogisticRegression; import joblib; X, y = make_classification(n_samples=1000, n_features=2, n_informative=2, n_redundant=0, random_state=42); model = LogisticRegression(random_state=42); model.fit(X, y); joblib.dump(model, 'app/model.pkl'); print('Model trained and saved to app/model.pkl')" 2>/dev/null || true

    # Create dummy files if they don't exist, Docker compose needs them for context
    touch app/requirements.txt
    touch app/api.py
    touch monitor/requirements.txt
    touch monitor/monitor.py

    # Build and run Docker containers
    docker-compose -f docker-compose.yml up --build -d

    # Give containers a moment to start
    sleep 5

    display_dashboard

    echo -e "\n${GREEN}--- Dockerized MLOps Demo Started ---${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop.${NC}"
    wait $TAIL_PID # Wait for the tail process, allowing Ctrl+C to trigger trap

else # Native execution
    echo -e "${GREEN}Running natively...${NC}"

    # --- Create project structure ---
    echo -e "${YELLOW}Creating project directories...${NC}"
    mkdir -p app monitor dashboard/templates

    # --- Setup Python virtual environment (or use system Python) ---
    PYTHON_CMD=""
    PIP_CMD=""
    if command -v "python${PYTHON_VERSION}" &>/dev/null && "python${PYTHON_VERSION}" -m venv "$VENV_DIR" 2>/dev/null; then
        source "$VENV_DIR/bin/activate"
        PYTHON_CMD="$SCRIPT_DIR/venv/bin/python"
        PIP_CMD="pip"
    elif python3 -m venv "$VENV_DIR" 2>/dev/null; then
        source "$VENV_DIR/bin/activate"
        PYTHON_CMD="$SCRIPT_DIR/venv/bin/python"
        PIP_CMD="pip"
    else
        echo -e "${YELLOW}Virtual env not available (install python3-venv for venv). Using system Python.${NC}"
        PYTHON_CMD="python3"
        if python3 -m pip --version &>/dev/null; then
            PIP_CMD="python3 -m pip"
        elif python3 -m ensurepip --user &>/dev/null && python3 -m pip --version &>/dev/null; then
            PIP_CMD="python3 -m pip"
        else
            echo -e "${RED}pip not available. Install python3-venv (apt install python3-venv) or python3-pip.${NC}"
            exit 1
        fi
    fi

    # --- Generate requirements files ---
    echo -e "${YELLOW}Generating requirements files...${NC}"
    echo "Flask" > app/requirements.txt
    echo "scikit-learn" >> app/requirements.txt
    echo "numpy" >> app/requirements.txt
    echo "joblib" >> app/requirements.txt

    echo "requests" > monitor/requirements.txt
    echo "numpy" >> monitor/requirements.txt
    echo "scikit-learn" >> monitor/requirements.txt # For make_classification in monitor

    # --- Install dependencies ---
    echo -e "${YELLOW}Installing dependencies...${NC}"
    $PIP_CMD install -q -r app/requirements.txt || { echo -e "${RED}Error: Failed to install app dependencies. Install python3-venv (apt install python3-venv) or ensure pip is available.${NC}"; exit 1; }
    $PIP_CMD install -q -r monitor/requirements.txt || { echo -e "${RED}Error: Failed to install monitor dependencies.${NC}"; exit 1; }

    # --- Generate API source code ---
    echo -e "${YELLOW}Generating API source code (app/api.py)...${NC}"
    cat <<EOF > app/api.py
from flask import Flask, request, jsonify
import joblib
import numpy as np
import os

app = Flask(__name__)
MODEL_PATH = os.environ.get('MODEL_PATH', 'app/model.pkl')

try:
    model = joblib.load(MODEL_PATH)
    print(f"API: Model loaded successfully from {MODEL_PATH}")
except Exception as e:
    print(f"API: Error loading model from {MODEL_PATH}: {e}")
    model = None # Handle case where model might not be available yet

@app.route('/predict', methods=['POST'])
def predict():
    if model is None:
        return jsonify({'error': 'Model not loaded'}), 500
    try:
        data = request.json.get('features')
        if not data:
            return jsonify({'error': 'No features provided'}), 400
        features = np.array(data)
        if features.ndim == 1: # Ensure 2D array for single sample
            features = features.reshape(1, -1)

        predictions = model.predict(features).tolist()
        probabilities = model.predict_proba(features).tolist()

        # For simplicity, let's return the max probability as confidence
        confidences = [max(p) for p in probabilities]

        return jsonify({'predictions': predictions, 'confidences': confidences})
    except Exception as e:
        print(f"API Error: {e}")
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=${API_PORT})
EOF

    # --- Generate Monitor source code ---
    echo -e "${YELLOW}Generating Monitor source code (monitor/monitor.py)...${NC}"
    cat <<EOF > monitor/monitor.py
import requests
import numpy as np
import time
import os
from sklearn.datasets import make_classification

API_URL = os.environ.get('API_URL', 'http://localhost:${API_PORT}/predict')
MONITOR_INTERVAL = int(os.environ.get('MONITOR_INTERVAL', '${MONITOR_INTERVAL}'))
DRIFT_ITERATIONS = int(os.environ.get('DRIFT_ITERATIONS', '${DRIFT_ITERATIONS}'))
ACCURACY_THRESHOLD = float(os.environ.get('ACCURACY_THRESHOLD', '0.90')) # 90%
N_SAMPLES_PER_CHECK = 50
METRICS_FILE = os.environ.get('METRICS_FILE', 'metrics.json')

# --- Colors for console output ---
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

def generate_data(drift_active=False):
    # Base data generation (consistent with training)
    X, _ = make_classification(n_samples=N_SAMPLES_PER_CHECK, n_features=2, n_informative=2, n_redundant=0, random_state=int(time.time()))

    if drift_active:
        # Simulate data drift by shifting one feature's distribution
        # This will make the original model perform worse
        X[:, 0] = X[:, 0] + 2.0 # Shift feature 0 significantly
        print(f"[{time.strftime('%H:%M:%S')}] {RED}Monitor: Simulating data drift...{NC}")
    return X.tolist()

def get_simulated_accuracy(confidences, drift_active):
    # In a real system, you'd compare predictions to ground truth labels.
    # Here, we simulate accuracy based on whether drift is active.
    # Higher average confidence might indicate better performance, but it's not a direct accuracy.
    # For this demo, we'll hardcode a simulated accuracy drop.
    if drift_active:
        # When drift is active, simulate a lower accuracy
        return np.random.uniform(0.75, 0.85) # e.g., 75-85%
    else:
        # When no drift, simulate high accuracy
        return np.random.uniform(0.92, 0.98) # e.g., 92-98%

def run_monitor():
    print(f"{GREEN}--- MLOps Model Monitor Started ---{NC}")
    print(f"{YELLOW}API URL: {API_URL}{NC}")
    print(f"{YELLOW}Check Interval: {MONITOR_INTERVAL}s{NC}")
    print(f"{YELLOW}Drift after: {DRIFT_ITERATIONS} iterations{NC}")
    print(f"{YELLOW}Accuracy Threshold: {ACCURACY_THRESHOLD*100:.0f}%{NC}")
    print(f"{GREEN}-----------------------------------{NC}")

    iteration = 0
    total_predictions = 0
    while True:
        iteration += 1
        drift_active = (iteration > DRIFT_ITERATIONS)
        print(f"\n[{time.strftime('%H:%M:%S')}] {YELLOW}Monitor: Checking model performance (Iteration {iteration})...{NC}")

        try:
            data_to_send = generate_data(drift_active=drift_active)
            response = requests.post(API_URL, json={'features': data_to_send})
            response.raise_for_status() # Raise an exception for HTTP errors (4xx or 5xx)
            result = response.json()

            # We're not using actual ground truth, so confidences are proxies.
            # For this demo, the simulated_accuracy function handles the logic.
            # In a real system, you'd log predictions and later compare with true labels.
            # For now, let's just use the simulated accuracy based on drift state.
            sim_accuracy = get_simulated_accuracy(result.get('confidences', []), drift_active)
            num_preds = len(result.get('predictions', []))
            total_predictions += num_preds

            print(f"[{time.strftime('%H:%M:%S')}] Monitor: Received {len(result['predictions'])} predictions from API.")
            print(f"[{time.strftime('%H:%M:%S')}] Monitor: Current simulated model accuracy: {sim_accuracy*100:.2f}% (Threshold: {ACCURACY_THRESHOLD*100:.0f}%)")

            if sim_accuracy < ACCURACY_THRESHOLD:
                print(f"[{time.strftime('%H:%M:%S')}] {RED}Monitor: Model Performance DEGRADED! Triggering Retraining Process...{NC}")
                # In a real MLOps pipeline, this would trigger an external retraining job
                # e.g., via a message queue, API call to a CI/CD system, or a workflow orchestrator.
                # For this demo, we just print the message.
            else:
                print(f"[{time.strftime('%H:%M:%S')}] {GREEN}Monitor: Model performance is OK.{NC}")

        except requests.exceptions.ConnectionError:
            print(f"[{time.strftime('%H:%M:%S')}] {RED}Monitor: Error: Could not connect to API at {API_URL}. Is it running?{NC}")
        except requests.exceptions.RequestException as e:
            print(f"[{time.strftime('%H:%M:%S')}] {RED}Monitor: Error during API request: {e}{NC}")
        except Exception as e:
            print(f"[{time.strftime('%H:%M:%S')}] {RED}Monitor: An unexpected error occurred: {e}{NC}")

        time.sleep(MONITOR_INTERVAL)

if __name__ == '__main__':
    run_monitor()
EOF

    # --- Generate test script ---
    echo -e "${YELLOW}Generating run_tests.sh...${NC}"
    cat << 'TESTEOF' > run_tests.sh
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
API="${API_URL:-http://localhost:5000}"
echo "Testing API at $API/predict ..."
resp=$(curl -sf -X POST -H "Content-Type: application/json" -d '{"features":[[1.0, 0.5], [-0.5, 2.0]]}' "$API/predict")
echo "$resp" | grep -q '"predictions"' || { echo "FAIL: no predictions in response"; exit 1; }
echo "$resp" | grep -q '"confidences"' || { echo "FAIL: no confidences in response"; exit 1; }
echo "Tests passed. Response: $resp"
TESTEOF
    chmod +x run_tests.sh

    # --- Generate start_app.sh (API + Monitor only, for restart from dashboard) ---
    echo -e "${YELLOW}Generating start_app.sh...${NC}"
    cat << STARTOEOF > start_app.sh
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
cd "\$SCRIPT_DIR" || exit 1
API_PORT=${API_PORT}
if [ -x "\$SCRIPT_DIR/venv/bin/python" ]; then
  PYTHON_CMD="\$SCRIPT_DIR/venv/bin/python"
else
  PYTHON_CMD="python3"
fi
( cd "\$SCRIPT_DIR" && FLASK_APP=app.api nohup "\$PYTHON_CMD" -m flask run --host 0.0.0.0 --port \$API_PORT &> api.log ) &
echo \$! > "\$SCRIPT_DIR/api.pid"
sleep 2
( cd "\$SCRIPT_DIR" && nohup "\$PYTHON_CMD" "\$SCRIPT_DIR/monitor/monitor.py" &> monitor.log ) &
echo \$! > "\$SCRIPT_DIR/monitor.pid"
echo "Started API and Monitor."
STARTOEOF
    chmod +x start_app.sh

    # --- Generate stop_app.sh (API + Monitor only; dashboard uses this for Restart so it does not kill itself) ---
    echo -e "${YELLOW}Generating stop_app.sh...${NC}"
    cat << 'STOPAPPEOF' > stop_app.sh
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || true
[ -f api.pid ] && kill "$(cat api.pid)" 2>/dev/null || true
[ -f monitor.pid ] && kill "$(cat monitor.pid)" 2>/dev/null || true
pkill -f "flask run.*5000" 2>/dev/null || true
pkill -f "monitor/monitor.py" 2>/dev/null || true
rm -f api.pid monitor.pid
echo "Stopped API and Monitor (dashboard unchanged)."
STOPAPPEOF
    chmod +x stop_app.sh

    # --- Train initial model ---
    echo -e "${YELLOW}Training initial model (app/model.pkl)...${NC}"
    $PYTHON_CMD -c "from sklearn.datasets import make_classification; from sklearn.linear_model import LogisticRegression; import joblib; X, y = make_classification(n_samples=1000, n_features=2, n_informative=2, n_redundant=0, random_state=42); model = LogisticRegression(random_state=42); model.fit(X, y); joblib.dump(model, 'app/model.pkl'); print('Model trained and saved to app/model.pkl')"

    # --- Ensure no duplicate services on API port ---
    if command -v lsof &>/dev/null && lsof -i :${API_PORT} &>/dev/null; then
        echo -e "${YELLOW}Port ${API_PORT} in use. Stopping existing services...${NC}"
        ./stop.sh 2>/dev/null || true
        sleep 2
    fi

    # --- Start API in background (full path, from SCRIPT_DIR) ---
    echo -e "${YELLOW}Starting Flask API in background... (logs to api.log)${NC}"
    ( cd "$SCRIPT_DIR" && FLASK_APP=app.api nohup "$PYTHON_CMD" -m flask run --host 0.0.0.0 --port ${API_PORT} &> api.log ) &
    API_PID=$!
    echo "$API_PID" > "$SCRIPT_DIR/api.pid"
    sleep 3 # Give API a moment to start

    # --- Start Monitor in background (full path) ---
    echo -e "${YELLOW}Starting MLOps Monitor in background... (logs to monitor.log)${NC}"
    ( cd "$SCRIPT_DIR" && nohup "$PYTHON_CMD" "$SCRIPT_DIR/monitor/monitor.py" &> monitor.log ) &
    MONITOR_PID=$!
    echo "$MONITOR_PID" > "$SCRIPT_DIR/monitor.pid"
    sleep 1 # Give monitor a moment to start

    # --- Start Dashboard (web UI with metrics and restart) ---
    if [ -f "$SCRIPT_DIR/dashboard/dashboard.py" ]; then
        echo -e "${YELLOW}Starting Dashboard... (http://localhost:${DASHBOARD_PORT})${NC}"
        ( cd "$SCRIPT_DIR" && DAY2_SCRIPT_DIR="$SCRIPT_DIR" API_PORT=${API_PORT} DASHBOARD_PORT=${DASHBOARD_PORT} nohup "$PYTHON_CMD" "$SCRIPT_DIR/dashboard/dashboard.py" &> dashboard.log ) &
        DASH_PID=$!
        echo "$DASH_PID" > "$SCRIPT_DIR/dashboard.pid"
        sleep 1
    fi

    # --- Run tests to verify API and populate metrics ---
    if [ -f "$SCRIPT_DIR/run_tests.sh" ]; then
        echo -e "${YELLOW}Running tests...${NC}"
        ( cd "$SCRIPT_DIR" && ./run_tests.sh ) || true
    fi
    sleep 2 # Allow monitor to run one check and write metrics

    display_dashboard

    echo -e "\n${GREEN}--- Native MLOps Demo Started ---${NC}"
    echo -e "${YELLOW}Dashboard (metrics + restart): http://localhost:${DASHBOARD_PORT}${NC}"
    echo -e "${YELLOW}To manually test the API:${NC}"
    echo -e "  ${YELLOW}curl -X POST -H "Content-Type: application/json" -d '{"features":[[1.0, 0.5]]}' http://localhost:${API_PORT}/predict${NC}"
    echo -e "  ${YELLOW}curl -X POST -H "Content-Type: application/json" -d '{"features":[[1.0, 0.5], [-0.5, 2.0]]}' http://localhost:${API_PORT}/predict${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop.${NC}"
    wait $TAIL_PID # Wait for the tail process, allowing Ctrl+C to trigger trap
fi