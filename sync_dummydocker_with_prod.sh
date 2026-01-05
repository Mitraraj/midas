#!/usr/bin/env bash
set -Eeuo pipefail

### CONFIG ###
PROD_HOST="172.16.50.53"
PROD_USER="postgres"
PARENT_BACKUP_DIRECTORY="/backup/dailybackup"

DEST_BASE="/home/administrator"

# module -> container,db
# folder "um" restores to db "user_management" in container "um-db"
declare -A CONTAINER=(
  [account]="account-db"
  [bloodbank]="bloodbank-db"
  [clinical]="clinical-db"
  [inventory]="inventory-db"
  [lab]="lab-db"
  [pa]="pa-db"
  [pharmacy]="pharmacy-db"
  [tpa]="tpa-db"
  [um]="um-db"
)

declare -A DBNAME=(
  [account]="account"
  [bloodbank]="bloodbank"
  [clinical]="clinical"
  [inventory]="inventory"
  [lab]="lab"
  [pa]="pa"
  [pharmacy]="pharmacy"
  [tpa]="tpa"
  [um]="user_management"
)

# where to place dump inside container
CONTAINER_BASE="/var/lib/postgresql"

### UTIL ###
log() { printf '%s %s\n' "[$(date '+%F %T')]" "$*"; }
err() { printf '%s %s\n' "[$(date '+%F %T')][ERROR]" "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 127; }
}

### CHECKS ###
require_cmd ssh
require_cmd scp
require_cmd docker

# Quick connectivity check
log "Checking SSH connectivity to ${PROD_USER}@${PROD_HOST} ..."
ssh -o BatchMode=yes -o ConnectTimeout=10 "${PROD_USER}@${PROD_HOST}" "echo ok" >/dev/null

### 1) Get latest backup directory on production ###
log "Finding latest backup directory under ${PARENT_BACKUP_DIRECTORY} on ${PROD_HOST} ..."
LATEST_DIR_NAME="$(ssh "${PROD_USER}@${PROD_HOST}" \
  "ls -1dt ${PARENT_BACKUP_DIRECTORY}/20*/ 2>/dev/null | head -n 1 | xargs -n1 basename")"

if [[ -z "${LATEST_DIR_NAME}" ]]; then
  err "No backup directories found under ${PARENT_BACKUP_DIRECTORY} on ${PROD_HOST}"
  exit 1
fi

ACTUAL_BACKUP_DIRECTORY="${PARENT_BACKUP_DIRECTORY}/${LATEST_DIR_NAME}"
DEST_DIR="${DEST_BASE}/${LATEST_DIR_NAME}"

log "Latest backup directory: ${ACTUAL_BACKUP_DIRECTORY}"
log "Destination directory:   ${DEST_DIR}"

### 2) Copy latest backup dir to destination ###
if [[ -d "${DEST_DIR}" ]]; then
  log "Destination already exists. Removing: ${DEST_DIR}"
  rm -rf "${DEST_DIR}"
fi

log "Copying backup directory from production to destination via scp..."
scp -r "${PROD_USER}@${PROD_HOST}:${ACTUAL_BACKUP_DIRECTORY}" "${DEST_BASE}/"

if [[ ! -d "${DEST_DIR}" ]]; then
  err "Copy failed: ${DEST_DIR} does not exist after scp"
  exit 1
fi

### 3) For each module: docker cp + perms + drop/create + restore ###
overall_rc=0

for module in account bloodbank clinical inventory lab pa pharmacy tpa um; do
  container="${CONTAINER[$module]}"
  db="${DBNAME[$module]}"

  module_dir="${DEST_DIR}/${module}"
  if [[ ! -d "${module_dir}" ]]; then
    err "[${db}] Module directory missing: ${module_dir} (skipping)"
    overall_rc=1
    continue
  fi

  # find the dump file (expects exactly one; picks newest if multiple)
  dump_file="$(ls -1t "${module_dir}"/*.dump 2>/dev/null | head -n 1 || true)"
  if [[ -z "${dump_file}" ]]; then
    err "[${db}] No .dump file found in ${module_dir} (skipping)"
    overall_rc=1
    continue
  fi

  dump_basename="$(basename "${dump_file}")"
  container_target_dir="${CONTAINER_BASE}/${LATEST_DIR_NAME}"
  container_target_path="${container_target_dir}/${dump_basename}"

  log "[${db}] Using dump: ${dump_file}"
  log "[${db}] Container: ${container}"
  log "[${db}] Copying dump into container..."

  # ensure container exists and is running
  if ! docker ps --format '{{.Names}}' | grep -qx "${container}"; then
    err "[${db}] Container not running/not found: ${container}"
    overall_rc=1
    continue
  fi

  # create target dir in container
  docker exec "${container}" bash -lc "mkdir -p '${container_target_dir}'"

  # copy dump into container
  docker cp "${dump_file}" "${container}:${container_target_path}"

  # set ownership/permissions
  docker exec "${container}" bash -lc \
    "chown postgres:postgres '${container_target_path}' && chmod 775 '${container_target_path}'"

  log "[${db}] Dropping & recreating database, then restoring..."

  # 1) disable connections, terminate backends, drop & create
  # 2) run pg_restore
  # Use ON_ERROR_STOP so failures bubble up.
  if docker exec "${container}" bash -lc "
      set -Eeuo pipefail

      # Drop/Create database
      su - postgres -c \"psql -v ON_ERROR_STOP=1 -d postgres <<'SQL'
ALTER DATABASE \\\"${db}\\\" WITH ALLOW_CONNECTIONS false;
SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE datname = '${db}'
  AND pid <> pg_backend_pid();
DROP DATABASE IF EXISTS \\\"${db}\\\";
CREATE DATABASE \\\"${db}\\\";
SQL\"

      # Restore
      su - postgres -c \"pg_restore -v -d \\\"${db}\\\" '${container_target_path}'\"
    " ; then
    log "✅ [${db}] SUCCESS"
  else
    err "❌ [${db}] FAILED (see logs above)"
    overall_rc=1
  fi
done

docker exec -it um-db bash -lc \
"su - postgres -c \"psql -v ON_ERROR_STOP=1 -d user_management -c \\\"UPDATE users SET password='\\\$2y\\\$10\\\$UPYvtSgzwgVrJxdSLVDhVupW5yZqvy23UYMVLaR9/aojy6J64Jx6u' WHERE username='superadmin';\\\"\""

log "[um-app] Flushing Laravel cache..."

if docker exec um-app php artisan cache:clear >/dev/null 2>&1; then
  log "✅ [um-app] Laravel cache cleared successfully"
else
  err "❌ [um-app] Failed to clear Laravel cache"
  exit 1
fi


if [[ "${overall_rc}" -eq 0 ]]; then
  log "All databases restored successfully from ${LATEST_DIR_NAME}"
else
  err "One or more databases failed to restore from ${LATEST_DIR_NAME}"
fi

exit "${overall_rc}"
