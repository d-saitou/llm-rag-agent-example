#!/bin/bash
# Name:
#   Redmine 初期設定スクリプト
# Description:
#   以下の Redmine 初期設定を実行する：
#   1. Redmine 起動待機
#   2. Redmine 日本語初期データロード
#   3. Redmine REST API 有効化
#   4. Redmine API キー登録
# Usage:
#   ./initialize.sh
set -e

# 定数定義
readonly SCRIPT_NAME=$(basename "$0") # 追加
readonly SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
readonly MAX_RETRIES=30
readonly SLEEP_SEC=5

# Description:
#   ログメッセージコンソール出力 (例: [2026-04-01 12:00:00][INFO] メッセージ)
# Arguments:
#   $1 - ログレベル (INFO、ERROR、等)
#   $2 - メッセージ
# Returns: なし
output_log() {
  local lvl="$1"
  local msg="$2"
  local ts="$(date "+%Y/%m/%d %H:%M:%S")"
  local log_msg="[${ts}][${lvl}][${SCRIPT_NAME}] ${msg}"

  if [ "${lvl}" = "ERROR" ]; then
    echo "${log_msg}" >&2
  else
    echo "${log_msg}"
  fi
}

# Description:
#   Redmine 起動待機 (最大 ${MAX_RETRIES} 回、${SLEEP_SEC} 秒間隔)
# Arguments:
#   なし
# Returns:
#   なし
wait_for_redmine() {
  output_log "INFO" "Redmine 起動待機..."

  local retry_count=0
  local is_ready=false

  while [ ${retry_count} -lt ${MAX_RETRIES} ]; do
    if docker compose logs redmine 2>&1 | grep -q "Listening on http://0.0.0.0:3000"; then
      is_ready=true
      break
    fi

    if ! docker compose ps redmine | grep -q "Up"; then
      output_log "ERROR" "Redmine コンテナ起動失敗"
      exit 1
    fi

    output_log "INFO" "Redmine 起動待機中... ($((retry_count * SLEEP_SEC)) 秒 / $((MAX_RETRIES * SLEEP_SEC)) 秒)"
    retry_count=$((retry_count + 1))
    sleep ${SLEEP_SEC}
  done

  if [ "${is_ready}" = false ]; then
    output_log "ERROR" "Redmine 起動タイムアウト ($((MAX_RETRIES * SLEEP_SEC)) 秒)"
    exit 1
  fi
}

# Description:
#   Redmine 日本語初期データロード
# Arguments:
#   なし
# Returns:
#   なし
load_default_data() {
  output_log "INFO" "Redmine 日本語初期データロード..."
  # 既にデータが存在する場合のエラー回避のため`|| true`を付加
  docker compose exec redmine bundle exec rake redmine:load_default_data RAILS_ENV=production REDMINE_LANG=ja || true
}

# Description:
#   Redmine REST API 有効化
# Arguments:
#   なし
# Returns:
#   なし
enable_rest_api() {
  output_log "INFO" "Redmine REST API 有効化..."
  docker compose exec redmine bundle exec rails runner "Setting.rest_api_enabled = '1'"
}

# Description:
#   Redmine API キー登録
# Arguments:
#   なし
# Returns:
#   なし
register_api_key() {
  output_log "INFO" "Redmine API キー登録..."
  local api_key_path="${SCRIPT_DIR}/../secrets/redmine_api.key"

  if [ ! -f "${api_key_path}" ]; then
    output_log "ERROR" "API キーが見つかりません: ${api_key_path}"
    exit 1
  fi

  local api_key=$(cat "${api_key_path}" | tr -d '\n\r')
  docker compose exec -e REDMINE_API_KEY="${api_key}" redmine bundle exec rails runner "
    user = User.find_by_login('admin')
    token = Token.find_or_initialize_by(user_id: user.id, action: 'api')
    token.value = ENV['REDMINE_API_KEY']
    token.save!
    puts 'Redmine API キー登録完了'
  "
}

# Description:
#   メイン処理
# Arguments:
#   なし
# Returns:
#   なし
main() {
  output_log "INFO" "Redmine 初期設定開始..."

  wait_for_redmine
  load_default_data
  enable_rest_api
  register_api_key

  output_log "INFO" "Redmine 初期設定完了"
}

main
