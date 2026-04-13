#!/bin/bash
set -e

# 各ユーザーパスワード読み込み ※改行がある場合除去
APP_TX_USER_PASSWORD=$(cat /run/secrets/db_app_tx_user | tr -d '\n\r')
APP_RAG_USER_PASSWORD=$(cat /run/secrets/db_app_rag_user | tr -d '\n\r')
REDMINE_USER_PASSWORD=$(cat /run/secrets/db_redmine_user | tr -d '\n\r')

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER}" --dbname "${POSTGRES_DB}" <<-EOSQL
  -- ユーザー作成
  CREATE USER app_tx WITH PASSWORD '${APP_TX_USER_PASSWORD}';
  CREATE USER app_rag WITH PASSWORD '${APP_RAG_USER_PASSWORD}';
  CREATE USER redmine WITH PASSWORD '${REDMINE_USER_PASSWORD}';

  -- データベース作成
  CREATE DATABASE app_tx_db OWNER app_tx;
  CREATE DATABASE app_rag_db OWNER app_rag;
  CREATE DATABASE redmine_db OWNER redmine;

  -- 拡張機能導入
  \c app_rag_db
  CREATE EXTENSION IF NOT EXISTS vector;
EOSQL
