#!/bin/bash

set -euo pipefail

# === Input Validation ===
if [[ $# -ne 1 ]]; then
  echo " Usage: $0 <cluster_name>"
  exit 1
fi

CLUSTER_NAME="$1"
# === Logging Setup ===
LOG_FILE="/var/log/create_pg_cluster_service.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

PG_VERSION="16"
DATA_DIR="/var/lib/postgresql/${PG_VERSION}/${CLUSTER_NAME}"
SERVICE_FILE="/etc/systemd/system/postgresql@${CLUSTER_NAME}.service"

echo "======================================"
echo " Creating systemd service for PostgreSQL cluster: $CLUSTER_NAME"
echo " $(date)"
echo "======================================"

# === Create systemd service unit file ===
echo " Writing service file to $SERVICE_FILE"

sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=PostgreSQL database server (${CLUSTER_NAME})
After=network.target

[Service]
Type=forking
User=postgres
Group=postgres
Environment=PGDATA=${DATA_DIR}
ExecStart=/usr/lib/postgresql/${PG_VERSION}/bin/pg_ctl -D ${DATA_DIR} start
ExecStop=/usr/lib/postgresql/${PG_VERSION}/bin/pg_ctl -D ${DATA_DIR} stop
ExecReload=/usr/lib/postgresql/${PG_VERSION}/bin/pg_ctl -D ${DATA_DIR} reload
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

# === Reload systemd to pick up new service ===
echo " Reloading systemd daemon..."
sudo systemctl daemon-reload

# === Enable service to start on boot ===
echo " Enabling service postgresql@${CLUSTER_NAME}.service"
sudo systemctl enable postgresql@"${CLUSTER_NAME}".service

# === Optionally Start the Service Immediately ===
echo " Starting PostgreSQL service for cluster '$CLUSTER_NAME'..."
sudo systemctl start postgresql@"${CLUSTER_NAME}".service

echo " Done! PostgreSQL cluster '$CLUSTER_NAME' service is created, enabled and started."
echo "======================================"
