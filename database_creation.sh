#!/bin/bash

# Strict error handling
set -euo pipefail

# Logging setup
CLUSTER_NAME="$1"
PORT="$2"
LOG_FILE="/var/lib/postgresql/dbscript/log/create_pg_db_${CLUSTER_NAME}.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

# Input validation
if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <cluster_name> <port>"
  exit 1
fi

# Define paths
TBS_BASE="/FRA/${CLUSTER_NAME}/${CLUSTER_NAME}_tbs"
TBS_DATA="${TBS_BASE}/data"
TBS_LOG="${TBS_BASE}/log"

echo "========================================"
echo " Starting DB setup for cluster '$CLUSTER_NAME' on port $PORT"
echo " Date: $(date)"
echo "========================================"

# Create tablespace directories
echo " Creating tablespace directories..."
sudo mkdir -p "$TBS_DATA" "$TBS_LOG"
sudo chown -R postgres:postgres "$TBS_BASE"

# Prepare SQL file
SQL_FILE="/tmp/create_${CLUSTER_NAME}_db.sql"
cat <<EOF > "$SQL_FILE"
CREATE TABLESPACE ${CLUSTER_NAME}tbs01 LOCATION '${TBS_DATA}';
CREATE TABLESPACE ${CLUSTER_NAME}log01 LOCATION '${TBS_LOG}';
CREATE DATABASE ${CLUSTER_NAME} TABLESPACE ${CLUSTER_NAME}tbs01;
EOF

echo " SQL commands prepared in $SQL_FILE:"
cat "$SQL_FILE"

# Run SQL commands via psql
echo " Executing SQL commands..."
sudo -u postgres psql -p "$PORT" -U postgres -f "$SQL_FILE"

# Validate connection
echo " Validating database connection to '${CLUSTER_NAME}'..."
if sudo -u postgres psql -p "$PORT" -U postgres -d "${CLUSTER_NAME}" -c '\q'; then
  echo " Database '${CLUSTER_NAME}' and tablespaces created successfully!"
else
  echo " ERROR: Unable to connect to database '${CLUSTER_NAME}' on port ${PORT}."
  exit 1
fi


# Clean up
rm -f "$SQL_FILE"

echo " Database '${CLUSTER_NAME}' and tablespaces created successfully!"
echo " Log file: $LOG_FILE"
echo " Script completed at: $(date)"
