# 変数定義(デフォルト値) ※参照：https://hub.docker.com/_/redmine/tags
ARG REDMINE_VERSION=6-alpine

# イメージ指定
FROM redmine:${REDMINE_VERSION}

USER root

# PDF出力用日本語フォント および タイムゾーンデータ インストール
RUN apk update && \
    apk add --no-cache font-noto-cjk tzdata

# タイムゾーン設定
ENV TZ Asia/Tokyo

USER redmine
