#!/usr/bin/env python3
"""
🔒 Calculate Security Score from Slither Report

This script analyzes Slither JSON output to generate a security score
and extract key security metrics for the CI/CD pipeline.
"""

import json
import sys
import os

def calculate_security_score(slither_file):
    """Calculate security score from Slither JSON report"""

    try:
        with open(slither_file, 'r') as f:
            data = json.load(f)
    except FileNotFoundError:
        return 50  # Default score if file not found
    except json.JSONDecodeError:
        return 45  # Lower score if invalid JSON

    score = 100  # Start with perfect score
    issues = data.get('results', {}).get('detectors', [])

    # Issue severity penalties
    severity_penalties = {
        'high': 25,
        'medium': 15,
        'low': 5,
        'informational': 1
    }

    issue_counts = {
        'high': 0,
        'medium': 0,
        'low': 0,
        'informational': 0
    }

    # Count issues by severity
    for issue in issues:
        impact = issue.get('impact', 'informational').lower()
        if impact in severity_penalties:
            issue_counts[impact] += 1
            score -= severity_penalties[impact]

    # Bonus points for good practices
    checks = data.get('results', {}).get('printers', [])

    # Check for positive indicators
    positive_indicators = [
        'Pausable',
        'AccessControl',
        'ReentrancyGuard',
        'SafeMath',
        'ERC20',
        'ERC721'
    ]

    for check in checks:
        check_name = check.get('check', '')
        for indicator in positive_indicators:
            if indicator.lower() in check_name.lower():
                score += 2  # Small bonus for good practices

    # Ensure score stays within bounds
    score = max(0, min(100, score))

    # Create detailed report
    report = {
        'score': score,
        'total_issues': len(issues),
        'severity_breakdown': issue_counts,
        'checks_performed': len(checks),
        'status': 'EXCELLENT' if score >= 90 else
                'GOOD' if score >= 80 else
                'FAIR' if score >= 70 else
                'POOR' if score >= 60 else 'CRITICAL'
    }

    return score, report

def main():
    """Main function"""
    if len(sys.argv) != 2:
        print("0")  # Default score
        sys.exit(0)

    slither_file = sys.argv[1]
    score, report = calculate_security_score(slither_file)

    print(score)  # Output just the score for GitHub Actions

    # Optional: Save detailed report
    report_file = slither_file.replace('.json', '_score_report.json')
    try:
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
    except:
        pass  # Fail silently if we can't write the report

if __name__ == "__main__":
    main()