#!/bin/bash
# 💾 ANDE Chain Backup Script
# Backs up critical data from Docker volumes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_ROOT="${BACKUP_DIR:-$PROJECT_DIR/backups}"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/$DATE"

echo "💾 ANDE Chain Backup Script"
echo "============================"
echo "Backup directory: $BACKUP_DIR"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Define volumes to backup
VOLUMES=(
    "ande_sequencer-data"
    "ande_evolve-data"
    "ande_celestia-data"
    "ande_jwttoken-sequencer"
)

echo ""
echo "📦 Starting backup process..."

# Backup each volume
for VOLUME in "${VOLUMES[@]}"; do
    echo "⏳ Backing up $VOLUME..."

    if docker volume inspect "$VOLUME" > /dev/null 2>&1; then
        docker run --rm \
            -v "$VOLUME:/source:ro" \
            -v "$BACKUP_DIR:/backup" \
            alpine:latest \
            tar czf "/backup/${VOLUME}.tar.gz" -C /source .

        BACKUP_SIZE=$(du -h "$BACKUP_DIR/${VOLUME}.tar.gz" | cut -f1)
        echo "✅ Backed up $VOLUME ($BACKUP_SIZE)"
    else
        echo "⚠️  Volume $VOLUME not found, skipping"
    fi
done

# Backup configuration files
echo ""
echo "⏳ Backing up configuration files..."
CONFIG_BACKUP="$BACKUP_DIR/config"
mkdir -p "$CONFIG_BACKUP"

cp "$PROJECT_DIR/docker-compose.yml" "$CONFIG_BACKUP/" 2>/dev/null || echo "⚠️  docker-compose.yml not found"
cp -r "$PROJECT_DIR/infra/stacks/single-sequencer" "$CONFIG_BACKUP/" 2>/dev/null || echo "⚠️  Config not found"

echo "✅ Configuration files backed up"

# Create backup manifest
echo ""
echo "📝 Creating backup manifest..."
cat > "$BACKUP_DIR/manifest.txt" <<EOF
ANDE Chain Backup Manifest
==========================
Date: $(date)
Backup Directory: $BACKUP_DIR

Volumes Backed Up:
EOF

for VOLUME in "${VOLUMES[@]}"; do
    if [ -f "$BACKUP_DIR/${VOLUME}.tar.gz" ]; then
        SIZE=$(du -h "$BACKUP_DIR/${VOLUME}.tar.gz" | cut -f1)
        echo "  - $VOLUME ($SIZE)" >> "$BACKUP_DIR/manifest.txt"
    fi
done

echo ""
cat >> "$BACKUP_DIR/manifest.txt" <<EOF

Configuration Files:
  - docker-compose.yml
  - genesis.json
  - prometheus.yml

Restore Instructions:
=====================
1. Stop ANDE Chain: docker-compose down
2. Extract volume backup:
   docker run --rm -v VOLUME_NAME:/target -v $(pwd):/backup \\
     alpine:latest tar xzf /backup/VOLUME_NAME.tar.gz -C /target
3. Restore config files to project directory
4. Start ANDE Chain: docker-compose up -d
EOF

echo "✅ Manifest created"

# Calculate total backup size
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
echo ""
echo "✅ Backup completed successfully!"
echo "   Location: $BACKUP_DIR"
echo "   Total size: $TOTAL_SIZE"

# Cleanup old backups (keep last 30 days)
echo ""
echo "🧹 Cleaning up old backups (keeping last 30 days)..."
find "$BACKUP_ROOT" -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null || true
echo "✅ Cleanup completed"

# List recent backups
echo ""
echo "📋 Recent backups:"
ls -lth "$BACKUP_ROOT" | head -6

echo ""
echo "💾 Backup process completed!"
