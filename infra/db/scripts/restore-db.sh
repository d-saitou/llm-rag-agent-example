#!/bin/bash
# Name:
#   DB リストアスクリプト
# Description:
#   pg_restore を用いた DB リストアを実行する
# Usage:
#   ./restore-db.sh <DB名> <バックアップファイルパス>

# 定数定義
readonly SCRIPT_NAME=$(basename "$0")
readonly REPOSITORY_DIR="$(cd "$(dirname "$0")/../../../"; pwd)"
readonly BACKUP_HOST_BASE_DIR="${REPOSITORY_DIR}/data/db/backups/postgres"
readonly BACKUP_CONT_BASE_DIR="/var/backups/postgres"

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
#   入力値チェック (引数必須チェック、バックアップファイル存在チェック、バックアップファイル指定チェック)
# Arguments:
#   $1 - DB名
#   $2 - バックアップファイルパス
# Returns:
#   なし
validate_args() {
  local db_name="${1}"
  local backup_file="${2}"

  # 引数必須チェック
  if [ -z "${db_name}" ] || [ -z "${backup_file}" ]; then
    echo "Error: 引数を指定してください。" >&2
    echo "Usage: $0 <DB名> <バックアップファイルパス>" >&2
    exit 1
  fi

  # バックアップファイル存在チェック
  if [ ! -f "${backup_file}" ]; then
    echo "Error: バックアップファイルが見つかりません。(${backup_file})" >&2
    exit 1
  fi

  # バックアップファイル指定チェック
  local abs_path=$(realpath "${backup_file}")
  if [[ ! "${abs_path}" =~ ^"${BACKUP_HOST_BASE_DIR}" ]]; then
    echo "Error: DBコンテナにマウントするバックアップディレクトリ配下のファイルを指定してください。(${BACKUP_HOST_BASE_DIR})" >&2
    exit 1
  fi
}

# Description:
#   DBリストア実行
# Arguments:
#   $1 - DB名
#   $2 - バックアップファイルパス
# Returns:
#   なし
restore_database() {
  local db_name="${1}"
  local host_backup_file="${2}"

  # バックアップファイルパス取得(ホスト側絶対パス取得 → コンテナ内絶対パス変換)
  local abs_host_path=$(realpath "${host_backup_file}")
  local cont_backup_file="${BACKUP_CONT_BASE_DIR}/${abs_host_path#$BACKUP_HOST_BASE_DIR/}"

  # DBリストア実行(コンテナ内 pg_restore 実行。-c:既存オブジェクトを削除, --if-exists:削除時エラー抑制)
  output_log "INFO" "DBリストア開始 (${db_name})"
  output_log "INFO" " ホスト側ファイルパス   : ${abs_host_path}"
  output_log "INFO" " コンテナ側ファイルパス : ${cont_backup_file}"
  if docker exec -i "postgres" bash -c "pg_restore -U postgres -d ${db_name} -c --if-exists ${cont_backup_file}"; then
    output_log "INFO" "DBリストア成功 (${db_name})"
    return 0
  else
    output_log "ERROR" "DBリストア失敗 (${db_name})"
    return 1
  fi
}

# Description:
#   メイン処理
# Arguments:
#   $1 - DB名
#   $2 - バックアップファイルパス
# Returns:
#   なし
main() {
  local db_name="${1}"
  local backup_file="${2}"
  validate_args "${db_name}" "${backup_file}"
  if restore_database "${db_name}" "${backup_file}"; then
    exit 0
  else
    exit 1
  fi
}

main "${1}" "${2}"
