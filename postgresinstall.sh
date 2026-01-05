#!/bin/bash

# Enable strict mode
set -euo pipefail

# Define log file
LOG_FILE="/var/log/install_postgresql16.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Start logging (tee writes output to both terminal and log file)
exec > >(tee -a "$LOG_FILE") 2>&1

echo "======================================"
echo " PostgreSQL 16 Installation Started"
echo " $(date)"
echo "======================================"

echo " Updating system packages and installing dependencies..."
sudo apt update
sudo apt install -y curl ca-certificates lsb-release gnupg

echo " Creating directory for PostgreSQL GPG key..."
sudo install -d /usr/share/postgresql-common/pgdg

echo " Downloading PostgreSQL GPG key..."
curl -sSf -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc

echo " Adding PostgreSQL APT repository..."
sudo sh -c "echo 'deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main' > /etc/apt/sources.list.d/pgdg.list"

echo " Updating package list after adding PostgreSQL repo..."
sudo apt update

echo " Installing PostgreSQL 16..."
sudo apt install -y postgresql-16

echo " (Optional) Installing PostgreSQL 16 development headers..."
sudo apt install -y postgresql-server-dev-16



echo "======================================"
echo " PostgreSQL 16 installation complete!"
echo "  Check PostgreSQL status: sudo systemctl status postgresql"
echo " Installation log saved to: $LOG_FILE"
echo " Completed at: $(date)"
echo "======================================"
