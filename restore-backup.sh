#!/bin/bash
# اسکریپت restore backup

set -e

log() { echo -e "✅ $1"; }
error() { echo -e "❌ $1"; exit 1; }

cd /root/pocketbase

# توقف سرویس
systemctl stop pocketbase.service

# دانلود و restore
log "دانلود backup جدید..."
curl -L -o backup.zip \
    "https://github.com/heydarlouam/pb-setup-scripts/raw/main/pocketbase_backup.zip"

log "Restore backup..."
unzip -o backup.zip
rm backup.zip

# راه‌اندازی مجدد
systemctl start pocketbase.service

log "Backup با موفقیت restore شد"
echo "🔍 وضعیت: systemctl status pocketbase"