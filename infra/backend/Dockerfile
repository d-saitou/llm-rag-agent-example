# ========================================
# ビルド引数定義
# ========================================
ARG BACKEND_PYTHON_VERSION=3.12-slim-bookworm
ARG APP_UID=9999
ARG APP_GID=9999
ARG APP_USER=appuser
ARG APP_GROUP=appgroup

# ========================================
# ベースステージ
# ========================================
FROM python:${BACKEND_PYTHON_VERSION} AS base

ARG APP_UID
ARG APP_GID
ARG APP_USER
ARG APP_GROUP

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONPATH=/app/backend \
    UV_PROJECT_ENVIRONMENT=/.venv \
    PATH="/.venv/bin:$PATH"

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

RUN groupadd -g ${APP_GID} ${APP_GROUP} && \
    useradd -m -u ${APP_UID} -g ${APP_GROUP} -s /bin/bash ${APP_USER}

WORKDIR /app/backend

RUN mkdir -p /app/backend /.venv && \
    chown -R ${APP_USER}:${APP_GROUP} /app/backend /.venv

# ========================================
# 開発環境ステージ
# ========================================
FROM base AS development

RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

COPY --chown=${APP_USER}:${APP_GROUP} backend/pyproject.toml backend/uv.lock ./

USER ${APP_USER}

RUN uv sync --frozen

CMD ["uv", "run", "python", "-m", "debugpy", "--listen", "0.0.0.0:5678", "-m", "uvicorn", "server.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# ========================================
# 本番環境依存関係インストールステージ(サンプル)
# ========================================
FROM base AS deps

COPY --chown=${APP_USER}:${APP_GROUP} backend/pyproject.toml backend/uv.lock ./

USER ${APP_USER}

RUN uv sync --frozen --no-dev

# ========================================
# 本番環境ステージ(サンプル)
# ========================================
FROM deps AS production

COPY --chown=${APP_USER}:${APP_GROUP} backend/ ./

USER ${APP_USER}

CMD ["uv", "run", "uvicorn", "server.main:app", "--host", "0.0.0.0", "--port", "8000"]
