# AI-Assisted Local Pre-Push Review Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Install a non-blocking AI pre-push review hook into JS/mixed repos that calls Claude, prints the review to the terminal, saves it to `review/`, and commits it before each push.

**Architecture:** Two new harness files — `harness/lib/ai-review.sh` (install-time logic) and `harness/scripts/ai-review-runner.sh` (review runner installed into target repos at `.harness/ai-review-runner.sh`). `setup.sh` sources the lib and calls `install_ai_review_hook` for JS and mixed repos. The runner is called from the pre-push hook and is runnable standalone for debugging.

**Tech Stack:** POSIX sh, bats-core, git, Claude CLI (`claude`), `merge_block` (existing harness utility in `harness/lib/merge-hook.sh`)

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `tests/mocks/claude` | Create | Mock `claude` binary — echoes canned review, exits 0 |
| `harness/lib/ai-review.sh` | Create | `parse_harness_config`, `install_ai_review_runner`, `install_ai_review_hook` |
| `harness/scripts/ai-review-runner.sh` | Create | Skip guards, diff fetch, Claude call, review file save, git commit |
| `tests/harness/ai-review.bats` | Create | All bats tests for lib and runner |
| `harness/setup.sh` | Modify | Source `ai-review.sh`, parse config, call `install_ai_review_hook` in js/mixed case |
| `tests/harness/setup.bats` | Modify | Two new tests: ai-review block present, idempotent |

---

### Task 1: Mock `claude` binary

**Files:**
- Create: `tests/mocks/claude`

- [ ] **Step 1: Create the mock**

```sh
#!/bin/sh
echo "## AI Review

This is a canned test review.

- Line 1 looks good
- Line 2 could be improved"
```

Save as `tests/mocks/claude`, then:

```bash
chmod +x tests/mocks/claude
```

- [ ] **Step 2: Verify mock works**

```bash
PATH="$(pwd)/tests/mocks:$PATH" claude --model claude-sonnet-4-6 -p /dev/stdin <<'EOF'
test input
EOF
```

Expected output includes `canned test review`.

- [ ] **Step 3: Commit**

```bash
git add tests/mocks/claude
git commit -m "test: add mock claude binary for ai-review tests"
```

---

### Task 2: `parse_harness_config` (TDD)

**Files:**
- Create: `harness/lib/ai-review.sh`
- Create: `tests/harness/ai-review.bats`

- [ ] **Step 1: Write failing tests**

Create `tests/harness/ai-review.bats`:

```bash
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
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
bats tests/harness/ai-review.bats
```

Expected: all 5 tests fail with `parse_harness_config: command not found`.

- [ ] **Step 3: Create `harness/lib/ai-review.sh` with `parse_harness_config`**

```sh
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
```

- [ ] **Step 4: Run tests to confirm all pass**

```bash
bats tests/harness/ai-review.bats
```

Expected: all 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add harness/lib/ai-review.sh tests/harness/ai-review.bats
git commit -m "feat: add parse_harness_config to ai-review.sh"
```

---

### Task 3: Runner skip guards (TDD)

**Files:**
- Create: `harness/scripts/ai-review-runner.sh` (partial — skip guards only)
- Modify: `tests/harness/ai-review.bats`

- [ ] **Step 1: Append failing tests for skip guards**

```bash
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
```

- [ ] **Step 2: Run to confirm failure**

```bash
bats tests/harness/ai-review.bats
```

Expected: 3 new tests fail with `No such file or directory` for the runner script.

- [ ] **Step 3: Create `harness/scripts/ai-review-runner.sh` with skip guards**

```bash
mkdir -p harness/scripts
```

Create `harness/scripts/ai-review-runner.sh`:

```sh
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
```

```bash
chmod +x harness/scripts/ai-review-runner.sh
```

- [ ] **Step 4: Run tests to confirm skip guard tests pass**

```bash
bats tests/harness/ai-review.bats
```

Expected: all 8 tests pass.

- [ ] **Step 5: Commit**

```bash
git add harness/scripts/ai-review-runner.sh tests/harness/ai-review.bats
git commit -m "feat: add ai-review-runner.sh with skip guards"
```

---

### Task 4: Runner review flow — diff, Claude call, save, commit (TDD)

**Files:**
- Modify: `harness/scripts/ai-review-runner.sh`
- Modify: `tests/harness/ai-review.bats`

- [ ] **Step 1: Append failing tests for the full review flow**

```bash
# ── ai-review-runner.sh review flow ─────────────────────────────────────

