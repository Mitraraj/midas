#!/bin/bash

# ==========================================================
#   PostgreSQL Base Backup Script with HTML Email Report
# ==========================================================

# Define the PostgreSQL clusters and their respective ports
declare -A clusters
clusters=(
    ["pa"]=5435
    ["lab"]=5434
    ["tpa"]=5438
    ["um"]=5437
    ["account"]=5436
    ["pharmacy"]=5439
    ["clinical"]=5440
)

# Define the backup directory
BACKUP_DIR="/backup/basebackup"
LOG_DIR="/backup/basebackup/logs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Define PostgreSQL credentials
PG_USER="replicator"
PG_HOST="10.56.10.75"

# Email Configuration
TO="prakash.khatiwada@nmcth.edu.np"
CC="mitraraj.katwal@midastechnologies.com.np,Nirajan.karki@midastechnologies.com.np, nishan.thapa@midastechnologies.com.np"
FROM="support@midastechnologies.com.np"
SUBJECT="NMCTH PostgreSQL Database Base Backup Report | $(hostname)"
BODY_FILE="/tmp/basebackup_mail_body_${TIMESTAMP}.html"

# Ensure directory structure exists
mkdir -p "$BACKUP_DIR" "$LOG_DIR"

echo "========== PostgreSQL Base Backup Started: $TIMESTAMP =========="

# ----------------------------------------------------------
# Start HTML email body
# ----------------------------------------------------------
cat <<EOF > "$BODY_FILE"
<html>
<head>
  <style>
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid #999; padding: 7px; text-align: left; }
    th { background-color: #336699; color: #fff; }
    .success { color: green; font-weight: bold; }
    .failure { color: red; font-weight: bold; }
  </style>
</head>
<body>
  <h2>NMCTH PostgreSQL Database Base Backup Report</h2>
  <p><strong>Date:</strong> $(date)<br>
  <strong>Hostname:</strong> $(hostname)<br>
  <strong>IP Address:</strong> $(hostname -I | awk '{print $1}')<br>
  <strong>Retention Period:</strong> 7 days</p>

  <table>
    <tr>
      <th>Cluster</th>
      <th>Port</th>
      <th>Duration</th>
      <th>Backup Size</th>
      <th>Backup Directory</th>
      <th>Status</th>
    </tr>
EOF

# Start logging
echo "========== PostgreSQL Base Backup Started: $TIMESTAMP =========="

# Loop through each cluster and take a base backup
for cluster in "${!clusters[@]}"; do
    PORT=${clusters[$cluster]}
    CLUSTER_BACKUP_DIR="$BACKUP_DIR/$cluster/$TIMESTAMP"
    CLUSTER_LOG_FILE="$LOG_DIR/${cluster}_backup_$TIMESTAMP.log"

    echo "Starting backup for $cluster on port $PORT..." | tee -a "$CLUSTER_LOG_FILE"
    mkdir -p "$CLUSTER_BACKUP_DIR"

    # Run pg_basebackup with tablespace handling and log output
    pg_basebackup -D "$CLUSTER_BACKUP_DIR" -Fp -Xs -P -R -U "$PG_USER" -h "$PG_HOST" -p "$PORT" \
        --tablespace-mapping=/data/tablespace/${cluster}/${cluster}_tbs/data="$CLUSTER_BACKUP_DIR/${cluster}_tbs_data" \
        --tablespace-mapping=/data/tablespace/${cluster}/${cluster}_tbs/log="$CLUSTER_BACKUP_DIR/${cluster}_tbs_log" \
        >> "$CLUSTER_LOG_FILE" 2>&1

    status=$?
    end_time=$(date +%s)


    duration=$((end_time - start_time))
    human_duration=$(printf '%02d:%02d:%02d\n' $((duration/3600)) $(((duration%3600)/60)) $((duration%60)))

    if [[ $status -eq 0 ]]; then
        backup_size=$(du -sh "$CLUSTER_BACKUP_DIR" | awk '{print $1}')
        status_text="Success"
        status_class="success"
        echo "Backup for $cluster completed successfully."
    else
        backup_size="N/A"
        status_text="Failure"
        status_class="failure"
        echo "Backup for $cluster FAILED."
    fi

    # Append HTML row
    echo "<tr>
        <td>$cluster</td>
        <td>$PORT</td>
        <td>$human_duration</td>
        <td>$backup_size</td>
        <td>$CLUSTER_BACKUP_DIR</td>
        <td class=\"$status_class\">$status_text</td>
      </tr>" >> "$BODY_FILE"
done

# ----------------------------------------------------------
# Close HTML email body
# ----------------------------------------------------------
cat <<EOF >> "$BODY_FILE"
  </table>
  <br>
  <p>Check backup logs in: <b>$LOG_DIR</b></p>
</body>
</html>
EOF



# ----------------------------------------------------------
# Send email report (HTML)
# ----------------------------------------------------------
echo "Sending email report..."

{
  echo "To: $TO"
  echo "Cc: $CC"
  echo "From: $FROM"
  echo "Subject: $SUBJECT"
  echo "Content-Type: text/html"
  echo
  cat "$BODY_FILE"
} | msmtp --debug -t


# ----------------------------------------------------------
# Cleanup old backups/logs
# ----------------------------------------------------------
find "$BACKUP_DIR" -mindepth 2 -maxdepth 2 -type d -mtime +7 -exec rm -rf {} \;
find "$LOG_DIR" -type f -mtime +7 -exec rm -f {} \;

rm -f "$BODY_FILE"

echo "========== PostgreSQL Base Backup Completed: $(date +"%Y%m%d_%H%M%S") =========="
