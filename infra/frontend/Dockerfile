# ========================================
# ビルド引数定義
# ========================================
ARG FRONTEND_NODE_VERSION=22-bookworm-slim
ARG APP_UID=9999
ARG APP_GID=9999
ARG APP_USER=appuser
ARG APP_GROUP=appgroup

# ========================================
# ベースステージ
# ========================================
FROM node:${FRONTEND_NODE_VERSION} AS base

ARG APP_UID
ARG APP_GID
ARG APP_USER
ARG APP_GROUP

WORKDIR /app/frontend

RUN groupadd -g ${APP_GID} ${APP_GROUP} && \
    useradd -m -u ${APP_UID} -g ${APP_GROUP} -s /bin/bash ${APP_USER} && \
    chown -R ${APP_USER}:${APP_GROUP} /app

# ========================================
# 依存関係インストールステージ
# ========================================
FROM base AS deps

COPY --chown=${APP_USER}:${APP_GROUP} frontend/package*.json ./

USER ${APP_USER}

RUN npm ci

# ========================================
# 開発環境ステージ
# ========================================
FROM deps AS development

ENV NODE_ENV=development \
    CHOKIDAR_USEPOLLING=true \
    WATCHPACK_POLLING=true \
    PORT=3000

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /app/frontend/.next && \
    chown ${APP_USER}:${APP_GROUP} /app/frontend/.next

USER ${APP_USER}

EXPOSE 3000 9229

CMD ["npm", "run", "dev", "--", "--hostname", "0.0.0.0", "--inspect=0.0.0.0:9229"]

# ========================================
# 本番環境アプリビルドステージ(サンプル)
# ========================================
FROM base AS builder

ENV NODE_ENV=production

COPY --from=deps --chown=${APP_USER}:${APP_GROUP} /app/frontend/node_modules ./node_modules
COPY --chown=${APP_USER}:${APP_GROUP} frontend/ ./

USER ${APP_USER}

RUN npm run build

# ========================================
# 本番環境ステージ(サンプル)
# ========================================
FROM node:${FRONTEND_NODE_VERSION} AS production

ARG APP_UID
ARG APP_GID
ARG APP_USER
ARG APP_GROUP

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app/frontend

RUN groupadd -g ${APP_GID} ${APP_GROUP} && \
    useradd -m -u ${APP_UID} -g ${APP_GROUP} -s /usr/sbin/nologin ${APP_USER} && \
    chown -R ${APP_USER}:${APP_GROUP} /app

# frontend/next.config.js で output: 'standalone' を指定
COPY --from=builder --chown=${APP_USER}:${APP_GROUP} /app/frontend/.next/standalone ./
COPY --from=builder --chown=${APP_USER}:${APP_GROUP} /app/frontend/.next/static ./.next/static
COPY --from=builder --chown=${APP_USER}:${APP_GROUP} /app/frontend/public ./public

USER ${APP_USER}

EXPOSE 3000

CMD ["node", "server.js"]
