#!/usr/bin/env python3
"""
📋 Extract Gemini Analysis Summary

This script extracts a formatted summary from Gemini AI analysis JSON output
for use in GitHub PR comments and notifications.
"""

import json
import sys
import os
from datetime import datetime

def extract_summary_from_analysis(analysis_file):
    """Extract formatted summary from Gemini analysis JSON"""

    try:
        with open(analysis_file, 'r') as f:
            data = json.load(f)
    except FileNotFoundError:
        return "❌ Analysis file not found"
    except json.JSONDecodeError:
        return "❌ Invalid JSON format in analysis file"

    summary = data.get('summary', {})
    analyses = data.get('analyses', [])

    # Build formatted summary
    formatted_summary = []

    # Header
    formatted_summary.append("## 🤖 Gemini AI Code Analysis Results")
    formatted_summary.append("")

    # Overall Scores
    avg_scores = summary.get('averageScores', {})
    if any(avg_scores.values()):
        formatted_summary.append("### 📊 Overall Assessment")

        if avg_scores.get('security'):
            security_emoji = "🔒" if avg_scores['security'] >= 80 else "⚠️" if avg_scores['security'] >= 60 else "❌"
            formatted_summary.append(f"- {security_emoji} **Security Score**: {avg_scores['security']}/100")

        if avg_scores.get('gasEfficiency'):
            gas_emoji = "⚡" if avg_scores['gasEfficiency'] >= 80 else "⚠️" if avg_scores['gasEfficiency'] >= 60 else "❌"
            formatted_summary.append(f"- {gas_emoji} **Gas Efficiency**: {avg_scores['gasEfficiency']}/100")

        if avg_scores.get('codeQuality'):
            quality_emoji = "📝" if avg_scores['codeQuality'] >= 80 else "⚠️" if avg_scores['codeQuality'] >= 60 else "❌"
            formatted_summary.append(f"- {quality_emoji} **Code Quality**: {avg_scores['codeQuality']}/100")

        formatted_summary.append("")

    # Risk Distribution
    risk_dist = summary.get('riskDistribution', {})
    if any(risk_dist.values()):
        formatted_summary.append("### 🎯 Risk Assessment")

        for risk_level, count in risk_dist.items():
            if count > 0:
                emoji = {"LOW": "✅", "MEDIUM": "⚠️", "HIGH": "❌", "CRITICAL": "🚨"}.get(risk_level, "❓")
                formatted_summary.append(f"- {emoji} **{risk_level}**: {count} file(s)")

        formatted_summary.append("")

    # Key Recommendations
    recommendations = summary.get('recommendations', [])
    if recommendations:
        formatted_summary.append("### 💡 Key Recommendations")

        for i, rec in enumerate(recommendations[:5], 1):  # Top 5 recommendations
            formatted_summary.append(f"{i}. {rec}")

        if len(recommendations) > 5:
            formatted_summary.append(f"... and {len(recommendations) - 5} more recommendations")

        formatted_summary.append("")

    # File-by-file Analysis
    successful_analyses = [a for a in analyses if not a.get('error')]
    if successful_analyses:
        formatted_summary.append("### 📄 File Analysis Summary")

        for analysis in successful_analyses[:3]:  # Show first 3 files
            file_name = analysis.get('file', 'Unknown')
            analysis_text = analysis.get('analysis', '')

            # Extract key insights
            lines = analysis_text.split('\n')
            key_insights = []

            for line in lines:
                if any(marker in line for marker in ['Security Score:', 'Gas Efficiency:', 'Risk Level:', '###']):
                    key_insights.append(line.strip())

            if key_insights:
                formatted_summary.append(f"**{file_name}**:")
                for insight in key_insights[:3]:  # Top 3 insights per file
                    formatted_summary.append(f"- {insight}")
                formatted_summary.append("")

    # Statistics
    total_files = summary.get('totalFiles', 0)
    successful = summary.get('successfulAnalyses', 0)
    failed = summary.get('failedAnalyses', 0)

    formatted_summary.append("### 📈 Analysis Statistics")
    formatted_summary.append(f"- **Total Files**: {total_files}")
    formatted_summary.append(f"- **Successfully Analyzed**: {successful}")
    formatted_summary.append(f"**Failed**: {failed}")

    if failed > 0:
        formatted_summary.append("")
        formatted_summary.append("⚠️ **Some files could not be analyzed**. Check the full analysis report for details.")

    # Footer
    formatted_summary.append("")
    formatted_summary.append("---")
    formatted_summary.append("*Analysis powered by Google Gemini AI*")
    formatted_summary.append(f"*Generated on {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} UTC*")

    return "\n".join(formatted_summary)

def main():
    """Main function"""
    if len(sys.argv) != 2:
        print("Usage: python3 extract_gemini_summary.py <analysis.json>")
        sys.exit(1)

    analysis_file = sys.argv[1]
    summary = extract_summary_from_analysis(analysis_file)
    print(summary)

if __name__ == "__main__":
    main()