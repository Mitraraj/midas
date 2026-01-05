#!/bin/bash

######################################################
####                                              ####
####            Property of Midas Technologies    ####
####            Author : Mitra                    ####
####            DoC : 22nd Jan 2025               ####
####            Purpose: Daily Backup PostgreSQL  ####
####            Version: 16                       ####
####                                              ####
######################################################


# Define databases for each cluster
# Define databases for each cluster
declare -A databases

databases=(
        ["lab"]="lab"
        ["pa"]="pa"
        ["account"]="account"
        ["um"]="um"
        ["tpa"]="tpa"
        ["pharmacy"]="pharmacy"
        ["clinical"]="clinical"
)


# Define the PostgreSQL user and password
PG_USER="postgres"
#PG_PASSWORD="your_pg_password"
PG_HOST="192.168.6.228"

# Declare an associative array mapping cluster names to port numbers
declare -A clusters_ports
clusters_ports=(
    ["lab"]=5434
    ["pa"]=5435
    ["account"]=5436
    ["um"]=5437
    ["tpa"]=5438
    ["pharmacy"]=5439
    ["clinical"]=5440
)


# Directory to store backups
backup_parent_dir="/backup/daily_backup/"
timestamp=$(date +"%Y%m%d_%H%M%S")
backup_dir="$backup_parent_dir/$timestamp"



for cluster in "${!clusters_ports[@]}"; do
    # Get the port for the current cluster
    PG_PORT=${clusters_ports[$cluster]}

    # Create a directory for the cluster's backups
    CLUSTER_BACKUP_DIR="$backup_dir/$cluster"
    mkdir -p "$CLUSTER_BACKUP_DIR"
    
    # Loop through each database for the current cluster
    for db in "${databases[$cluster]}"; do
        # Set the backup file and logfile path
        LOG_FILE="$backup_parent_dir/backuplog/${db}_${timestamp}.log"
        echo "Log file: $LOG_FILE"
        BACKUP_FILE="$CLUSTER_BACKUP_DIR/${db}_${timestamp}.dump"
        echo "Backup file: $BACKUP_FILE" >> $LOG_FILE

        # Run pg_dump to take the backup
        echo "Backing up database $db from cluster $cluster on port $PG_PORT started on: $timestamp" >> $LOG_FILE
        pg_dump -h $PG_HOST -p $PG_PORT -U $PG_USER -F c -b -v -f "$BACKUP_FILE" $db >> "$LOG_FILE" 2>&1

        # Check if pg_dump was successful
        if [[ $? -eq 0 ]]; then
            echo "Backup Successful: Backup for database $db completed successfully." >> $LOG_FILE
        else
            echo "Backup Failure: Error backing up database $db." >> $LOG_FILE
        fi
    done
done

# Create tar.gz file
tar_gz_file="$backup_parent_dir/backup_${timestamp}.tar.gz"
tar -czvf "$tar_gz_file" -C "$backup_parent_dir" "$timestamp"
