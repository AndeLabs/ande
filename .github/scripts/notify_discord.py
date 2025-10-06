#!/usr/bin/env python3
"""
📢 Notify Discord Script

This script sends notifications to Discord for CI/CD pipeline status.
"""

import json
import sys
import os
import requests
from datetime import datetime

def send_discord_notification(webhook_url, message, status="info"):
    """Send notification to Discord webhook"""

    if not webhook_url:
        print("❌ Discord webhook URL not provided")
        return False

    # Color codes for different statuses
    colors = {
        "success": 0x00ff00,   # Green
        "failure": 0xff0000,   # Red
        "warning": 0xffff00,   # Yellow
        "info": 0x0099ff       # Blue
    }

    # Create embed
    embed = {
        "title": "🚀 AndeChain CI/CD Pipeline",
        "description": message,
        "color": colors.get(status, colors["info"]),
        "timestamp": datetime.utcnow().isoformat(),
        "footer": {
            "text": "AndeChain Blockchain Infrastructure"
        }
    }

    # Add GitHub context if available
    if os.getenv("GITHUB_REPOSITORY"):
        embed["footer"]["text"] += f" • {os.getenv('GITHUB_REPOSITORY')}"

    if os.getenv("GITHUB_SHA"):
        embed["description"] += f"\n\n**Commit:** `{os.getenv('GITHUB_SHA')[:8]}`"

    payload = {
        "embeds": [embed]
    }

    try:
        response = requests.post(webhook_url, json=payload, timeout=10)
        response.raise_for_status()
        print(f"✅ Discord notification sent: {status}")
        return True
    except Exception as e:
        print(f"❌ Failed to send Discord notification: {e}")
        return False

def main():
    """Main function"""

    # Get arguments
    if len(sys.argv) < 3:
        print("Usage: python3 notify_discord.py <webhook_url> <message> [status]")
        sys.exit(1)

    webhook_url = sys.argv[1]
    message = sys.argv[2]
    status = sys.argv[3] if len(sys.argv) > 3 else "info"

    # Send notification
    success = send_discord_notification(webhook_url, message, status)

    if not success:
        sys.exit(1)

if __name__ == "__main__":
    main()