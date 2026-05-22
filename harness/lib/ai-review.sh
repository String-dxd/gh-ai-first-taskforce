# parse_harness_config <repo_root> <dotted_key>
# Returns a scalar value from .harness.yml at <repo_root>.
# Handles two-level dotted keys: parent.leaf
# Returns empty string if file, parent section, or key is absent.
parse_harness_config() {
  local repo_root="$1" key="$2"
  local config_file="$repo_root/.harness.yml"
  [ -f "$config_file" ] || return 0

  local parent leaf
  parent="${key%%.*}"
  leaf="${key#*.}"

  awk -v parent="${parent}:" -v leaf="  ${leaf}:" '
    $0 ~ "^"parent { in_section=1; next }
    in_section && /^[^[:space:]]/ { in_section=0 }
    in_section && index($0, leaf) == 1 {
      sub(/^[^:]*:[[:space:]]*/, "")
      gsub(/^["'"'"']|["'"'"'][[:space:]]*$|[[:space:]]*$/, "")
      print
      exit
    }
  ' "$config_file"
}

# install_ai_review_runner <repo_root>
# Copies harness/scripts/ai-review-runner.sh to <repo_root>/.harness/ai-review-runner.sh.
# Requires SCRIPT_DIR pointing to the harness root (set by setup.sh or tests).
install_ai_review_runner() {
  local repo_root="$1"
  local dest="$repo_root/.harness/ai-review-runner.sh"
  local src="${SCRIPT_DIR}/scripts/ai-review-runner.sh"

  mkdir -p "$repo_root/.harness"
  cp "$src" "$dest"
  chmod +x "$dest"
}
