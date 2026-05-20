ensure_hook_exists() {
  local hook_file="$1"
  if [ ! -f "$hook_file" ]; then
    mkdir -p "$(dirname "$hook_file")"
    printf '#!/bin/sh\n' > "$hook_file"
    chmod +x "$hook_file"
  fi
}

# merge_block <hook_file> <block_id> <block_content> [position]
# position: "append" (default) | "after-shebang"
# block_content must include the # harness:<block_id>:begin / :end sentinels.
merge_block() {
  local hook_file="$1"
  local block_id="$2"
  local block_content="$3"
  local position="${4:-append}"

  if grep -qF "# harness:${block_id}:begin" "$hook_file" 2>/dev/null; then
    return 0
  fi

  if [ "$position" = "after-shebang" ]; then
    local tmp
    tmp=$(mktemp)
    head -1 "$hook_file" > "$tmp"
    printf '\n%s\n' "$block_content" >> "$tmp"
    tail -n +2 "$hook_file" >> "$tmp"
    mv "$tmp" "$hook_file"
  else
    printf '\n%s\n' "$block_content" >> "$hook_file"
  fi
}
