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
LOG_FILE="/var/lib/postgresql/dbscript/log/setup_pgaudit_${CLUSTER_NAME}.log"

mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "======================================"
echo " PostgreSQL pgaudit Setup Script"
echo " Cluster: ${CLUSTER_NAME}"
echo " Port: ${PORT}"
echo " Time: $(date)"
echo "======================================"

# Step 1: Install required packages
echo " Installing required packages..."
sudo apt-get -y update
sudo apt-get install -y postgresql-contrib-16 postgresql-16-pgaudit

# Step 2: Modify postgresql.conf to preload pgaudit library
CONF_FILE="/var/lib/postgresql/16/${CLUSTER_NAME}/postgresql.conf"

echo " Modifying postgresql.conf to load pgaudit extension..."
if ! grep -q "shared_preload_libraries = 'pgaudit'" "$CONF_FILE"; then
  sudo -u postgres sed -i "s|^#shared_preload_libraries = ''|shared_preload_libraries = 'pgaudit'|" "$CONF_FILE"
else
  echo " pgaudit is already enabled in shared_preload_libraries."
fi

# Step 3: Restart PostgreSQL service to apply changes
echo " Restarting PostgreSQL service for '${CLUSTER_NAME}'..."
sudo systemctl restart "postgresql@${CLUSTER_NAME}.service"

# Step 4: Create pgaudit extension and configure logging settings
echo " Creating pgaudit extension and setting up logging..."
SQL_FILE="/tmp/create_pgaudit_${CLUSTER_NAME}.sql"
cat <<EOF > "$SQL_FILE"
CREATE EXTENSION IF NOT EXISTS pgaudit;
ALTER DATABASE ${CLUSTER_NAME} SET pgaudit.log = 'ddl, write';
EOF

echo " SQL commands prepared in $SQL_FILE:"
cat "$SQL_FILE"

# Run SQL commands via psql
sudo -u postgres psql -U postgres -p "$PORT" -d "$CLUSTER_NAME" -f "$SQL_FILE"

# Step 5: Verify if pgaudit settings were applied
echo " Verifying pgaudit settings..."
PGAUDIT_LOG=$(sudo -u postgres psql -U postgres -p "$PORT" -d "$CLUSTER_NAME" -t -c "SHOW pgaudit.log;")

if [[ "$PGAUDIT_LOG" == " ddl, write" ]]; then
  echo " pgaudit setup completed successfully for cluster '${CLUSTER_NAME}'"
else
  echo " Failed to configure pgaudit for cluster '${CLUSTER_NAME}'. Please check the logs."
  exit 1
fi

# Clean up SQL file
rm -f "$SQL_FILE"

echo " Log file: $LOG_FILE"
