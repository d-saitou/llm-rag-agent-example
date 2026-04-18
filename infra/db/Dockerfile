# 変数定義(デフォルト値) ※参照：https://hub.docker.com/r/pgvector/pgvector/tags
ARG DB_PGVECTOR_VERSION=0.8.2-pg17-trixie

# イメージ指定
FROM pgvector/pgvector:${DB_PGVECTOR_VERSION}

# ロケールインストール
RUN apt-get update && \
    apt-get install -y locales && \
    localedef -i ja_JP -c -f UTF-8 -A /usr/share/locale/locale.alias ja_JP.UTF-8 && \
    rm -rf /var/lib/apt/lists/*

# 環境変数ロケール指定
ENV LANG ja_JP.UTF-8
ENV LC_ALL ja_JP.UTF-8

# 初期化スクリプトコピー・実行権限付与
COPY ./infra/db/initdb.d/* /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/*.sh
