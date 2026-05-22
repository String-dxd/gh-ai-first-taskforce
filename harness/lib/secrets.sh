# Requires merge_block() and ensure_hook_exists() from merge-hook.sh to be sourced first.

# ensure_gitleaks_available
# Returns 0 if gitleaks is in PATH. Tries brew, then go install.
# Prints an actionable error and returns 1 if no installer is available.
ensure_gitleaks_available() {
  if command -v gitleaks >/dev/null 2>&1; then
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    if ! brew install gitleaks; then
      echo "ERROR: brew install gitleaks failed. Install manually:" >&2
      echo "  brew install gitleaks" >&2
      return 1
    fi
    return 0
  fi

  if command -v go >/dev/null 2>&1; then
    if ! go install github.com/zricethezav/gitleaks/v8@latest; then
      echo "ERROR: go install gitleaks failed. Install manually:" >&2
      echo "  go install github.com/zricethezav/gitleaks/v8@latest" >&2
      return 1
    fi
    return 0
  fi

  echo "ERROR: gitleaks not found and could not be installed automatically." >&2
  echo "  macOS:  brew install gitleaks" >&2
  echo "  other:  go install github.com/zricethezav/gitleaks/v8@latest" >&2
  echo "  manual: https://github.com/gitleaks/gitleaks#installing" >&2
  return 1
}

# ensure_gitleaks_config <repo_root>
# Writes a default .gitleaks.toml if none exists.
ensure_gitleaks_config() {
  local repo_root="$1"

  if [ -f "$repo_root/.gitleaks.toml" ]; then
    return 0
  fi

  cat > "$repo_root/.gitleaks.toml" <<'EOF'
title = "gitleaks config"

[extend]
useDefault = true

# To allowlist a false positive, add an entry below:
# [allowlist]
# description = "describe what is being allowed"
# paths = ['''path/to/false-positive-file''']
# regexes = ['''EXAMPLE_PLACEHOLDER_[A-Z0-9]+''']
EOF

  echo "Created default .gitleaks.toml"
}
