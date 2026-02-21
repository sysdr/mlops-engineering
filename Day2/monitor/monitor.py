import requests
import numpy as np
import time
import os
from sklearn.datasets import make_classification

API_URL = os.environ.get('API_URL', 'http://localhost:5000/predict')
MONITOR_INTERVAL = int(os.environ.get('MONITOR_INTERVAL', '5'))
DRIFT_ITERATIONS = int(os.environ.get('DRIFT_ITERATIONS', '3'))
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

            metrics = {
                'iteration': iteration,
                'accuracy': round(sim_accuracy, 4),
                'drift_active': drift_active,
                'total_predictions': total_predictions,
                'last_check': time.strftime('%Y-%m-%dT%H:%M:%S'),
            }
            try:
                import json
                with open(METRICS_FILE, 'w') as f:
                    json.dump(metrics, f, indent=2)
            except Exception:
                pass

            print(f"[{time.strftime('%H:%M:%S')}] Monitor: Received {num_preds} predictions from API.")
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