_git_repo_setup() {
  REMOTE_DIR=$(mktemp -d)
  WORK_DIR=$(mktemp -d)

  git -C "$REMOTE_DIR" init --bare -q

  git clone -q "$REMOTE_DIR" "$WORK_DIR" 2>/dev/null
  git -C "$WORK_DIR" config user.email "test@test.com"
  git -C "$WORK_DIR" config user.name "Test"

  echo "init" > "$WORK_DIR/README.md"
  git -C "$WORK_DIR" add .
  git -C "$WORK_DIR" commit -q -m "init"
  git -C "$WORK_DIR" push -q -u origin main 2>/dev/null

  # Unpushed local commit — this is what the runner will review
  echo "local change" > "$WORK_DIR/app.js"
  git -C "$WORK_DIR" add .
  git -C "$WORK_DIR" commit -q -m "local work"
}

@test "runner: skips when there are no unpushed commits" {
  _runner_setup
  local remote work
  remote=$(mktemp -d)
  work=$(mktemp -d)
  git -C "$remote" init --bare -q
  git clone -q "$remote" "$work" 2>/dev/null
  git -C "$work" config user.email "t@t.com"
  git -C "$work" config user.name "T"
  echo "init" > "$work/README.md"
  git -C "$work" add .
  git -C "$work" commit -q -m "init"
  git -C "$work" push -q -u origin main 2>/dev/null

  run env PATH="$MOCK_PATH:/usr/bin:/bin:/usr/local/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" ANTHROPIC_API_KEY="test-key" \
    sh -c "cd '$work' && sh '$RUNNER'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no diff to review"* ]]
  rm -rf "$remote" "$work"
}

@test "runner: calls claude and prints review to terminal" {
  _runner_setup
  _git_repo_setup

  run env PATH="$MOCK_PATH:/usr/bin:/bin:/usr/local/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" ANTHROPIC_API_KEY="test-key" \
    sh -c "cd '$WORK_DIR' && sh '$RUNNER'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"running AI pre-push review"* ]]
  [[ "$output" == *"canned test review"* ]]
  rm -rf "$REMOTE_DIR" "$WORK_DIR"
}

@test "runner: saves review to review/YYYY-MM-DD-<branch>-<sha>.md" {
  _runner_setup
  _git_repo_setup
  local sha branch today
  sha=$(git -C "$WORK_DIR" rev-parse --short HEAD)
  branch=$(git -C "$WORK_DIR" rev-parse --abbrev-ref HEAD | tr '/' '-')
  today=$(date +%Y-%m-%d)

  env PATH="$MOCK_PATH:/usr/bin:/bin:/usr/local/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" ANTHROPIC_API_KEY="test-key" \
    sh -c "cd '$WORK_DIR' && sh '$RUNNER'"

  [ -f "$WORK_DIR/review/${today}-${branch}-${sha}.md" ]
  grep -q "canned test review" "$WORK_DIR/review/${today}-${branch}-${sha}.md"
  rm -rf "$REMOTE_DIR" "$WORK_DIR"
}

