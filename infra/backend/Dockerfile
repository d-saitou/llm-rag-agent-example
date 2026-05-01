# 変数定義(デフォルト値) ※参照：https://hub.docker.com/_/python/tags
ARG BACKEND_PYTHON_VERSION=3.12-slim-bookworm

# イメージ指定
FROM python:${BACKEND_PYTHON_VERSION}

# ビルド引数定義
ARG APP_UID=9999
ARG APP_GID=9999
ARG APP_USER=appuser
ARG APP_GROUP=appgroup

# 環境変数設定
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app/backend \
    UV_PROJECT_ENVIRONMENT=/.venv \
    PATH="/.venv/bin:$PATH"

# uv インストール
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# git インストール(開発用)
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

# アプリケーションユーザー作成
RUN groupadd -g ${APP_GID} ${APP_GROUP} && \
    useradd -m -u ${APP_UID} -g ${APP_GROUP} -s /bin/bash ${APP_USER}

# 作業ディレクトリ設定
WORKDIR /app/backend

# アプリケーション・仮想環境ディレクトリ作成および権限設定 ※root 直下のため root 権限が必要
RUN mkdir -p /app/backend /.venv && \
    chown -R ${APP_USER}:${APP_GROUP} /app/backend /.venv

# アプリケーションユーザー切替
USER ${APP_USER}

# 依存関係インストール(レイヤーキャッシュ有効化)
COPY --chown=${APP_USER}:${APP_GROUP} backend/pyproject.toml backend/uv.lock ./
RUN uv sync --frozen

# アプリケーションコピー(本番用) ※開発環境はボリュームマウントによるホットリロード運用としている
COPY --chown=${APP_USER}:${APP_GROUP} backend/ ./

# 起動コマンド(本番用)
CMD [ "uv", "run", "uvicorn", "server.main:app", "--host", "0.0.0.0", "--port", "8000" ]
