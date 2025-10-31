#!/bin/bash
# ⏰ Setup Automatic Backup Cron Job
# Configures automatic daily backups at 3 AM

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/backup-andechain.sh"

echo "⏰ Setting up automatic backups for ANDE Chain"
echo "=============================================="

# Check if backup script exists
if [ ! -f "$BACKUP_SCRIPT" ]; then
    echo "❌ Backup script not found: $BACKUP_SCRIPT"
    exit 1
fi

# Create cron job entry
CRON_CMD="0 3 * * * $BACKUP_SCRIPT >> /var/log/andechain-backup.log 2>&1"
CRON_COMMENT="# ANDE Chain automatic backup (daily at 3 AM)"

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "$BACKUP_SCRIPT"; then
    echo "ℹ️  Cron job already exists"
    echo "Current cron jobs:"
    crontab -l | grep -A1 "ANDE Chain"
else
    # Add cron job
    (crontab -l 2>/dev/null; echo ""; echo "$CRON_COMMENT"; echo "$CRON_CMD") | crontab -
    echo "✅ Cron job added successfully"
fi

echo ""
echo "📋 Current cron configuration:"
crontab -l | grep -A1 "ANDE Chain" || echo "No ANDE Chain cron jobs found"

echo ""
echo "✅ Automatic backups configured!"
echo ""
echo "🔍 Backup details:"
echo "   Schedule: Daily at 3:00 AM"
echo "   Script: $BACKUP_SCRIPT"
echo "   Log: /var/log/andechain-backup.log"
echo ""
echo "💡 To test the backup manually:"
echo "   $BACKUP_SCRIPT"
