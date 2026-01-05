#!/bin/bash
# Script to purge PostgreSQL archive logs older than 7 days

# Define the directories where the archive logs are stored
ARCHIVE_DIRS=(
    "/FRA/archive/pa"
    "/FRA/archive/lab"
        "/FRA/archive/um"
        "/FRA/archive/account"
        "/FRA/archive/tpa"
        "/FRA/archive/pharmacy"
        "/FRA/archive/clinical"
)

# Define the base path for the log files
BASE_LOG_FILE="/FRA/archive/purge_log"

# Print the start time to each log file
for ARCHIVE_DIR in "${ARCHIVE_DIRS[@]}"; do
    # Get the name of the directory to use in the log filename
    CLUSTER_NAME=$(basename $ARCHIVE_DIR)

    # Define the log file for each cluster's purge
    LOG_FILE="${BASE_LOG_FILE}/purge_log_${CLUSTER_NAME}.log"

    # Print the start time for this particular cluster's log
    echo "Purge started for $CLUSTER_NAME at $(date)" >> $LOG_FILE

    # List of purged archive
    echo "List of purged archive: $ARCHIVE_DIR" >> $LOG_FILE
    find $ARCHIVE_DIR -type f -mtime +7 -print >> $LOG_FILE

    # Purge archive logs older than 7 days(as basebackup runs 2 days a week hence a week old archives are retained for safer approach)
    echo "Purging archive logs in directory: $ARCHIVE_DIR" >> $LOG_FILE
    find $ARCHIVE_DIR -type f -mtime +7 -exec rm -f {} \; >> $LOG_FILE 2>&1

    # Print result
    echo "Purge completed for $CLUSTER_NAME at $(date)" >> $LOG_FILE
    echo "" >> $LOG_FILE
done
