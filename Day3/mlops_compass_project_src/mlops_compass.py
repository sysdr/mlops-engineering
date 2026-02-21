"""MLOps Compass - Maturity assessment with optional --demo mode for dashboard metrics."""
import json
import os
import sys
import argparse
from datetime import datetime, timezone

# Define color codes (ANSI)
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


def load_questions(filepath):
    """Loads questions from a JSON file."""
    if not os.path.exists(filepath):
        print(f"{Colors.FAIL}Error: Questions file not found at {filepath}{Colors.ENDC}")
        sys.exit(1)
    with open(filepath, 'r') as f:
        return json.load(f)


def run_assessment(questions_data, demo_mode=False):
    """Runs the interactive (or demo) MLOps maturity assessment."""
    dimension_scores = {dim: [] for dim in questions_data.keys()}
    if not demo_mode:
        print(f"\n{Colors.HEADER}--- MLOps Maturity Assessment ---{Colors.ENDC}")
        print("Answer the following questions to assess your organization's MLOps maturity.")
        print("Choose the option that best describes your current practices (e.g., 'A', 'B', 'C', 'D').\n")

    for dimension, q_list in questions_data.items():
        if not demo_mode:
            print(f"{Colors.BOLD}\n-- Dimension: {dimension} --{Colors.ENDC}")
        for q_idx, q in enumerate(q_list):
            if not demo_mode:
                print(f"\n{q_idx + 1}. {q['question']}")
                for opt_idx, option_text in enumerate(q['options']):
                    print(f"  {chr(65 + opt_idx)}) {option_text}")

            if demo_mode:
                # Default: option C (index 2) for all questions
                choice_idx = 2
                if choice_idx >= len(q['options']):
                    choice_idx = len(q['options']) - 1
                selected_score = q['scores'][choice_idx]
                dimension_scores[dimension].append(selected_score)
            else:
                while True:
                    choice = input(f"{Colors.OKBLUE}Your choice (A, B, C, D): {Colors.ENDC}").strip().upper()
                    if choice in [chr(65 + i) for i in range(len(q['options']))]:
                        selected_score = q['scores'][ord(choice) - ord('A')]
                        dimension_scores[dimension].append(selected_score)
                        break
                    else:
                        print(f"{Colors.WARNING}Invalid choice. Please enter A, B, C, or D.{Colors.ENDC}")
    return dimension_scores


def compute_overall(dimension_scores):
    """Compute overall total and average scores."""
    overall_total_score = 0
    overall_max_score = 0
    total_questions = 0
    for dim, scores in dimension_scores.items():
        overall_total_score += sum(scores)
        overall_max_score += len(scores) * 4
        total_questions += len(scores)
    overall_avg_score = (overall_total_score / overall_max_score * 4) if overall_max_score > 0 else 0
    return overall_avg_score, total_questions, overall_total_score, overall_max_score


def generate_report(dimension_scores, quiet=False):
    """Generates and prints the MLOps maturity report."""
    if not quiet:
        print(f"\n{Colors.HEADER}--- MLOps Maturity Report ---{Colors.ENDC}")

    overall_avg_score, total_questions, overall_total_score, overall_max_score = compute_overall(dimension_scores)
    maturity_levels = {
        1: "Ad-Hoc/Manual",
        2: "Repeatable/Automated",
        3: "Managed/Standardized",
        4: "Optimized/Autonomous"
    }

    if not quiet:
        print(f"\n{Colors.BOLD}Maturity by Dimension:{Colors.ENDC}")
        for dim, scores in dimension_scores.items():
            if not scores:
                avg_score = 0
            else:
                avg_score = sum(scores) / len(scores)
            level_idx = int(round(avg_score))
            if level_idx < 1: level_idx = 1
            if level_idx > 4: level_idx = 4
            print(f"  - {dim}: Average Score {avg_score:.2f} (Level {level_idx}: {maturity_levels.get(level_idx, 'Unknown')})")

    overall_level_idx = int(round(overall_avg_score))
    if overall_level_idx < 1: overall_level_idx = 1
    if overall_level_idx > 4: overall_level_idx = 4

    if not quiet:
        print(f"\n{Colors.BOLD}Overall MLOps Maturity:{Colors.ENDC}")
        print(f"  Total Average Score: {overall_avg_score:.2f}")
        print(f"  Maturity Level: {Colors.OKGREEN}Level {overall_level_idx}: {maturity_levels.get(overall_level_idx, 'Unknown')}{Colors.ENDC}")
        print(f"\n{Colors.OKCYAN}-- Recommendations --{Colors.ENDC}")
        if overall_level_idx <= 2:
            print("  Focus on standardizing basic processes and implementing foundational tools for data versioning and experiment tracking.")
            print("  Automate manual deployment steps to improve reproducibility.")
        elif overall_level_idx == 3:
            print("  Consider integrating advanced monitoring for model drift and exploring automated retraining pipelines.")
            print("  Strengthen governance and compliance frameworks with model registries.")
        else:
            print("  Maintain continuous optimization, explore advanced AI ethics, explainability, and autonomous MLOps capabilities.")
            print("  Share best practices across teams and mentor others on advanced MLOps strategies.")
        print(f"\n{Colors.ENDC}--- Assessment Complete ---{Colors.ENDC}")

    return overall_avg_score, overall_level_idx, total_questions


def write_metrics(project_root, overall_avg_score, overall_level_idx, total_questions, dimension_scores):
    """Write metrics.json for dashboard (compatible with Day2-style metrics)."""
    metrics_file = os.environ.get('METRICS_FILE', os.path.join(project_root, 'metrics.json'))
    iteration = 1
    if os.path.isfile(metrics_file):
        try:
            with open(metrics_file, 'r') as f:
                existing = json.load(f)
                iteration = existing.get('iteration', 0) + 1
        except Exception:
            pass
    # Scale overall_avg_score 0-4 to 0-1 for "accuracy" display
    accuracy = round(overall_avg_score / 4.0, 4) if overall_avg_score else 0
    metrics = {
        'iteration': iteration,
        'accuracy': accuracy,
        'drift_active': False,
        'total_predictions': total_questions,
        'last_check': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%S'),
        'overall_level': overall_level_idx,
        'overall_avg_score': round(overall_avg_score, 2),
        'dimension_scores': {k: (sum(v) / len(v) if v else 0) for k, v in dimension_scores.items()},
    }
    with open(metrics_file, 'w') as f:
        json.dump(metrics, f, indent=2)
    return metrics_file


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='MLOps Maturity Assessment')
    parser.add_argument('--demo', action='store_true', help='Run with preset answers and write metrics.json for dashboard')
    args = parser.parse_args()

    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    questions_filepath = os.path.join(project_root, 'data', 'questions.json')
    questions = load_questions(questions_filepath)
    scores = run_assessment(questions, demo_mode=args.demo)
    overall_avg, level_idx, total_questions = generate_report(scores, quiet=args.demo)

    if args.demo:
        write_metrics(project_root, overall_avg, level_idx, total_questions, scores)
        print(f"Demo complete. Metrics written. Overall: {overall_avg:.2f}, Level: {level_idx}, Questions: {total_questions}")
