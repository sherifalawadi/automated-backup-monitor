#!/bin/bash
# ============================================================
# Automated System Backup and Monitoring Script
# Ubuntu Linux - Full Featured
# ============================================================

SCRIPT_DIR="/opt/backup_monitor"
CONFIG_FILE="$SCRIPT_DIR/config.conf"
LOG_FILE="$SCRIPT_DIR/logs/backup_monitor.log"
DISK_LOG="$SCRIPT_DIR/logs/disk_usage.log"

# ── Load configuration ──────────────────────────────────────
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Config file not found: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

# ── Ensure directories exist ─────────────────────────────────
mkdir -p "$SCRIPT_DIR/logs"
mkdir -p "$BACKUP_DEST/daily"
mkdir -p "$BACKUP_DEST/weekly"
mkdir -p "$BACKUP_DEST/monthly"

# ── Logging utility ──────────────────────────────────────────
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# ── Email notification ───────────────────────────────────────
send_email() {
    local subject="$1"
    local body="$2"

    if [[ "$EMAIL_ENABLED" != "true" ]]; then
        log "INFO" "Email disabled. Skipping: $subject"
        return
    fi

    if command -v mailx &>/dev/null; then
        echo "$body" | mailx \
            -s "$subject" \
            -S smtp="$SMTP_SERVER:$SMTP_PORT" \
            -S smtp-use-starttls \
            -S smtp-auth=login \
            -S smtp-auth-user="$SMTP_USER" \
            -S smtp-auth-password="$SMTP_PASS" \
            -S from="$SMTP_USER" \
            "$EMAIL_RECIPIENT"
        log "INFO" "Email sent: $subject"
    else
        log "WARN" "mailx not found. Install with: sudo apt install mailutils"
    fi
}

# ── Perform backup ───────────────────────────────────────────
perform_backup() {
    local type="$1"   # daily | weekly | monthly
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_dir="$BACKUP_DEST/$type"
    local success=true
    local report=""

    log "INFO" "Starting $type backup..."

    # Split comma-separated source dirs
    IFS=',' read -ra DIRS <<< "$BACKUP_SOURCES"

    for src in "${DIRS[@]}"; do
        src=$(echo "$src" | xargs)  # trim whitespace
        if [[ ! -d "$src" ]]; then
            log "WARN" "Source directory not found: $src"
            report+="  [SKIP] $src — not found\n"
            continue
        fi

        local dir_name
        dir_name=$(basename "$src")
        local archive="$backup_dir/${dir_name}_${timestamp}.tar.gz"

        log "INFO" "Backing up: $src → $archive"
        if tar -czf "$archive" -C "$(dirname "$src")" "$dir_name" 2>>"$LOG_FILE"; then
            local size
            size=$(du -sh "$archive" | cut -f1)
            log "INFO" "Backup OK: $archive ($size)"
            report+="  [OK]   $src → $archive ($size)\n"
        else
            log "ERROR" "Backup FAILED: $src"
            report+="  [FAIL] $src\n"
            success=false
        fi
    done

    # Rotate old backups
    rotate_backups "$backup_dir" "$type"

    # Notify
    if $success; then
        send_email "[Backup OK] $type backup completed on $(hostname)" \
            "$(date)\n\n$type backup completed successfully.\n\n$report"
    else
        send_email "[Backup FAILED] $type backup on $(hostname)" \
            "$(date)\n\nSome backups failed!\n\n$report\nCheck: $LOG_FILE"
    fi

    log "INFO" "$type backup finished."
}

