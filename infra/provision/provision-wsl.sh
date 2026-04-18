#!/bin/bash
# Name:
#   LLM・RAG エージェント開発環境 WSL インスタンスプロビジョニングスクリプト
# Description:
#   以下の開発環境構築処理を実行する：
#   1. システム要件チェック (root 権限、.env ファイル存在確認)
#   2. Ansible インストール (未インストール時のみ)
#   3. yq インストール (未インストール時のみ)
#   4. .env → Ansible group_vars 変換
#   5. Ansible Playbook (site.yml) 実行
# Usage:
#   ./provision.sh
# Note:
#   - 実行前に プロジェクトルート/.env ファイルを作成し、ユーザー情報等を環境に合わせて変更すること。
#   - root 権限で実行すること。
set -euo pipefail

# 変数定義
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
ENV_PATH="${SCRIPT_DIR}/../../.env"
ANSIBLE_GROUP_VARS_PATH="${ANSIBLE_DIR}/group_vars/all.yml"

# Description:
#   ログメッセージコンソール出力 (例: [2026-04-01 12:00:00][INFO] メッセージ)
# Arguments:
#   $1 - ログレベル (INFO、ERROR、等)
#   $2 - メッセージ
# Returns: なし
output_log() {
  local LVL="$1"
  local MSG="$2"
  local TS="$(date "+%Y/%m/%d %H:%M:%S")"
  local LOG_MSG="[${TS}][${LVL}][${SCRIPT_NAME}] ${MSG}"
  if [ "${LVL}" = "ERROR" ]; then
    echo "${LOG_MSG}" >&2
  else
    echo "${LOG_MSG}"
  fi
}

# Description:
#   システム要件チェック (root 権限、.env ファイル存在確認)
# Arguments:
#   なし
# Returns:
#   なし
test_system_requirements() {
  # 実行ユーザー判定
  if [ "$(id -u)" -ne 0 ]; then
    output_log "ERROR" "root 権限で実行してください"
    exit 1
  fi

  # .env ファイル存在確認
  if [ ! -f "${ENV_PATH}" ]; then
    output_log "ERROR" "${ENV_PATH} が見つかりません"
    exit 1
  fi
}

# Description: Ansible インストール (未インストール時のみ)
# Arguments:
#   なし
# Returns:
#   なし
install_ansible() {
  if ! command -v ansible >/dev/null 2>&1; then
    output_log "INFO" "Ansible インストール..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y ansible
  fi
}

# Description: yq インストール (未インストール時のみ)
# Arguments:
#   なし
# Returns:
#   なし
install_yq() {
  if ! command -v yq >/dev/null 2>&1; then
    output_log "INFO" "yq インストール..."
    local YQ_DOWNLOAD_URL=$(grep "^YQ_DOWNLOAD_URL=" "${ENV_PATH}" | cut -d'=' -f2- | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
    YQ_DOWNLOAD_URL=${YQ_DOWNLOAD_URL:-"https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64"}
    wget -q "${YQ_DOWNLOAD_URL}" -O /usr/bin/yq
    chmod +x /usr/bin/yq
  fi
}

# Description: .env → Ansible group_vars 変換
# Arguments:
#   なし
# Returns:
#   なし
convert_env_to_ansible() {
  output_log "INFO" ".env → Ansible group_vars 変換..."
  mkdir -p "$(dirname "${ANSIBLE_GROUP_VARS_PATH}")"
  sed 's/\\/\\\\/g' "${ENV_PATH}" | yq eval-all -p=props -oy 'with_entries(.key |= downcase)' - > "${ANSIBLE_GROUP_VARS_PATH}"

  local ANSIBLE_DIR_OWNER_GROUP="$(stat -c '%U:%G' "${ANSIBLE_DIR}")"
  chown "${ANSIBLE_DIR_OWNER_GROUP}" "${ANSIBLE_GROUP_VARS_PATH}"
}

# Description: Ansible Playbook (site.yml) 実行
# Arguments:
#   なし
# Returns:
#   なし
run_ansible_playbook() {
  output_log "INFO" "Ansible playbook 実行..."
  cd "${ANSIBLE_DIR}" || exit 1
  ansible-playbook -i inventory site.yml
}

# Description:
#   メイン処理
# Arguments:
#   なし
# Returns:
#   なし
main() {
  test_system_requirements

  output_log "INFO" "セットアップ開始..."
  install_ansible
  install_yq
  convert_env_to_ansible
  run_ansible_playbook
  output_log "INFO" "セットアップ完了"
}

main
