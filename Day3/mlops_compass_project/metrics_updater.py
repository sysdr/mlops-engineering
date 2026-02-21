"""Background process: updates metrics.json every 1 second so dashboard values keep changing."""
import os
import json
import time
import random
from datetime import datetime, timezone

SCRIPT_DIR = os.environ.get("DAY3_SCRIPT_DIR", os.path.dirname(os.path.abspath(__file__)))
METRICS_FILE = os.path.join(SCRIPT_DIR, "metrics.json")
INTERVAL = 1  # seconds

def read_metrics():
    try:
        if os.path.isfile(METRICS_FILE):
            with open(METRICS_FILE, encoding="utf-8") as f:
                return json.load(f)
    except Exception:
        pass
    return {
        "iteration": 0,
        "accuracy": 0.75,
        "drift_active": False,
        "total_predictions": 6,
        "last_check": None,
        "overall_level": 3,
        "overall_avg_score": 3.0,
        "dimension_scores": {},
    }

def write_metrics(m):
    try:
        with open(METRICS_FILE, "w", encoding="utf-8") as f:
            json.dump(m, f, indent=2)
    except Exception:
        pass

def main():
    metrics = read_metrics()
    iteration = int(metrics.get("iteration", 0))
    total_predictions = int(metrics.get("total_predictions", 6))
    while True:
        iteration += 1
        total_predictions += 1
        # Vary accuracy between 0.70 and 0.99
        accuracy = round(0.70 + 0.29 * random.random(), 4)
        # Cycle level 1-4 or small variation
        level = (iteration % 4) + 1
        overall_avg = round(2.0 + (level - 1) * 0.35 + 0.1 * random.random(), 2)
        metrics = {
            "iteration": iteration,
            "accuracy": accuracy,
            "drift_active": level <= 2,
            "total_predictions": total_predictions,
            "last_check": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S"),
            "overall_level": level,
            "overall_avg_score": overall_avg,
            "dimension_scores": {
                "Data & Experimentation Management": max(1, min(4, level + random.randint(-1, 1))),
                "Model Deployment & Integration": max(1, min(4, level + random.randint(-1, 1))),
                "Monitoring & Governance": max(1, min(4, level + random.randint(-1, 1))),
            },
        }
        write_metrics(metrics)
        time.sleep(INTERVAL)

if __name__ == "__main__":
    main()
