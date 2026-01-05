#!/bin/bash

# Enable strict mode
set -euo pipefail

# === Accept cluster name and port as input ===
if [[ $# -ne 2 ]]; then
  echo " Usage: $0 <cluster_name> <port>"
  exit 1
fi

CLUSTER_NAME="$1"
PORT="$2"

# Define log file
LOG_FILE="/var/lib/postgresql/dbscript/log/create_pg_${CLUSTER_NAME}.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Start logging (tee writes output to both terminal and log file)
exec > >(tee -a "$LOG_FILE") 2>&1

PG_VERSION="16"
PG_BIN_DIR="/usr/lib/postgresql/${PG_VERSION}/bin"
DATA_DIR="/var/lib/postgresql/${PG_VERSION}/${CLUSTER_NAME}"
LOG_DIR="${DATA_DIR}/log"

echo "======================================"
echo " PostgreSQL Cluster Setup Started"
echo " $(date)"
echo "======================================"

# === Create data and log directory ===
echo " Creating data directory: $DATA_DIR"
sudo mkdir -p "$DATA_DIR"
sudo chown -R postgres:postgres "$DATA_DIR"


# === Initialize PostgreSQL cluster ===
echo " Initializing PostgreSQL cluster for '$CLUSTER_NAME'..."
sudo -u postgres "${PG_BIN_DIR}/initdb" -D "$DATA_DIR"

# === Adjust postgresql.conf for logging and other settings ===
CONF_FILE="${DATA_DIR}/postgresql.conf"

echo "  Configuring postgresql.conf..."
sudo -u postgres sed -i "s|^#*logging_collector.*|logging_collector = on|" "$CONF_FILE"
sudo -u postgres sed -i "s|^#*log_directory.*|log_directory = '${LOG_DIR}'|" "$CONF_FILE"
sudo -u postgres sed -i "s|^#*log_filename.*|log_filename = 'postgresql-${CLUSTER_NAME}-%Y-%m-%d.log'|" "$CONF_FILE"
sudo -u postgres sed -i "s|^#*log_file_mode.*|log_file_mode = 0640|" "$CONF_FILE"
sudo -u postgres sed -i "s|^#*log_rotation_age.*|log_rotation_age = 1d|" "$CONF_FILE"
sudo -u postgres sed -i "s|^#*log_rotation_size.*|log_rotation_size = 0|" "$CONF_FILE"

# === Adjust listen_addresses, max_connections, and port ===
echo "  Configuring listen_addresses, max_connections, and port..."
sudo -u postgres sed -i "s|^#*listen_addresses.*|listen_addresses = '*'|" "$CONF_FILE"
sudo -u postgres sed -i "s|^#*max_connections.*|max_connections = 200|" "$CONF_FILE"
sudo -u postgres sed -i "s|^#*port.*|port = ${PORT}|" "$CONF_FILE"

# === Define HBA file and allow remote connections ===
HBA_FILE="${DATA_DIR}/pg_hba.conf"
echo "  Configuring pg_hba.conf for remote access..."
echo "host all all 0.0.0.0/0 md5" | sudo -u postgres tee -a "$HBA_FILE" > /dev/null

# === Start the PostgreSQL cluster ===
echo " Starting PostgreSQL cluster for '$CLUSTER_NAME' on port $PORT..."
sudo -u postgres "${PG_BIN_DIR}/pg_ctl" -D "$DATA_DIR"  start

# === Stop the PostgreSQL cluster immediately ===
echo " Stopping PostgreSQL cluster '$CLUSTER_NAME' after initial start..."
sudo -u postgres "${PG_BIN_DIR}/pg_ctl" -D "$DATA_DIR" stop

echo "======================================"
echo " Cluster '$CLUSTER_NAME' setup complete at: $DATA_DIR"
echo " To start this cluster manually:"
echo " sudo -u postgres ${PG_BIN_DIR}/pg_ctl -D ${DATA_DIR} -l ${LOG_DIR}/startup.log start"
echo " Log saved to: $LOG_FILE"
echo " Completed at: $(date)"
echo "======================================"
