#!/bin/bash
# Name:
#   DB バックアップスクリプト
# Description:
#   pg_dump を用いた DB バックアップを実行する (app_tx_db, app_rag_db, redmine_db)
# Usage:
#   ./backup-db.sh

# 定数定義
readonly SCRIPT_NAME=$(basename "$0")
readonly REPOSITORY_DIR="$(cd "$(dirname "$0")/../../../"; pwd)"
readonly TIMESTAMP="$(date "+%Y%m%d_%H%M%S")"
readonly BACKUP_HOST_TARGET_DIR="${REPOSITORY_DIR}/data/db/backups/postgres/${TIMESTAMP}"
readonly BACKUP_CONT_TARGET_DIR="/var/backups/postgres/${TIMESTAMP}"

# Description:
#   ログメッセージコンソール出力 (例: [2026-04-01 12:00:00][INFO] メッセージ)
# Arguments:
#   $1 - ログレベル (INFO、ERROR、等)
#   $2 - メッセージ
# Returns:
#   なし
output_log() {
  local level="${1}"
  local message="${2}"
  local timestamp="$(date "+%Y/%m/%d %H:%M:%S")"
  local log_msg="[${timestamp}][${level}][${SCRIPT_NAME}] ${message}"
  if [ "${level}" = "ERROR" ]; then
    echo "${log_msg}" >&2
  else
    echo "${log_msg}"
  fi
}

# Description:
#   DBバックアップディレクトリ作成
# Arguments:
#   なし
# Returns:
#   なし
create_backup_dir() {
  mkdir -p "${BACKUP_HOST_TARGET_DIR}"
  chmod 700 "${BACKUP_HOST_TARGET_DIR}"
}

# Description:
#   DBバックアップ
# Arguments:
#   $1 - データベース名
# Returns:
#   0: バックアップ成功, 1: バックアップ失敗
backup_database() {
  local db_name="${1}"
  output_log "INFO" "DBバックアップ開始(${db_name})..."
  if docker exec -i postgres bash -c "pg_dump -U postgres -d ${db_name} -Fc > ${BACKUP_CONT_TARGET_DIR}/${db_name}.dump"; then
    output_log "INFO" "DBバックアップ成功(${db_name} : ${BACKUP_HOST_TARGET_DIR}/${db_name}.dump)"
    return 0
  else
    output_log "ERROR" "DBバックアップ失敗(${db_name})"
    return 1
  fi
}

# Description:
#   メイン処理
# Arguments:
#   なし
# Returns:
#   なし
main() {
  local error_found=0
  create_backup_dir
  backup_database "app_tx_db" || error_found=1
  backup_database "app_rag_db" || error_found=1
  backup_database "redmine_db" || error_found=1
  if [ ${error_found} -eq 0 ]; then
    exit 0
  else
    exit 1
  fi
}

main