@test "runner: review file contains date, branch, and commit SHA header" {
  _runner_setup
  _git_repo_setup
  local sha branch today
  sha=$(git -C "$WORK_DIR" rev-parse --short HEAD)
  branch=$(git -C "$WORK_DIR" rev-parse --abbrev-ref HEAD | tr '/' '-')
  today=$(date +%Y-%m-%d)

  env PATH="$MOCK_PATH:/usr/bin:/bin:/usr/local/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" ANTHROPIC_API_KEY="test-key" \
    sh -c "cd '$WORK_DIR' && sh '$RUNNER'"

  local review_file="$WORK_DIR/review/${today}-${branch}-${sha}.md"
  grep -q "**Date:** $today" "$review_file"
  grep -q "**Branch:** $branch" "$review_file"
  grep -q "**Commit:** $sha" "$review_file"
  rm -rf "$REMOTE_DIR" "$WORK_DIR"
}

@test "runner: commits review file with expected message" {
  _runner_setup
  _git_repo_setup
  local sha branch
  sha=$(git -C "$WORK_DIR" rev-parse --short HEAD)
  branch=$(git -C "$WORK_DIR" rev-parse --abbrev-ref HEAD | tr '/' '-')

  env PATH="$MOCK_PATH:/usr/bin:/bin:/usr/local/bin" \
    HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY" ANTHROPIC_API_KEY="test-key" \
    sh -c "cd '$WORK_DIR' && sh '$RUNNER'"

  [ "$(git -C "$WORK_DIR" log -1 --format='%s')" = "chore: ai review for ${branch} @ ${sha}" ]
  rm -rf "$REMOTE_DIR" "$WORK_DIR"
}
```

- [ ] **Step 2: Run to confirm the 5 new tests fail**

```bash
bats tests/harness/ai-review.bats
```

Expected: 5 new tests fail.

- [ ] **Step 3: Implement full review flow in `harness/scripts/ai-review-runner.sh`**

Replace the file:

```sh
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

  local base
  base=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null \
    || echo "origin/main")

  local diff
  diff=$(git diff "$base"..HEAD -- . \
    ':(exclude)**/*.lock' \
    ':(exclude)**/package-lock.json' \
    ':(exclude)**/go.sum' \
    ':(exclude)**/*.generated.*' \
    ':(exclude)**/dist/**' \
    2>/dev/null)

  [ -n "$diff" ] \
    || { echo "harness: ai-review skipped (no diff to review)"; return 0; }

  local sha branch today review_dir review_file
  sha=$(git rev-parse --short HEAD)
  branch=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')
  today=$(date +%Y-%m-%d)
  review_dir="$(git rev-parse --show-toplevel)/review"
  review_file="$review_dir/${today}-${branch}-${sha}.md"

  echo "harness: running AI pre-push review..."
  local review
  review=$(printf 'Review the following diff for code quality, potential bugs, and logic issues. Be concise.\n\n%s\n' \
    "$diff" | claude --model "$HARNESS_AI_MODEL" -p /dev/stdin 2>&1) || true

  echo "$review"

  mkdir -p "$review_dir"
  printf '# AI Pre-Push Review\n\n**Date:** %s\n**Branch:** %s\n**Commit:** %s\n\n---\n\n%s\n' \
    "$today" "$branch" "$sha" "$review" > "$review_file"

  git add "review/" \
    && git commit --no-verify \
         -m "chore: ai review for ${branch} @ ${sha}" \
         -- "review/" \
    || true

  echo "harness: review saved to $review_file"
}

_harness_ai_review
```

- [ ] **Step 4: Run all tests to confirm they pass**

```bash
bats tests/harness/ai-review.bats
```

Expected: all 13 tests pass.

- [ ] **Step 5: Commit**

```bash
git add harness/scripts/ai-review-runner.sh tests/harness/ai-review.bats
git commit -m "feat: implement full ai-review-runner.sh — diff, review, save, commit"
```

---

### Task 5: `install_ai_review_runner` (TDD)

**Files:**
- Modify: `harness/lib/ai-review.sh`
- Modify: `tests/harness/ai-review.bats`

- [ ] **Step 1: Append failing tests**

```bash
# ── install_ai_review_runner ─────────────────────────────────────────────

