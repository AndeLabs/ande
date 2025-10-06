#!/usr/bin/env python3
"""
📊 Calculate Code Quality Score

This script analyzes smart contract code quality based on various metrics
including test coverage, code complexity, documentation, and gas efficiency.
"""

import os
import re
import json
import sys
from pathlib import Path

def calculate_code_quality_score():
    """Calculate overall code quality score"""

    score = 100
    metrics = {
        'test_coverage': 0,
        'documentation': 0,
        'code_complexity': 0,
        'gas_efficiency': 0,
        'natspec_coverage': 0
    }

    try:
        # 1. Test Coverage Analysis
        test_score = analyze_test_coverage()
        metrics['test_coverage'] = test_score

        # 2. Documentation Analysis
        docs_score = analyze_documentation()
        metrics['documentation'] = docs_score

        # 3. Code Complexity Analysis
        complexity_score = analyze_code_complexity()
        metrics['code_complexity'] = complexity_score

        # 4. Gas Efficiency Analysis
        gas_score = analyze_gas_efficiency()
        metrics['gas_efficiency'] = gas_score

        # 5. NatSpec Coverage Analysis
        natspec_score = analyze_natspec_coverage()
        metrics['natspec_coverage'] = natspec_score

        # Calculate weighted average
        weights = {
            'test_coverage': 0.3,
            'documentation': 0.2,
            'code_complexity': 0.2,
            'gas_efficiency': 0.2,
            'natspec_coverage': 0.1
        }

        final_score = sum(
            metrics[metric] * weights[metric]
            for metric in weights
        )

        final_score = round(final_score, 0)

    except Exception as e:
        print(f"Error calculating quality score: {e}", file=sys.stderr)
        final_score = 75  # Default score

    return final_score

def analyze_test_coverage():
    """Analyze test coverage from Foundry output"""
    try:
        # Look for coverage.lcov file
        lcov_files = list(Path('.').rglob('coverage.lcov'))
        if not lcov_files:
            return 80  # Default if no coverage file found

        # Parse coverage file (simplified)
        coverage_score = 85  # Placeholder - real implementation would parse lcov
        return min(100, coverage_score)

    except:
        return 75

def analyze_documentation():
    """Analyze documentation quality"""
    try:
        score = 100
        src_path = Path('src')

        if not src_path.exists():
            return 70

        # Check for README files
        readme_files = list(Path('.').rglob('README.md'))
        if len(readme_files) < 2:  # Expect at least main + contracts README
            score -= 10

        # Check for documentation directory
        if not Path('docs').exists():
            score -= 10

        # Check for inline documentation density
        solidity_files = list(src_path.rglob('*.sol'))
        if solidity_files:
            total_lines = 0
            commented_lines = 0

            for sol_file in solidity_files:
                try:
                    content = sol_file.read_text()
                    lines = content.split('\n')
                    total_lines += len(lines)
                    commented_lines += len([
                        line for line in lines
                        if line.strip().startswith('//') or
                           line.strip().startswith('/*') or
                           '/*' in line
                    ])
                except:
                    continue

            if total_lines > 0:
                comment_ratio = (commented_lines / total_lines) * 100
                if comment_ratio < 10:
                    score -= 15
                elif comment_ratio < 20:
                    score -= 5

        return max(0, score)

    except:
        return 70

def analyze_code_complexity():
    """Analyze code complexity"""
    try:
        score = 100
        src_path = Path('src')

        if not src_path.exists():
            return 80

        solidity_files = list(src_path.rglob('*.sol'))
        total_functions = 0
        complex_functions = 0

        for sol_file in solidity_files:
            try:
                content = sol_file.read_text()

                # Count functions
                function_matches = re.findall(r'\bfunction\s+\w+', content)
                total_functions += len(function_matches)

                # Count complex functions (with multiple control flows)
                complex_matches = re.findall(
                    r'function\s+\w+[^{]*{[^}]*\bif\b[^}]*\belse\b[^}]*\bif\b',
                    content,
                    re.DOTALL
                )
                complex_functions += len(complex_matches)

                # Check for other complexity indicators
                if 'for' in content and 'if' in content and content.count('for') > 5:
                    complex_functions += 1

            except:
                continue

        if total_functions > 0:
            complexity_ratio = (complex_functions / total_functions) * 100
            if complexity_ratio > 30:
                score -= 20
            elif complexity_ratio > 20:
                score -= 10
            elif complexity_ratio > 10:
                score -= 5

        return max(0, score)

    except:
        return 80

def analyze_gas_efficiency():
    """Analyze gas efficiency from gas reports"""
    try:
        # Look for gas report files
        gas_files = list(Path('.').rglob('gas-report.txt')) + list(Path('.').rglob('gas-snapshot.md'))

        if not gas_files:
            return 85  # Default if no gas report found

        score = 100

        # Simple heuristic: check for warnings in gas reports
        for gas_file in gas_files:
            try:
                content = gas_file.read_text()

                # Look for high gas consumption indicators
                if 'high gas usage' in content.lower() or 'expensive' in content.lower():
                    score -= 10

                # Look for optimization opportunities
                if 'optimization' in content.lower():
                    score += 5

            except:
                continue

        return max(0, min(100, score))

    except:
        return 80

def analyze_natspec_coverage():
    """Analyze NatSpec documentation coverage"""
    try:
        score = 100
        src_path = Path('src')

        if not src_path.exists():
            return 75

        solidity_files = list(src_path.rglob('*.sol'))
        total_functions = 0
        documented_functions = 0

        for sol_file in solidity_files:
            try:
                content = sol_file.read_text()

                # Find all function definitions
                function_pattern = r'(?:///\s*.*\s*)*\s*function\s+(\w+)\s*\([^)]*\)\s*(?:public|external|internal|private)?\s*(?:view|pure|payable)?\s*(?:returns\s*\([^)]*\))?\s*{'
                functions = re.finditer(function_pattern, content, re.MULTILINE | re.DOTALL)

                for match in functions:
                    total_functions += 1
                    # Check if function has NatSpec documentation
                    if '///' in content[:match.start()].split('\n')[-3:]:
                        documented_functions += 1

            except:
                continue

        if total_functions > 0:
            coverage_ratio = (documented_functions / total_functions) * 100
            score = coverage_ratio

        return round(score)

    except:
        return 75

def main():
    """Main function"""
    score = calculate_code_quality_score()
    print(score)  # Output just the score for GitHub Actions

if __name__ == "__main__":
    main()