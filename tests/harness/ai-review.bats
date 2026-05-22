#!/usr/bin/env bats

setup() {
  SCRIPT_DIR="$BATS_TEST_DIRNAME/../../harness"
  source "$BATS_TEST_DIRNAME/../../harness/lib/ai-review.sh"
  REPO_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$REPO_DIR"
}

# ── parse_harness_config ─────────────────────────────────────────────────

@test "parse_harness_config: returns value for present scalar key" {
  cat > "$REPO_DIR/.harness.yml" <<'YAML'
ai_review:
  model: "claude-sonnet-4-6"
  api_key_secret: "MY_API_KEY"
YAML
  run parse_harness_config "$REPO_DIR" "ai_review.model"
  [ "$status" -eq 0 ]
  [ "$output" = "claude-sonnet-4-6" ]
}

@test "parse_harness_config: returns empty for missing key" {
  cat > "$REPO_DIR/.harness.yml" <<'YAML'
ai_review:
  model: "claude-sonnet-4-6"
YAML
  run parse_harness_config "$REPO_DIR" "ai_review.api_key_secret"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "parse_harness_config: returns empty for missing file" {
  run parse_harness_config "$REPO_DIR" "ai_review.model"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "parse_harness_config: returns empty for missing parent section" {
  cat > "$REPO_DIR/.harness.yml" <<'YAML'
other_section:
  key: "value"
YAML
  run parse_harness_config "$REPO_DIR" "ai_review.model"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "parse_harness_config: strips surrounding quotes from value" {
  cat > "$REPO_DIR/.harness.yml" <<'YAML'
ai_review:
  api_key_secret: "ANTHROPIC_API_KEY"
YAML
  run parse_harness_config "$REPO_DIR" "ai_review.api_key_secret"
  [ "$status" -eq 0 ]
  [ "$output" = "ANTHROPIC_API_KEY" ]
}

# ── ai-review-runner.sh skip guards ─────────────────────────────────────

_runner_setup() {
  RUNNER="$BATS_TEST_DIRNAME/../../harness/scripts/ai-review-runner.sh"
  MOCK_PATH="$BATS_TEST_DIRNAME/../mocks"
}

@test "runner: skips with warning when claude CLI not in PATH" {
  _runner_setup
  run env PATH="/usr/bin:/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" ANTHROPIC_API_KEY="test-key" \
    sh "$RUNNER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"claude CLI not found"* ]]
}

@test "runner: skips with warning when API key env var is unset" {
  _runner_setup
  run env PATH="$MOCK_PATH:/usr/bin:/bin:/usr/local/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" \
    sh "$RUNNER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ANTHROPIC_API_KEY not set"* ]]
}

@test "runner: skips with warning when API key env var is empty" {
  _runner_setup
  run env PATH="$MOCK_PATH:/usr/bin:/bin:/usr/local/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" ANTHROPIC_API_KEY="" \
    sh "$RUNNER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ANTHROPIC_API_KEY not set"* ]]
}