@test "install_ai_review_runner: copies runner to .harness/ai-review-runner.sh" {
  run install_ai_review_runner "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.harness/ai-review-runner.sh" ]
}

@test "install_ai_review_runner: installed script is executable" {
  install_ai_review_runner "$REPO_DIR"
  [ -x "$REPO_DIR/.harness/ai-review-runner.sh" ]
}

@test "install_ai_review_runner: creates .harness/ directory if absent" {
  [ ! -d "$REPO_DIR/.harness" ]
  install_ai_review_runner "$REPO_DIR"
  [ -d "$REPO_DIR/.harness" ]
}

@test "install_ai_review_runner: is idempotent" {
  install_ai_review_runner "$REPO_DIR"
  run install_ai_review_runner "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.harness/ai-review-runner.sh" ]
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
bats tests/harness/ai-review.bats
```

Expected: 4 new tests fail with `install_ai_review_runner: command not found`.

- [ ] **Step 3: Append `install_ai_review_runner` to `harness/lib/ai-review.sh`**

```sh
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
```

- [ ] **Step 4: Run tests to confirm all pass**

```bash
bats tests/harness/ai-review.bats
```

Expected: all 17 tests pass.

- [ ] **Step 5: Commit**

```bash
git add harness/lib/ai-review.sh tests/harness/ai-review.bats
git commit -m "feat: add install_ai_review_runner to ai-review.sh"
```

---

### Task 6: `install_ai_review_hook` (TDD)

**Files:**
- Modify: `harness/lib/ai-review.sh`
- Modify: `tests/harness/ai-review.bats`

- [ ] **Step 1: Append failing tests**

```bash
# ── install_ai_review_hook ───────────────────────────────────────────────

_husky_setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/merge-hook.sh"
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-push"
  chmod +x "$REPO_DIR/.husky/pre-push"
}

@test "install_ai_review_hook: copies runner to .harness/" {
  _husky_setup
  run install_ai_review_hook "$REPO_DIR" "claude-sonnet-4-6" "ANTHROPIC_API_KEY"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.harness/ai-review-runner.sh" ]
}

@test "install_ai_review_hook: merges call block into .husky/pre-push" {
  _husky_setup
  install_ai_review_hook "$REPO_DIR" "claude-sonnet-4-6" "ANTHROPIC_API_KEY"
  grep -q "# harness:ai-review:begin" "$REPO_DIR/.husky/pre-push"
  grep -q "ai-review-runner.sh" "$REPO_DIR/.husky/pre-push"
  grep -q 'HARNESS_AI_MODEL="claude-sonnet-4-6"' "$REPO_DIR/.husky/pre-push"
  grep -q 'HARNESS_AI_KEY_VAR="ANTHROPIC_API_KEY"' "$REPO_DIR/.husky/pre-push"
}

