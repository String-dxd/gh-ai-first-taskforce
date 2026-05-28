#!/bin/sh
# AI pre-push review — installed by harness. Edit .harness.yml to configure.
set -e

# --- Skip escape hatch ---
if [ "${HARNESS_AI_REVIEW_SKIP:-0}" = "1" ]; then
  echo "harness: ai-review skipped (HARNESS_AI_REVIEW_SKIP=1)"
  exit 0
fi

# --- Prerequisites ---
command -v claude >/dev/null 2>&1 \
  || { echo "harness: ai-review skipped (claude CLI not found)"; exit 0; }

# --- Configuration ---
HARNESS_AI_MODEL="${HARNESS_AI_MODEL:-claude-sonnet-4-6}"
MAX_DIFF_BYTES="${HARNESS_AI_REVIEW_MAX_DIFF:-102400}"

# --- Resolve repo root (prefer _HARNESS_ROOT from caller for worktree correctness) ---
repo_root="${_HARNESS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
if [ -z "$repo_root" ]; then
  echo "harness: ai-review skipped (unable to resolve repository root)" >&2
  exit 0
fi

# --- Detect base ref ---
detect_base() {
  # 1. Upstream tracking branch
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null) && echo "$upstream" && return

  # 2. Remote HEAD (e.g. origin/main or origin/master)
  remote_head=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/||') \
    && [ -n "$remote_head" ] && echo "$remote_head" && return

  # 3. Probe common names
  for candidate in origin/main origin/master; do
    git rev-parse --verify "$candidate" >/dev/null 2>&1 && echo "$candidate" && return
  done

  echo ""
}

base=$(detect_base)
if [ -z "$base" ]; then
  echo "harness: ai-review skipped (unable to determine base branch)" >&2
  exit 0
fi

# --- Generate diff ---
diff=$(git diff "$base"..HEAD -- . \
  ':(exclude)**/*.lock' \
  ':(exclude)**/package-lock.json' \
  ':(exclude)**/go.sum' \
  ':(exclude)**/*.generated.*' \
  ':(exclude)**/dist/**' \
  ':(exclude)**/review/**' \
  2>/dev/null)

[ -n "$diff" ] \
  || { echo "harness: ai-review skipped (no diff to review)"; exit 0; }

# --- Truncate if too large ---
diff_truncated=""
diff_size=$(printf '%s' "$diff" | wc -c | tr -d ' ')
if [ "$diff_size" -gt "$MAX_DIFF_BYTES" ]; then
  diff=$(printf '%s' "$diff" | head -c "$MAX_DIFF_BYTES")
  diff_truncated="(truncated to ${MAX_DIFF_BYTES} bytes — full diff was ${diff_size} bytes)"
fi

# --- Build prompt in a temp file (avoids ARG_MAX issues) ---
prompt_file=$(mktemp)
trap 'rm -f "$prompt_file"' EXIT

cat > "$prompt_file" <<PROMPT
Review the following git diff for bugs, logic errors, and code quality issues.

For each finding, output a line in this format:
  [severity] file:line — description

Severity levels: ERROR (likely bug), WARN (potential issue), INFO (suggestion).
Be concise — max 1 sentence per finding. If the diff looks fine, say "No issues found."
${diff_truncated:+
Note: $diff_truncated}

---
$diff
PROMPT

# --- Run review ---
sha=$(git rev-parse --short HEAD)
branch=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')
today=$(date +%Y-%m-%d)
review_dir="$repo_root/review"
review_file="$review_dir/${today}-${branch}-${sha}.md"

echo "harness: running AI pre-push review (model: $HARNESS_AI_MODEL)..."
stderr_file=$(mktemp)
set +e
review=$(claude --model "$HARNESS_AI_MODEL" -p /dev/stdin < "$prompt_file" 2>"$stderr_file")
review_status=$?
set -e

rm -f "$prompt_file"
trap 'rm -f "$stderr_file"' EXIT

stderr_output=$(cat "$stderr_file")
rm -f "$stderr_file"
trap - EXIT

# Check for token limit errors in both stderr and stdout (claude may report in either)
combined_output="$stderr_output $review"
token_error=""
if printf '%s' "$combined_output" | grep -qiE "token.*(limit|exceed|max)|context.*(length|window|limit)|too (long|large)|max.*token|input.*too|prompt.*too|exceeds.*maximum"; then
  token_error=1
fi

if [ "$review_status" -ne 0 ]; then
  if [ "$token_error" = "1" ]; then
    echo "harness: ai-review failed — diff exceeds model token limit" >&2
    echo "harness: try reducing diff size or setting a lower HARNESS_AI_REVIEW_MAX_DIFF" >&2
    [ -n "$stderr_output" ] && echo "harness: error: $stderr_output" >&2
    [ -n "$review" ] && echo "harness: output: $review" >&2
    exit 1
  fi

  echo "harness: ai-review: claude exited $review_status — review skipped" >&2
  [ -n "$stderr_output" ] && echo "harness: $stderr_output" >&2
  [ -n "$review" ] && echo "harness: $review" >&2
  exit 0
fi

# Also check successful exit but with token warning in output
if [ "$token_error" = "1" ]; then
  echo "harness: ai-review failed — response indicates token limit was hit" >&2
  [ -n "$review" ] && echo "harness: output: $review" >&2
  exit 1
fi

echo "$review"

# --- Save review file ---
mkdir -p "$review_dir"
cat > "$review_file" <<EOF
# AI Pre-Push Review

**Date:** $today
**Branch:** $branch
**Commit:** $sha
**Model:** $HARNESS_AI_MODEL
**Base:** $base

---

$review
EOF

echo "harness: review saved to $review_file"
