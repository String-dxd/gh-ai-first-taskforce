#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/merge-hook.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/secrets.sh"
  REPO_DIR=$(mktemp -d)
  MOCK_LOG=$(mktemp)
  export MOCK_LOG
  MOCKS_DIR="$BATS_TEST_DIRNAME/../mocks"
}

teardown() {
  rm -rf "$REPO_DIR" "$MOCK_LOG"
}

# ── ensure_gitleaks_available ─────────────────────────────────────────────────

@test "ensure_gitleaks_available: returns 0 when gitleaks already in PATH" {
  export PATH="$MOCKS_DIR:$PATH"
  run ensure_gitleaks_available
  [ "$status" -eq 0 ]
}

@test "ensure_gitleaks_available: does not invoke brew when gitleaks already installed" {
  export PATH="$MOCKS_DIR:$PATH"
  ensure_gitleaks_available
  run grep "mock-brew" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "ensure_gitleaks_available: installs via brew when gitleaks absent and brew present" {
  local fake_bin="$REPO_DIR/bin"
  mkdir -p "$fake_bin"
  cp "$MOCKS_DIR/brew" "$fake_bin/brew"
  export PATH="$fake_bin:/usr/bin:/bin"
  ensure_gitleaks_available || true
  grep -q "mock-brew install gitleaks" "$MOCK_LOG"
}

@test "ensure_gitleaks_available: installs via go when gitleaks absent, brew absent, go present" {
  local fake_bin="$REPO_DIR/bin"
  mkdir -p "$fake_bin"
  cp "$MOCKS_DIR/go" "$fake_bin/go"
  export PATH="$fake_bin:/usr/bin:/bin"
  ensure_gitleaks_available || true
  grep -q "mock-go install github.com/zricethezav/gitleaks/v8@latest" "$MOCK_LOG"
}

@test "ensure_gitleaks_available: returns 1 with ERROR when gitleaks absent and no installer available" {
  local empty="$REPO_DIR/empty"
  mkdir -p "$empty"
  export PATH="$empty:/usr/bin:/bin"
  run ensure_gitleaks_available
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
}

@test "ensure_gitleaks_available: error message includes brew install command" {
  local empty="$REPO_DIR/empty"
  mkdir -p "$empty"
  export PATH="$empty:/usr/bin:/bin"
  run ensure_gitleaks_available
  [[ "$output" == *"brew install gitleaks"* ]]
}

@test "ensure_gitleaks_available: error message includes go install command" {
  local empty="$REPO_DIR/empty"
  mkdir -p "$empty"
  export PATH="$empty:/usr/bin:/bin"
  run ensure_gitleaks_available
  [[ "$output" == *"go install"*"gitleaks"* ]]
}

# ── ensure_gitleaks_config ────────────────────────────────────────────────────

@test "ensure_gitleaks_config: creates .gitleaks.toml when none exists" {
  ensure_gitleaks_config "$REPO_DIR"
  [ -f "$REPO_DIR/.gitleaks.toml" ]
}

@test "ensure_gitleaks_config: created config contains useDefault = true" {
  ensure_gitleaks_config "$REPO_DIR"
  grep -q "useDefault = true" "$REPO_DIR/.gitleaks.toml"
}

@test "ensure_gitleaks_config: created config contains allowlist comment guidance" {
  ensure_gitleaks_config "$REPO_DIR"
  grep -q "allowlist" "$REPO_DIR/.gitleaks.toml"
}

@test "ensure_gitleaks_config: skips when .gitleaks.toml already exists" {
  printf 'title = "custom"\n' > "$REPO_DIR/.gitleaks.toml"
  ensure_gitleaks_config "$REPO_DIR"
  run grep "useDefault" "$REPO_DIR/.gitleaks.toml"
  [ "$status" -ne 0 ]
}

@test "ensure_gitleaks_config: is idempotent — does not modify existing config" {
  printf 'title = "custom"\n' > "$REPO_DIR/.gitleaks.toml"
  ensure_gitleaks_config "$REPO_DIR"
  ensure_gitleaks_config "$REPO_DIR"
  [ "$(wc -l < "$REPO_DIR/.gitleaks.toml" | tr -d ' ')" = "1" ]
}
