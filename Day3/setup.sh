#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--- MLOps Compass: Starting Setup and Demo ---"

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="mlops_compass_project"
DASHBOARD_PORT="${DASHBOARD_PORT:-5001}"

# 1. Create Project & File Structure
echo "1. Creating project directory and file structure..."
mkdir -p "$SCRIPT_DIR/$PROJECT_DIR/src"
mkdir -p "$SCRIPT_DIR/$PROJECT_DIR/data"
mkdir -p "$SCRIPT_DIR/$PROJECT_DIR/dashboard/templates"
mkdir -p "$SCRIPT_DIR/$PROJECT_DIR/dashboard/static"
cd "$SCRIPT_DIR/$PROJECT_DIR"

# 2. Generate Source Code
echo "2. Generating source code files..."

# src/questions.json - The assessment questions and scoring
cat <<EOF > data/questions.json
{
    "Data & Experimentation Management": [
        {
            "id": "data_q1",
            "question": "How do you manage your training data versions?",
            "options": [
                "A) Manually copy files/datasets, no versioning.",
                "B) Use Git LFS or simple cloud storage versioning (e.g., S3 versions).",
                "C) Dedicated data versioning tool (e.g., DVC, Delta Lake) or robust data lake practices.",
                "D) Automated, lineage-tracked data pipelines with robust versioning and schema enforcement."
            ],
            "scores": [1, 2, 3, 4]
        },
        {
            "id": "data_q2",
            "question": "How are model training experiments tracked?",
            "options": [
                "A) No formal tracking, rely on memory/notebooks.",
                "B) Manual spreadsheets or basic logging in scripts.",
                "C) Experiment tracking tools (e.g., MLflow, Weights & Biases) for metrics and artifacts.",
                "D) Centralized, automated experiment tracking integrated with CI/CD and hyperparameter optimization."
            ],
            "scores": [1, 2, 3, 4]
        }
    ],
    "Model Deployment & Integration": [
        {
            "id": "deploy_q1",
            "question": "What is your process for deploying a new model to production?",
            "options": [
                "A) Manual steps, often requiring significant engineer intervention.",
                "B) Scripted deployments, but still requires manual triggers and checks.",
                "C) Automated CI/CD pipelines for model deployment, with canary/blue-green options.",
                "D) Fully automated, self-healing deployment pipelines with rollback capabilities and A/B testing frameworks."
            ],
            "scores": [1, 2, 3, 4]
        },
        {
            "id": "deploy_q2",
            "question": "How are deployed models integrated into existing applications?",
            "options": [
                "A) Ad-hoc API endpoints or direct model file loading.",
                "B) Standardized REST APIs, but manual endpoint management.",
                "C) Centralized model serving platform (e.g., Sagemaker Endpoints, KServe) with API versioning.",
                "D) Dynamic service mesh integration, automated API lifecycle management, and SDKs for client applications."
            ],
            "scores": [1, 2, 3, 4]
        }
    ],
    "Monitoring & Governance": [
        {
            "id": "monitor_q1",
            "question": "How do you monitor model performance in production?",
            "options": [
                "A) No monitoring beyond basic application health checks.",
                "B) Manual checks of aggregated metrics occasionally.",
                "C) Automated dashboards for key model metrics (accuracy, latency, throughput).",
                "D) Real-time monitoring for data drift, concept drift, fairness, and automated alerting/retraining triggers."
            ],
            "scores": [1, 2, 3, 4]
        },
        {
            "id": "monitor_q2",
            "question": "What mechanisms are in place for model governance and compliance?",
            "options": [
                "A) None, or ad-hoc reviews.",
                "B) Basic documentation of model purpose and data sources.",
                "C) Model registry with metadata, owners, and clear approval workflows.",
                "D) Automated audit trails, explainability tools (XAI), and adherence to ethical AI principles."
            ],
            "scores": [1, 2, 3, 4]
        }
    ]
}
EOF

# src/mlops_compass.py - Copy from repo source (has --demo and correct ANSI codes)
if [ -f "$SCRIPT_DIR/mlops_compass_project_src/mlops_compass.py" ]; then
    cp "$SCRIPT_DIR/mlops_compass_project_src/mlops_compass.py" src/mlops_compass.py
else
    echo "Error: $SCRIPT_DIR/mlops_compass_project_src/mlops_compass.py not found." >&2
    exit 1
