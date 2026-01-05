#!/bin/bash

# Strict error handling
set -euo pipefail

# ==== Input validation ====
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <cluster_name> <port>"
  exit 1
fi

CLUSTER_NAME="$1"
PORT="$2"
ARCHIVE_DIR="/FRA/archive/${CLUSTER_NAME}"
LOG_FILE="/var/lib/postgresql/dbscript/log/setup_pg_archive_${CLUSTER_NAME}.log"

mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "======================================"
echo " PostgreSQL Archiving Setup Script"
echo " Cluster: ${CLUSTER_NAME}"
echo " Port: ${PORT}"
echo " Time: $(date)"
echo "======================================"

# === Step 1: Create archive directory ===
echo " Creating archive directory at: ${ARCHIVE_DIR}"
sudo mkdir -p "$ARCHIVE_DIR"
sudo chown -R postgres:postgres /FRA
sudo chmod -R 775 /FRA

# Prepare SQL file
SQL_FILE="/tmp/create_${CLUSTER_NAME}_db.sql"
cat <<EOF > "$SQL_FILE"
ALTER SYSTEM SET archive_mode TO 'ON';
ALTER SYSTEM SET max_wal_senders TO 10;
ALTER SYSTEM SET wal_level TO 'replica';
ALTER SYSTEM SET archive_command TO 'cp %p ${ARCHIVE_DIR}/%f';
ALTER SYSTEM SET archive_timeout TO '900s';
SELECT pg_reload_conf();
SELECT pg_switch_wal();
EOF

echo " SQL commands prepared in $SQL_FILE:"
cat "$SQL_FILE"

# Run SQL commands via psql
echo "️  Applying archive configuration via ALTER SYSTEM..."
sudo -u postgres psql -U postgres -p "$PORT" -d "$CLUSTER_NAME" -f "$SQL_FILE"

# Clean up SQL file
echo " Removing temporary SQL file: $SQL_FILE"
rm -f "$SQL_FILE"

# === Step 3: Restart the cluster service ===
SERVICE_FILE="/etc/systemd/system/postgresql@${CLUSTER_NAME}.service"
if [[ -f "$SERVICE_FILE" ]]; then
  echo " Restarting PostgreSQL service: postgresql@${CLUSTER_NAME}.service" 
  sudo systemctl restart "postgresql@${CLUSTER_NAME}.service" > /tmp/restart_${CLUSTER_NAME}_service.log 2>&1
  echo " Service restart log saved to: /tmp/restart_${CLUSTER_NAME}_service.log"
else
  echo "  WARNING: Custom service file not found at $SERVICE_FILE. Skipping service restart."
fi

echo " Archiving setup complete for cluster '${CLUSTER_NAME}'!"
echo " Archive Directory: ${ARCHIVE_DIR}"
echo " Log File: $LOG_FILE"
