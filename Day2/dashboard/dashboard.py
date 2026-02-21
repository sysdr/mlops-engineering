"""Web dashboard for MLOps Day2: metrics view and restart application."""
import os
import json
import subprocess
from flask import Flask, render_template, jsonify

# App root = directory of this file (dashboard/) so templates resolve correctly
_APP_ROOT = os.path.dirname(os.path.abspath(__file__))
app = Flask(__name__, template_folder=os.path.join(_APP_ROOT, "templates"))
SCRIPT_DIR = os.environ.get("DAY2_SCRIPT_DIR", os.path.dirname(_APP_ROOT))
METRICS_FILE = os.path.join(SCRIPT_DIR, "metrics.json")
API_PORT = int(os.environ.get("API_PORT", "5000"))


def get_metrics():
    try:
        if os.path.isfile(METRICS_FILE):
            with open(METRICS_FILE, encoding="utf-8") as f:
                return json.load(f)
    except Exception:
        pass
    return {
        "iteration": 0,
        "accuracy": 0,
        "drift_active": False,
        "total_predictions": 0,
        "last_check": None,
    }


@app.route("/health")
def health():
    return jsonify({"status": "ok", "service": "dashboard"}), 200


@app.route("/")
def index():
    try:
        return render_template("index.html", api_port=API_PORT)
    except Exception:
        return "<h1>Dashboard</h1><p>Template error. Check dashboard/templates/index.html.</p>", 500


@app.route("/api/metrics")
def api_metrics():
    try:
        return jsonify(get_metrics())
    except Exception:
        return jsonify({
            "iteration": 0,
            "accuracy": 0,
            "drift_active": False,
            "total_predictions": 0,
            "last_check": None,
        })


@app.route("/api/restart", methods=["POST"])
def api_restart():
    # Use stop_app.sh (API + monitor only), NOT stop.sh (which would kill this dashboard)
    try:
        stop_app_sh = os.path.join(SCRIPT_DIR, "stop_app.sh")
        start_sh = os.path.join(SCRIPT_DIR, "start_app.sh")
        if not os.path.isfile(stop_app_sh):
            return jsonify({"ok": False, "error": "stop_app.sh not found. Run setup first."}), 400
        if not os.path.isfile(start_sh):
            return jsonify({"ok": False, "error": "start_app.sh not found. Run setup first."}), 400
        subprocess.run([stop_app_sh], cwd=SCRIPT_DIR, shell=True, timeout=10)
        subprocess.Popen([start_sh], cwd=SCRIPT_DIR, shell=True, start_new_session=True)
        return jsonify({"ok": True, "message": "Restart triggered (API and Monitor). Dashboard stays running."})
    except subprocess.TimeoutExpired:
        return jsonify({"ok": False, "error": "stop timed out"}), 500
    except Exception as e:
        return jsonify({"ok": False, "error": str(e)}), 500


if __name__ == "__main__":
    port = int(os.environ.get("DASHBOARD_PORT", "5001"))
    app.run(host="0.0.0.0", port=port, debug=False, threaded=True)
