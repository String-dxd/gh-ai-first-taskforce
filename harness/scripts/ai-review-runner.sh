#!/bin/sh
# AI pre-push review — installed by harness. Edit .harness.yml to configure.
HARNESS_AI_MODEL="${HARNESS_AI_MODEL:-claude-sonnet-4-6}"
HARNESS_AI_KEY_VAR="${HARNESS_AI_KEY_VAR:-ANTHROPIC_API_KEY}"

_harness_ai_review() {
  command -v claude >/dev/null 2>&1 \
    || { echo "harness: ai-review skipped (claude CLI not found)"; return 0; }

  eval "api_key=\${${HARNESS_AI_KEY_VAR}:-}"
  [ -n "$api_key" ] \
    || { echo "harness: ai-review skipped ($HARNESS_AI_KEY_VAR not set)"; return 0; }
}

_harness_ai_review