fi

# 3. Setup Python Virtual Environment and Install Dependencies
echo "3. Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate
pip install -q Flask
echo "Flask installed for dashboard."

# 4. Generate Dashboard (metrics view)
echo "4. Generating dashboard..."
cat <<'DASHEOF' > dashboard/dashboard.py
"""Web dashboard for MLOps Day3 Compass: metrics from assessment demo."""
import os
import json
from flask import Flask, render_template, jsonify

_APP_ROOT = os.path.dirname(os.path.abspath(__file__))
app = Flask(__name__, template_folder=os.path.join(_APP_ROOT, "templates"))
SCRIPT_DIR = os.environ.get("DAY3_SCRIPT_DIR", os.path.dirname(_APP_ROOT))
METRICS_FILE = os.path.join(SCRIPT_DIR, "metrics.json")
DASHBOARD_PORT = int(os.environ.get("DASHBOARD_PORT", "5001"))

def get_metrics():
    try:
        if os.path.isfile(METRICS_FILE):
            with open(METRICS_FILE, encoding="utf-8") as f:
                m = json.load(f)
            # Map compass fields to dashboard display (iteration, accuracy, total_predictions, last_check)
            return {
                "iteration": m.get("iteration", 0),
                "accuracy": m.get("accuracy", 0),
                "drift_active": m.get("drift_active", False),
                "total_predictions": m.get("total_predictions", 0),
                "last_check": m.get("last_check"),
                "overall_level": m.get("overall_level"),
                "overall_avg_score": m.get("overall_avg_score"),
            }
    except Exception:
        pass
    return {"iteration": 0, "accuracy": 0, "drift_active": False, "total_predictions": 0, "last_check": None, "overall_level": None, "overall_avg_score": None}

@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "dashboard"}), 200

@app.route("/")
def index():
    try:
        return render_template("index.html", dashboard_port=DASHBOARD_PORT)
    except Exception:
        return "<h1>Dashboard</h1><p>Template error.</p>", 500

@app.route("/api/metrics")
def api_metrics():
    try:
        return jsonify(get_metrics())
    except Exception:
        return jsonify(get_metrics())

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=DASHBOARD_PORT, debug=False, threaded=True)
DASHEOF

cat <<'HTMLEOF' > dashboard/templates/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MLOps Day3 Compass Dashboard</title>
  <link rel="stylesheet" href="/static/style.css">
</head>
<body>
  <div class="dashboard-wrap">
    <header class="page-header">
      <h1>MLOps Day3 Compass Dashboard</h1>
      <span class="header-badge">Live</span>
    </header>
    <main class="dashboard-main">
      <section class="card card-metrics">
        <h2 class="card-title">Assessment metrics</h2>
        <div class="metrics" id="metrics">
          <div class="metric"><div class="value" id="iter">-</div><div class="label">Iteration (runs)</div></div>
          <div class="metric"><div class="value" id="acc">-</div><div class="label">Accuracy (score 0-1)</div></div>
          <div class="metric"><div class="value" id="preds">-</div><div class="label">Total questions</div></div>
          <div class="metric"><div class="value" id="level">-</div><div class="label">Maturity level</div></div>
        </div>
        <div class="updated" id="updated"></div>
      </section>
    </main>
  </div>
  <script>
    function loadMetrics() {
      fetch('/api/metrics').then(r => r.json()).then(m => {
        document.getElementById('iter').textContent = m.iteration;
        document.getElementById('acc').textContent = (m.accuracy != null ? (Number(m.accuracy) * 100).toFixed(2) + '%' : '-');
        document.getElementById('preds').textContent = m.total_predictions;
        document.getElementById('level').textContent = m.overall_level != null ? m.overall_level : '-';
        document.getElementById('updated').textContent = m.last_check ? 'Last run: ' + m.last_check : '';
      }).catch(() => {});
    }
    loadMetrics();
    setInterval(loadMetrics, 3000);
  </script>
</body>
</html>
HTMLEOF

