#!/bin/bash
# Sao lưu Postgres hằng ngày (spec 17.6). Chạy bằng cron trên server, ví dụ:
#   0 3 * * * BACKUP_MOUNT=/mnt/<ổ backup> $HOME/antam-wallet/scripts/backup.sh >> $HOME/antam-wallet/backup.log 2>&1
# Khôi phục vào DB trống:
#   gunzip -c antam-YYYY-MM-DD.sql.gz | docker compose exec -T db psql -U postgres -d antam
set -euo pipefail                     # pipefail: pg_dump lỗi thì không lưu file hỏng

MNT=${BACKUP_MOUNT:-/mnt/backup}      # ổ riêng dành cho backup
KEEP_DAYS=${BACKUP_KEEP_DAYS:-14}
DEST=$MNT/backup-antam

# Ổ backup thường mount "nofail": nếu ổ không lên, $MNT chỉ là thư mục trống trên ổ hệ thống → không ghi
mountpoint -q "$MNT" || { echo "$(date '+%F %T') $MNT chua mount, bo qua backup" >&2; exit 1; }

cd "$(dirname "$0")/.."
f="$DEST/antam-$(date +%F).sql.gz"
# < /dev/null: không cho docker đọc stdin của người gọi (chạy qua "bash -s" sẽ nuốt mất phần script còn lại)
docker compose exec -T db pg_dump -U postgres antam < /dev/null | gzip > "$f.tmp"
mv "$f.tmp" "$f"
find "$DEST" -name 'antam-*.sql.gz' -mtime +"$KEEP_DAYS" -delete
echo "$(date '+%F %T') ok $(du -h "$f" | cut -f1) $f"
