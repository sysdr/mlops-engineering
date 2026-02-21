"""Web dashboard for MLOps Day3 Compass: metrics from assessment demo."""
import os
import json
import subprocess
from flask import Flask, render_template, jsonify

_APP_ROOT = os.path.dirname(os.path.abspath(__file__))
app = Flask(__name__, template_folder=os.path.join(_APP_ROOT, "templates"))
SCRIPT_DIR = os.environ.get("DAY3_SCRIPT_DIR", os.path.dirname(_APP_ROOT))
METRICS_FILE = os.path.join(SCRIPT_DIR, "metrics.json")
DASHBOARD_PORT = int(os.environ.get("DASHBOARD_PORT", "5001"))
UPDATER_SCRIPT = os.path.join(SCRIPT_DIR, "metrics_updater.py")
UPDATER_PID_FILE = os.path.join(SCRIPT_DIR, "updater.pid")

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


@app.route("/api/restart", methods=["POST"])
def api_restart():
    """Restart the metrics updater (dashboard keeps running)."""
    try:
        if os.path.isfile(UPDATER_PID_FILE):
            with open(UPDATER_PID_FILE, encoding="utf-8") as f:
                pid = int(f.read().strip())
            try:
                os.kill(pid, 15)
            except (ProcessLookupError, OSError):
                pass
            os.remove(UPDATER_PID_FILE)
        if not os.path.isfile(UPDATER_SCRIPT):
            return jsonify({"ok": False, "error": "metrics_updater.py not found"}), 400
        py_cmd = os.path.join(SCRIPT_DIR, "venv", "bin", "python")
        if not os.path.isfile(py_cmd):
            py_cmd = "python3"
        env = os.environ.copy()
        env["DAY3_SCRIPT_DIR"] = SCRIPT_DIR
        log_path = os.path.join(SCRIPT_DIR, "updater.log")
        with open(log_path, "a") as log:
            proc = subprocess.Popen(
                [py_cmd, UPDATER_SCRIPT],
                cwd=SCRIPT_DIR,
                env=env,
                start_new_session=True,
                stdout=log,
                stderr=subprocess.STDOUT,
            )
        with open(UPDATER_PID_FILE, "w") as f:
            f.write(str(proc.pid))
        return jsonify({"ok": True, "message": "Application (metrics updater) restarted. Values will keep updating every 1s."})
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=DASHBOARD_PORT, debug=False, threaded=True)