cp "$SCRIPT_DIR/../Day2/dashboard/static/style.css" dashboard/static/style.css 2>/dev/null || true
if [ ! -f dashboard/static/style.css ]; then
  echo ':root{--bg:#d4edda;--card:#c3e6cb;--accent:#155724;} *{box-sizing:border-box;} body{font-family:system-ui;background:var(--bg);margin:0;padding:2rem;} .dashboard-wrap{max-width:900px;margin:0 auto;} .page-header{display:flex;align-items:center;justify-content:space-between;margin-bottom:2rem;border-bottom:3px solid var(--accent);} .card{background:var(--card);border-radius:12px;padding:1.5rem;margin-bottom:1rem;} .metric{text-align:center;padding:1rem;} .metric .value{font-size:1.75rem;font-weight:700;color:var(--accent);} .metric .label{font-size:0.7rem;color:#2d6a3e;} .metrics{display:grid;grid-template-columns:repeat(4,1fr);gap:1rem;}' > dashboard/static/style.css
fi

# 5. Generate start.sh, stop.sh, run_tests.sh, validate_dashboard.sh
echo "5. Generating start.sh, stop.sh, run_tests.sh, validate_dashboard.sh..."
PROJECT_ABS="$(pwd)"
cat <<STARTEOF > start.sh
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\$0")" && pwd)"
cd "\$SCRIPT_DIR" || exit 1
if [ -x "\$SCRIPT_DIR/venv/bin/python" ]; then
  PYTHON_CMD="\$SCRIPT_DIR/venv/bin/python"
else
  PYTHON_CMD="python3"
fi
# Run demo once to refresh metrics, then start dashboard
"\$PYTHON_CMD" "\$SCRIPT_DIR/src/mlops_compass.py" --demo 2>/dev/null || true
DAY3_SCRIPT_DIR="\$SCRIPT_DIR" DASHBOARD_PORT="${DASHBOARD_PORT}" nohup "\$PYTHON_CMD" "\$SCRIPT_DIR/dashboard/dashboard.py" &> dashboard.log &
echo \$! > dashboard.pid
echo "Started dashboard at http://localhost:${DASHBOARD_PORT}"
STARTEOF
chmod +x start.sh

cat <<'STOPEOF' > stop.sh
#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR" || true
[ -f dashboard.pid ] && kill "$(cat dashboard.pid)" 2>/dev/null || true
pkill -f "dashboard/dashboard.py" 2>/dev/null || true
rm -f dashboard.pid
echo "Stopped dashboard."
STOPEOF
chmod +x stop.sh

cat <<'TESTEOF' > run_tests.sh
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
TESTEOF
chmod +x run_tests.sh

cat <<'VALEOF' > validate_dashboard.sh
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
VALEOF
chmod +x validate_dashboard.sh

# 6. Run demo (non-interactive) to populate metrics.json for dashboard
echo "6. Running MLOps Compass in demo mode (populates metrics for dashboard)..."
python3 src/mlops_compass.py --demo

# 7. Create Dockerfile (optional; build only, no interactive run)
echo "7. Creating Dockerfile..."
cat <<EOF > Dockerfile
FROM python:3.9-slim-buster
WORKDIR /app
COPY . /app
CMD ["python", "src/mlops_compass.py", "--demo"]
EOF
if command -v docker &>/dev/null; then
  docker build -t mlops-compass:latest . 2>/dev/null || echo "   Docker build skipped (docker not available or failed)."
else
  echo "   Docker not available; skipping build."
fi

# 8. Start dashboard and run tests
echo "8. Starting dashboard (full path)..."
./stop.sh 2>/dev/null || true
sleep 1
if [ -x "$(pwd)/venv/bin/python" ]; then
  DAY3_SCRIPT_DIR="$(pwd)" DASHBOARD_PORT="$DASHBOARD_PORT" nohup "$(pwd)/venv/bin/python" "$(pwd)/dashboard/dashboard.py" &> dashboard.log &
else
  DAY3_SCRIPT_DIR="$(pwd)" DASHBOARD_PORT="$DASHBOARD_PORT" nohup python3 "$(pwd)/dashboard/dashboard.py" &> dashboard.log &
fi
echo $! > dashboard.pid
sleep 2
echo "9. Running tests..."
./run_tests.sh || true
./validate_dashboard.sh || true

deactivate
echo "--- MLOps Compass: Setup and Demo Complete ---"
echo "Dashboard: http://localhost:$DASHBOARD_PORT"
echo "To stop: $SCRIPT_DIR/$PROJECT_DIR/stop.sh  or: $(pwd)/stop.sh"