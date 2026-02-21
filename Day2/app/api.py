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
    app.run(host='0.0.0.0', port=5000)
