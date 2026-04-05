#!/bin/bash
#
# Name: LLM・RAG エージェント開発環境 WSL インスタンスプロビジョニングスクリプト
# Description:
#   以下の開発環境構築処理を実行する：
#   1. Ansible インストール
#   2. yq インストール
#   3. .env → Ansible group_vars 変換
#   4. Ansible playbook 実行
# Usage: ./provision.sh
# Note:
#   - 実行前に プロジェクトルート/.env ファイルを作成し、ユーザー情報等を環境に合わせて変更すること。
#   - root 権限で実行すること。
#
set -eu

# 変数定義
SCRIPT_NAME=$(basename "$0")
SCRIPT_DIR=$(cd "$(dirname "$0")"; pwd)
ANSIBLE_DIR="${SCRIPT_DIR}/ansible"
INPUT_ENV="${SCRIPT_DIR}/../../.env"
OUTPUT_YML="${ANSIBLE_DIR}/group_vars/all.yml"

log() {
  local LVL="$1"
  local MSG="$2"
  local TS=$(date "+%Y/%m/%d %H:%M:%S")
  echo "[${TS}][${LVL}][${SCRIPT_NAME}] ${MSG}"
}

# 実行ユーザー判定
if [ "$(id -u)" -ne 0 ]; then
  log "ERROR" "root 権限で実行してください"
  exit 1
fi

# .env ファイル存在確認
if [ ! -f "${INPUT_ENV}" ]; then
  log "ERROR" "${INPUT_ENV} が見つかりません"
  exit 1
fi

log "INFO" "セットアップ開始..."

# Ansible インストール
if ! command -v ansible >/dev/null 2>&1; then
  log "INFO" "Ansible インストール..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y ansible
fi

# yq インストール
if ! command -v yq >/dev/null 2>&1; then
  log "INFO" "yq インストール..."
  wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
  chmod +x /usr/bin/yq
fi

# .env → Ansible group_vars 変換 ※sed でバックスラッシュをエスケープしてから yq で変換
log "INFO" ".env → Ansible group_vars 変換..."
mkdir -p "$(dirname "${OUTPUT_YML}")"
sed 's/\\/\\\\/g' "${INPUT_ENV}" | yq eval-all -p=props -oy 'with_entries(.key |= downcase)' - > "${OUTPUT_YML}"
ANSIBLE_DIR_OWNER=$(stat -c '%U' "${ANSIBLE_DIR}")
chown "${ANSIBLE_DIR_OWNER}:${ANSIBLE_DIR_OWNER}" "${OUTPUT_YML}"

# Ansible playbook 実行
log "INFO" "Ansible playbook 実行..."
cd "${ANSIBLE_DIR}" || exit 1
ansible-playbook -i inventory site.yml

log "INFO" "セットアップ完了"
