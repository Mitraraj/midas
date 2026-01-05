#!/bin/bash
#
# cleanup_pg_logs.sh
# Description: Deletes PostgreSQL cluster logs older than a defined number of days
# Supports multiple cluster directories defined manually below
# Log file pattern: postgresql-<cluster>-YYYY-MM-DD.log
# Also records actions and deleted files in a log file.

# === Configuration ===
PG_BASE_DIR="/var/lib/postgresql/16"
CLUSTERS=("pa" "lab" "um" "tpa" "clinical" "pharmacy" "account")
DAYS_TO_KEEP=3
LOGFILE="/var/lib/postgresql/dbascript/purge_postgres_log.log"

# === Ensure log file directory exists ===
mkdir -p "$(dirname "$LOGFILE")"

# === Logging function ===
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

# === Start of script ===
log "------------------------------------------------------------"
log "Starting PostgreSQL log cleanup"
log "Base directory: $PG_BASE_DIR"
log "Clusters: ${CLUSTERS[*]}"
log "Removing logs older than $DAYS_TO_KEEP days..."
log "Operation log: $LOGFILE"

# === Safety check ===
if [ ! -d "$PG_BASE_DIR" ]; then
    log "Error: PostgreSQL base directory $PG_BASE_DIR does not exist."
    exit 1
fi

# === Loop through defined clusters ===
for CLUSTER_NAME in "${CLUSTERS[@]}"; do
    LOG_DIR="${PG_BASE_DIR}/${CLUSTER_NAME}/log"

    if [ ! -d "$LOG_DIR" ]; then
        log "Skipping ${CLUSTER_NAME}: No log directory found at ${LOG_DIR}"
        continue
    fi

    log "Cleaning logs for cluster: ${CLUSTER_NAME}"

    # Find and delete old logs
    DELETED_LOGS=$(find "$LOG_DIR" -type f -name "postgresql-${CLUSTER_NAME}-*.log" -mtime +$DAYS_TO_KEEP)

    if [ -z "$DELETED_LOGS" ]; then
        log "No old logs found for ${CLUSTER_NAME}."
        echo "" | tee -a "$LOGFILE"
    else
        log "Deleting the following logs for ${CLUSTER_NAME}:"
        echo "$DELETED_LOGS" | tee -a "$LOGFILE"
        # Perform deletion
        find "$LOG_DIR" -type f -name "postgresql-${CLUSTER_NAME}-*.log" -mtime +$DAYS_TO_KEEP -delete
        log "Deletion completed for ${CLUSTER_NAME}."
        echo "" | tee -a "$LOGFILE"
    fi
done

log "Cleanup completed for all defined clusters."
log "------------------------------------------------------------"
