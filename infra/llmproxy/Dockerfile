# ========================================
# ビルド引数定義
# ========================================
ARG LLMPROXY_PYTHON_VERSION=3.12-slim-bookworm
ARG LLMPROXY_LITELLM_VERSION=1.40.14
ARG APP_UID=9999
ARG APP_GID=9999
ARG APP_USER=appuser
ARG APP_GROUP=appgroup

# ========================================
# 開発環境コンテナ
# ========================================
FROM python:${LLMPROXY_PYTHON_VERSION}

ARG LLMPROXY_LITELLM_VERSION
ARG APP_UID
ARG APP_GID
ARG APP_USER
ARG APP_GROUP

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

RUN apt-get update && \
    apt-get install -y --no-install-recommends tini && \
    rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip && \
    pip install "litellm[proxy]==${LLMPROXY_LITELLM_VERSION}"

COPY infra/llmproxy/scripts/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN groupadd -g ${APP_GID} ${APP_GROUP} && \
    useradd -m -u ${APP_UID} -g ${APP_GROUP} -s /bin/bash ${APP_USER} && \
    chown -R ${APP_USER}:${APP_GROUP} /app && \
    chown ${APP_USER}:${APP_GROUP} /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

USER ${APP_USER}

EXPOSE 4000

ENTRYPOINT ["tini", "-g", "--", "/usr/local/bin/entrypoint.sh"]
