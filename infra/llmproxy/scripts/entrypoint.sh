#!/bin/sh
set -e

export LITELLM_MASTER_KEY=$(tr -d '\n\r' < /run/secrets/llmproxy_litellm_master_key)
export GROQ_API_KEY=$(tr -d '\n\r' < /run/secrets/llmproxy_groq_api_key)

exec litellm --config /app/config.yaml