# ── Backup rotation ──────────────────────────────────────────
rotate_backups() {
    local dir="$1"
    local type="$2"
    local keep

    case "$type" in
        daily)   keep="$KEEP_DAILY" ;;
        weekly)  keep="$KEEP_WEEKLY" ;;
        monthly) keep="$KEEP_MONTHLY" ;;
        *)       keep=7 ;;
    esac

    log "INFO" "Rotating $type backups — keeping latest $keep archives..."
    local count
    count=$(ls -1 "$dir"/*.tar.gz 2>/dev/null | wc -l)
    if (( count > keep )); then
        ls -1t "$dir"/*.tar.gz | tail -n +"$((keep + 1))" | while read -r old; do
            rm -f "$old"
            log "INFO" "Removed old backup: $old"
        done
    fi
}

# ── Disk usage monitoring ────────────────────────────────────
monitor_disk() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local alert_triggered=false
    local disk_report="Disk Usage Report — $timestamp\n"
    disk_report+="$(printf '%-30s %-10s %-10s %-10s %-6s\n' 'Filesystem' 'Size' 'Used' 'Avail' 'Use%')\n"
    disk_report+="$(printf '%.0s─' {1..70})\n"

    while IFS= read -r line; do
        local usage fs
        usage=$(echo "$line" | awk '{print $5}' | tr -d '%')
        fs=$(echo "$line" | awk '{print $6}')
        disk_report+="$line\n"

        if (( usage >= DISK_THRESHOLD )); then
            alert_triggered=true
            log "WARN" "Disk usage ${usage}% on $fs exceeds threshold ${DISK_THRESHOLD}%"
        fi
    done < <(df -h --output=source,size,used,avail,pcent,target | tail -n +2)

    # Log to disk usage log
    echo -e "$disk_report" >> "$DISK_LOG"
    log "INFO" "Disk usage logged to $DISK_LOG"

    if $alert_triggered; then
        send_email "[ALERT] High Disk Usage on $(hostname)" \
            "$(date)\n\nDisk usage exceeded ${DISK_THRESHOLD}% threshold!\n\n$(df -h)"
    fi
}

# ── Log file management ──────────────────────────────────────
rotate_logs() {
    local log_dir="$SCRIPT_DIR/logs"
    local archive_dir="$log_dir/archive"
    mkdir -p "$archive_dir"

    log "INFO" "Starting log rotation..."

    for lf in "$log_dir"/*.log; do
        [[ -f "$lf" ]] || continue
        local size_kb
        size_kb=$(du -k "$lf" | cut -f1)

        if (( size_kb >= LOG_MAX_SIZE_KB )); then
            local ts
            ts=$(date '+%Y%m%d_%H%M%S')
            local base
            base=$(basename "$lf" .log)
            local archived="$archive_dir/${base}_${ts}.log.gz"
            gzip -c "$lf" > "$archived"
            > "$lf"  # truncate active log
            log "INFO" "Rotated: $lf → $archived"
        fi
    done

    # Remove archives older than LOG_KEEP_DAYS
    find "$archive_dir" -name "*.log.gz" -mtime +"$LOG_KEEP_DAYS" -exec rm -f {} \;
    log "INFO" "Log rotation complete."

    send_email "[Log Rotated] Logs rotated on $(hostname)" \
        "$(date)\n\nLog rotation completed.\nArchives kept: $LOG_KEEP_DAYS days.\nArchive dir: $archive_dir"
}

# ── Status report ────────────────────────────────────────────
show_status() {
    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  Backup & Monitor Status — $(date '+%Y-%m-%d %H:%M:%S')"
    echo "═══════════════════════════════════════════════════"
    echo ""
    echo "▸ Backup Destination : $BACKUP_DEST"
    echo "▸ Backup Sources     : $BACKUP_SOURCES"
    echo "▸ Disk Threshold     : ${DISK_THRESHOLD}%"
    echo "▸ Email Enabled      : $EMAIL_ENABLED"
    echo ""
    echo "── Backup Counts ─────────────────────────────────"
    echo "  Daily   : $(ls "$BACKUP_DEST/daily/"*.tar.gz 2>/dev/null | wc -l) / $KEEP_DAILY"
    echo "  Weekly  : $(ls "$BACKUP_DEST/weekly/"*.tar.gz 2>/dev/null | wc -l) / $KEEP_WEEKLY"
    echo "  Monthly : $(ls "$BACKUP_DEST/monthly/"*.tar.gz 2>/dev/null | wc -l) / $KEEP_MONTHLY"
    echo ""
    echo "── Current Disk Usage ────────────────────────────"
    df -h --output=source,size,used,avail,pcent,target | head -1
    df -h --output=source,size,used,avail,pcent,target | tail -n +2
    echo ""
    echo "── Recent Log Entries ────────────────────────────"
    tail -n 10 "$LOG_FILE" 2>/dev/null || echo "  (no log yet)"
    echo "═══════════════════════════════════════════════════"
}

# ── Help ─────────────────────────────────────────────────────
show_help() {
    cat <<EOF

Usage: $(basename "$0") [COMMAND]

Commands:
  backup daily      Run a daily backup
  backup weekly     Run a weekly backup
  backup monthly    Run a monthly backup
  disk              Check disk usage and alert if needed
  rotate-logs       Rotate and archive log files
  status            Show current status summary
  help              Show this help message

Examples:
  ./backup_monitor.sh backup daily
  ./backup_monitor.sh disk
  ./backup_monitor.sh status

Cron setup (edit with: crontab -e):
  0 2  * * *   /path/to/backup_monitor.sh backup daily
  0 3  * * 0   /path/to/backup_monitor.sh backup weekly
  0 4  1 * *   /path/to/backup_monitor.sh backup monthly
  */30 * * * * /path/to/backup_monitor.sh disk
  0 0  * * *   /path/to/backup_monitor.sh rotate-logs

EOF
}

# ── Entry point ──────────────────────────────────────────────
case "$1" in
    backup)
        case "$2" in
            daily|weekly|monthly) perform_backup "$2" ;;
            *) echo "Usage: $0 backup [daily|weekly|monthly]"; exit 1 ;;
        esac
        ;;
    disk)         monitor_disk ;;
    rotate-logs)  rotate_logs ;;
    status)       show_status ;;
    help|--help)  show_help ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