@test "install_ai_review_hook: is idempotent — does not duplicate block" {
  _husky_setup
  install_ai_review_hook "$REPO_DIR" "claude-sonnet-4-6" "ANTHROPIC_API_KEY"
  install_ai_review_hook "$REPO_DIR" "claude-sonnet-4-6" "ANTHROPIC_API_KEY"
  [ "$(grep -c 'harness:ai-review:begin' "$REPO_DIR/.husky/pre-push")" = "1" ]
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
bats tests/harness/ai-review.bats
```

Expected: 3 new tests fail with `install_ai_review_hook: command not found`.

- [ ] **Step 3: Append `install_ai_review_hook` to `harness/lib/ai-review.sh`**

```sh
# install_ai_review_hook <repo_root> <model> <api_key_var>
# Installs the runner and wires the pre-push hook call block.
# The model and api_key_var are substituted at install time;
# $(git rev-parse --show-toplevel) is left for runtime evaluation.
install_ai_review_hook() {
  local repo_root="$1" model="$2" api_key_var="$3"
  local pre_push="$repo_root/.husky/pre-push"
  local block

  install_ai_review_runner "$repo_root"

  block='# harness:ai-review:begin
HARNESS_AI_MODEL="'"$model"'" HARNESS_AI_KEY_VAR="'"$api_key_var"'" \
  sh "$(git rev-parse --show-toplevel)/.harness/ai-review-runner.sh"
# harness:ai-review:end'

  merge_block "$pre_push" "ai-review" "$block" ""
}
```

- [ ] **Step 4: Run all tests to confirm they pass**

```bash
bats tests/harness/ai-review.bats
```

Expected: all 20 tests pass.

- [ ] **Step 5: Commit**

```bash
git add harness/lib/ai-review.sh tests/harness/ai-review.bats
git commit -m "feat: add install_ai_review_hook to ai-review.sh"
```

---

### Task 7: Wire into `setup.sh` (TDD)

**Files:**
- Modify: `harness/setup.sh`
- Modify: `tests/harness/setup.bats`

- [ ] **Step 1: Append failing tests to `tests/harness/setup.bats`**

```bash
# ── ai-review hook ───────────────────────────────────────────────────────

@test "setup: merges ai-review block into .husky/pre-push for JS repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:ai-review:begin" "$REPO_DIR/.husky/pre-push"
}

@test "setup: re-run does not duplicate ai-review block in pre-push" {
  _pnpm_repo_with_hooks
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c 'harness:ai-review:begin' "$REPO_DIR/.husky/pre-push")" = "1" ]
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
bats tests/harness/setup.bats
```

Expected: 2 new tests fail — ai-review block not present in pre-push.

- [ ] **Step 3: Modify `harness/setup.sh`**

Add the source line after `secrets.sh`:

```sh
. "$SCRIPT_DIR/lib/ai-review.sh"
```

Add config parsing after all source lines, before `REPO_LANG=$(detect_language ...)`:

```sh
AI_MODEL=$(parse_harness_config "$REPO_ROOT" "ai_review.model")
AI_KEY_VAR=$(parse_harness_config "$REPO_ROOT" "ai_review.api_key_secret")
```

Inside the `js|mixed)` case, after `install_workflow_file` and before the `echo "Done..."` line:

```sh
    install_ai_review_hook "$REPO_ROOT" \
      "${AI_MODEL:-claude-sonnet-4-6}" \
      "${AI_KEY_VAR:-ANTHROPIC_API_KEY}"
```

- [ ] **Step 4: Run setup tests to confirm new tests pass**

```bash
bats tests/harness/setup.bats
```

Expected: all tests pass including 2 new ones.

- [ ] **Step 5: Run full test suite to confirm no regressions**

```bash
bats tests/harness/
```

Expected: all tests across all files pass.

- [ ] **Step 6: Commit**

```bash
git add harness/setup.sh tests/harness/setup.bats
git commit -m "feat: wire ai-review hook into harness setup for js/mixed repos"
```

---

### Task 8: Smoke test and close issue

**Files:** none

- [ ] **Step 1: Run the full test suite one final time**

```bash
bats tests/harness/
```

Expected: all tests pass, zero failures.

- [ ] **Step 2: Smoke test the installed runner standalone**

In any git repo with unpushed commits and `claude` CLI installed:

```bash
ANTHROPIC_API_KEY="<your-key>" sh .harness/ai-review-runner.sh
```

Expected:
- `harness: running AI pre-push review...` printed
- Review content printed to terminal
- `review/YYYY-MM-DD-<branch>-<sha>.md` created with review content
- `git log -1 --format='%s'` shows `chore: ai review for <branch> @ <sha>`

- [ ] **Step 3: Close issue #13**

```bash
gh issue close 13 --repo transformteamsg/ai-first-taskforce \
  --comment "Implemented in $(git rev-parse --short HEAD). Runner at \`.harness/ai-review-runner.sh\`, lib at \`harness/lib/ai-review.sh\`."
```
