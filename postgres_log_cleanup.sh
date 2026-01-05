#!/bin/bash

# ==============================================================
#   PostgreSQL Log Cleanup Script — Deletes logs > 60 days old
# ==============================================================

clusters=("pa" "lab" "tpa" "um" "account" "pharmacy" "clinical")

for c in "${clusters[@]}"; do
    log_dir="/data/16/$c/log"
    pattern="postgresql-$c-*.log"

    if [ -d "$log_dir" ]; then
        echo "Cleaning logs for cluster: $c in $log_dir"
        find "$log_dir" -type f -name "$pattern" -mtime +60 -exec rm -f {} \;
    else
        echo "Log directory not found: $log_dir"
    fi
done
