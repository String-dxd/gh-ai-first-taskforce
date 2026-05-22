# Formatting — Automatic Formatting Enforcement on Commit and in CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the harness to install Prettier for JS/TS repos (and gofmt + goimports for mixed repos), enforce formatting on staged files via lint-staged in pre-commit, and add formatting checks to the generated CI workflow — check mode only, no auto-fixing.

**Architecture:** A new `harness/lib/format.sh` library mirrors the structure of `lint.sh`. It installs Prettier (with optional tailwindcss plugin), writes a default `.prettierrc`, and manages `.lintstagedrc.json` (which also covers ESLint — `install_prettier_staged` supersedes `ensure_lint_staged_config` from `lint.sh`). For mixed repos it installs goimports and merges a `harness:gofmt` pre-commit block. `generate_workflow_yaml` in `ci-workflows.sh` gains Prettier and gofmt/goimports CI steps. `setup.sh` sources `format.sh` and calls its functions after the lint setup, with `ensure_lint_staged_config` removed since `install_prettier_staged` now owns the config.

**Tech Stack:** POSIX sh, bats-core, Prettier (npm), prettier-plugin-tailwindcss (npm, conditional), lint-staged (npm), gofmt (Go stdlib), goimports (Go binary), GitHub Actions YAML

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `tests/mocks/goimports` | Mock goimports binary — logs invocations to $MOCK_LOG, returns 0 |
| Create | `tests/harness/format.bats` | Unit tests for all format.sh functions (30 tests) |
| Create | `harness/lib/format.sh` | `_has_tailwind`, `ensure_prettier_installed`, `ensure_prettier_config`, `install_prettier_staged`, `ensure_goimports_available`, `install_gofmt_hook` |
| Modify | `tests/harness/ci-workflows.bats` | Add 4 tests for formatting steps in `generate_workflow_yaml` |
| Modify | `harness/lib/ci-workflows.sh` | Add Prettier and gofmt/goimports steps to `generate_workflow_yaml` |
| Modify | `tests/harness/setup.bats` | Add 7 integration tests for formatting setup |
| Modify | `harness/setup.sh` | Source `format.sh`; add format calls; remove `ensure_lint_staged_config`; add `install_prettier_staged` + goimports/gofmt calls for mixed |
| Modify | `harness/README.md` | Add Formatting section; update directory structure |

---

### Task 1: Create `tests/mocks/goimports`

**Files:**
- Create: `tests/mocks/goimports`

- [ ] **Step 1: Create `tests/mocks/goimports`**

```sh
#!/bin/sh
echo "mock-goimports $*" >> "${MOCK_LOG:-/tmp/mock-calls.log}"
exit 0
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x tests/mocks/goimports
```

- [ ] **Step 3: Verify it logs correctly**

```bash
MOCK_LOG=$(mktemp)
export MOCK_LOG
tests/mocks/goimports -l ./...
grep -q "mock-goimports -l ./..." "$MOCK_LOG" && echo "PASS" || echo "FAIL"
rm "$MOCK_LOG"
```

Expected: `PASS`

- [ ] **Step 4: Commit**

```bash
git add tests/mocks/goimports
git commit -m "test: add mock goimports binary for format tests"
```

---

### Task 2: Write failing tests for `format.sh` (TDD red)

**Files:**
- Create: `tests/harness/format.bats`

`format.sh` will depend on `detect_package_manager` (from `detect-package-manager.sh`) and `merge_block` (from `merge-hook.sh`). Both must be sourced before `format.sh` in the test setup.

- [ ] **Step 1: Create `tests/harness/format.bats`**

```bash
#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../harness/lib/detect-package-manager.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/merge-hook.sh"
  source "$BATS_TEST_DIRNAME/../../harness/lib/format.sh"
  REPO_DIR=$(mktemp -d)
  MOCK_LOG=$(mktemp)
  export MOCK_LOG
  MOCKS_DIR="$BATS_TEST_DIRNAME/../mocks"
}

teardown() {
  rm -rf "$REPO_DIR" "$MOCK_LOG"
}

# ── _has_tailwind ──────────────────────────────────────────────────────────

@test "_has_tailwind: returns 0 when tailwindcss in package.json" {
  printf '{"dependencies":{"tailwindcss":"^3.0.0"}}\n' > "$REPO_DIR/package.json"
  run _has_tailwind "$REPO_DIR"
  [ "$status" -eq 0 ]
}

@test "_has_tailwind: returns 1 when tailwindcss absent from package.json" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run _has_tailwind "$REPO_DIR"
  [ "$status" -eq 1 ]
}

# ── ensure_prettier_installed ──────────────────────────────────────────────

@test "ensure_prettier_installed: runs pnpm add when prettier absent (pnpm repo)" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_prettier_installed "$REPO_DIR"
  grep -q "mock-pnpm add -D prettier" "$MOCK_LOG"
}

@test "ensure_prettier_installed: runs bun add when prettier absent (bun repo)" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/bun.lockb"
  ensure_prettier_installed "$REPO_DIR"
  grep -q "mock-bun add -D prettier" "$MOCK_LOG"
}

@test "ensure_prettier_installed: skips install when prettier already present" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{"prettier":"^3.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_prettier_installed "$REPO_DIR"
  run grep "mock-pnpm add -D prettier$" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "ensure_prettier_installed: exits 1 for unsupported package manager" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  run ensure_prettier_installed "$REPO_DIR"
  [ "$status" -eq 1 ]
}

@test "ensure_prettier_installed: installs prettier-plugin-tailwindcss when tailwindcss present" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"dependencies":{"tailwindcss":"^3.0.0"},"devDependencies":{"prettier":"^3.0.0"}}\n' \
    > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_prettier_installed "$REPO_DIR"
  grep -q "mock-pnpm add -D prettier-plugin-tailwindcss" "$MOCK_LOG"
}

@test "ensure_prettier_installed: does not install tailwind plugin when tailwindcss absent" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"devDependencies":{"prettier":"^3.0.0"}}\n' > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_prettier_installed "$REPO_DIR"
  run grep "mock-pnpm add -D prettier-plugin-tailwindcss" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

@test "ensure_prettier_installed: skips tailwind plugin when already present" {
  export PATH="$MOCKS_DIR:$PATH"
  printf '{"dependencies":{"tailwindcss":"^3.0.0"},"devDependencies":{"prettier":"^3.0.0","prettier-plugin-tailwindcss":"^0.5.0"}}\n' \
    > "$REPO_DIR/package.json"
  touch "$REPO_DIR/pnpm-lock.yaml"
  ensure_prettier_installed "$REPO_DIR"
  run grep "mock-pnpm add -D prettier-plugin-tailwindcss" "$MOCK_LOG"
  [ "$status" -ne 0 ]
}

# ── ensure_prettier_config ─────────────────────────────────────────────────

@test "ensure_prettier_config: creates .prettierrc when no config exists" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_prettier_config "$REPO_DIR"
  [ -f "$REPO_DIR/.prettierrc" ]
}

@test "ensure_prettier_config: .prettierrc contains printWidth 150" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_prettier_config "$REPO_DIR"
  grep -q '"printWidth": 150' "$REPO_DIR/.prettierrc"
}

@test "ensure_prettier_config: .prettierrc includes tailwind plugin when tailwindcss present" {
  printf '{"dependencies":{"tailwindcss":"^3.0.0"}}\n' > "$REPO_DIR/package.json"
  ensure_prettier_config "$REPO_DIR"
  grep -q "prettier-plugin-tailwindcss" "$REPO_DIR/.prettierrc"
}

@test "ensure_prettier_config: .prettierrc excludes tailwind plugin when tailwindcss absent" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  ensure_prettier_config "$REPO_DIR"
  run grep "prettier-plugin-tailwindcss" "$REPO_DIR/.prettierrc"
  [ "$status" -ne 0 ]
}

@test "ensure_prettier_config: skips when .prettierrc already exists" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  printf '{"printWidth": 80}\n' > "$REPO_DIR/.prettierrc"
  ensure_prettier_config "$REPO_DIR"
  run grep '"printWidth": 150' "$REPO_DIR/.prettierrc"
  [ "$status" -ne 0 ]
}

@test "ensure_prettier_config: skips when .prettierrc.json already exists" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  printf '{"printWidth": 80}\n' > "$REPO_DIR/.prettierrc.json"
  ensure_prettier_config "$REPO_DIR"
  [ ! -f "$REPO_DIR/.prettierrc" ]
}

@test "ensure_prettier_config: skips when prettier.config.js already exists" {
  printf '{"devDependencies":{}}\n' > "$REPO_DIR/package.json"
  printf 'module.exports = {}\n' > "$REPO_DIR/prettier.config.js"
  ensure_prettier_config "$REPO_DIR"
  [ ! -f "$REPO_DIR/.prettierrc" ]
}

# ── install_prettier_staged ────────────────────────────────────────────────

@test "install_prettier_staged: creates .lintstagedrc.json with prettier when no config exists" {
  install_prettier_staged "$REPO_DIR"
  [ -f "$REPO_DIR/.lintstagedrc.json" ]
}

@test "install_prettier_staged: .lintstagedrc.json contains prettier --check" {
  install_prettier_staged "$REPO_DIR"
  grep -q "prettier --check" "$REPO_DIR/.lintstagedrc.json"
}

@test "install_prettier_staged: .lintstagedrc.json contains eslint" {
  install_prettier_staged "$REPO_DIR"
  grep -q "eslint" "$REPO_DIR/.lintstagedrc.json"
}

@test "install_prettier_staged: is idempotent when prettier already in .lintstagedrc.json" {
  printf '{"*.{js,jsx,ts,tsx}":["prettier --check","eslint"]}\n' \
    > "$REPO_DIR/.lintstagedrc.json"
  install_prettier_staged "$REPO_DIR"
  [ "$(grep -c "prettier" "$REPO_DIR/.lintstagedrc.json")" = "1" ]
}

@test "install_prettier_staged: skips when lint-staged key in package.json has prettier" {
  printf '{"lint-staged":{"*.ts":["prettier --check"]}}\n' > "$REPO_DIR/package.json"
  install_prettier_staged "$REPO_DIR"
  [ ! -f "$REPO_DIR/.lintstagedrc.json" ]
}

# ── ensure_goimports_available ────────────────────────────────────────────

@test "ensure_goimports_available: returns 0 when goimports in PATH" {
  local bin_dir="$REPO_DIR/bin"
  mkdir -p "$bin_dir"
  printf '#!/bin/sh\nexit 0\n' > "$bin_dir/goimports"
  chmod +x "$bin_dir/goimports"
  export PATH="$bin_dir:/usr/bin:/bin"
  run ensure_goimports_available
  [ "$status" -eq 0 ]
}

@test "ensure_goimports_available: runs go install when go available and goimports absent" {
  local go_bin="$REPO_DIR/go-bin"
  mkdir -p "$go_bin"
  printf '#!/bin/sh\necho "mock-go $*" >> "%s"\n' "$MOCK_LOG" > "$go_bin/go"
  chmod +x "$go_bin/go"
  export PATH="$go_bin:/usr/bin:/bin"
  run ensure_goimports_available
  [ "$status" -eq 0 ]
  grep -q "mock-go install golang.org/x/tools/cmd/goimports" "$MOCK_LOG"
}

@test "ensure_goimports_available: fails with actionable error when neither found" {
  local empty_dir="$REPO_DIR/empty"
  mkdir -p "$empty_dir"
  local saved_path="$PATH"
  export PATH="$empty_dir"
  run ensure_goimports_available
  export PATH="$saved_path"
  [ "$status" -eq 1 ]
  [[ "$output" == *"ERROR"* ]]
  [[ "$output" == *"goimports"* ]]
}

# ── install_gofmt_hook ────────────────────────────────────────────────────

@test "install_gofmt_hook: merges gofmt block into pre-commit" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gofmt_hook "$REPO_DIR"
  grep -q "# harness:gofmt:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gofmt_hook: pre-commit contains gofmt -l" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gofmt_hook "$REPO_DIR"
  grep -q "gofmt -l" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gofmt_hook: pre-commit contains goimports -l" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gofmt_hook "$REPO_DIR"
  grep -q "goimports -l" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gofmt_hook: only runs when staged .go files present" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gofmt_hook "$REPO_DIR"
  grep -q '\.go' "$REPO_DIR/.husky/pre-commit"
}

@test "install_gofmt_hook: block checks for gofmt at runtime" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gofmt_hook "$REPO_DIR"
  grep -q "command -v gofmt" "$REPO_DIR/.husky/pre-commit"
}

@test "install_gofmt_hook: is idempotent on re-run" {
  mkdir -p "$REPO_DIR/.husky"
  printf '#!/bin/sh\n' > "$REPO_DIR/.husky/pre-commit"
  chmod +x "$REPO_DIR/.husky/pre-commit"
  install_gofmt_hook "$REPO_DIR"
  install_gofmt_hook "$REPO_DIR"
  [ "$(grep -c "harness:gofmt:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}
```

- [ ] **Step 2: Run the tests to confirm they all fail**

```bash
bats tests/harness/format.bats
```

Expected: all 30 tests FAIL with `source: .../format.sh: No such file or directory` or similar.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/harness/format.bats
git commit -m "test: add failing bats tests for format.sh (TDD red phase)"
```

---

### Task 3: Implement `harness/lib/format.sh` (TDD green)

**Files:**
- Create: `harness/lib/format.sh`

- [ ] **Step 1: Create `harness/lib/format.sh`**

```sh
# Requires detect_package_manager() from detect-package-manager.sh
# and merge_block() from merge-hook.sh to be sourced before this file.

# _has_tailwind <repo_root>
# Returns 0 if tailwindcss appears in package.json, 1 otherwise.
_has_tailwind() {
  grep -q '"tailwindcss"' "${1}/package.json" 2>/dev/null
}

# ensure_prettier_installed <repo_root>
# Installs prettier as a dev dependency if absent.
# Also installs prettier-plugin-tailwindcss if tailwindcss is detected and plugin is absent.
ensure_prettier_installed() {
  local repo_root="$1"
  local pm
  pm=$(detect_package_manager "$repo_root")

  if ! grep -q '"prettier"' "$repo_root/package.json" 2>/dev/null; then
    case "$pm" in
      pnpm) (cd "$repo_root" && pnpm add -D prettier) ;;
      bun)  (cd "$repo_root" && bun add -D prettier) ;;
      *)
        echo "ERROR: Unsupported package manager" >&2
        return 1
        ;;
    esac
  fi

  if _has_tailwind "$repo_root" && \
     ! grep -q '"prettier-plugin-tailwindcss"' "$repo_root/package.json" 2>/dev/null; then
    case "$pm" in
      pnpm) (cd "$repo_root" && pnpm add -D prettier-plugin-tailwindcss) ;;
      bun)  (cd "$repo_root" && bun add -D prettier-plugin-tailwindcss) ;;
    esac
  fi
}

# ensure_prettier_config <repo_root>
# Writes a default .prettierrc if no Prettier config of any kind exists.
# Includes prettier-plugin-tailwindcss in the plugins array when tailwindcss is detected.
ensure_prettier_config() {
  local repo_root="$1"
  for cfg in .prettierrc .prettierrc.json .prettierrc.js .prettierrc.cjs \
             .prettierrc.mjs .prettierrc.yml .prettierrc.yaml \
             prettier.config.js prettier.config.cjs prettier.config.mjs; do
    [ -f "$repo_root/$cfg" ] && return 0
  done
  grep -q '"prettier"' "$repo_root/package.json" 2>/dev/null && return 0

  if _has_tailwind "$repo_root"; then
    printf '{\n  "printWidth": 150,\n  "tabWidth": 2,\n  "singleQuote": true,\n  "bracketSameLine": true,\n  "trailingComma": "es5",\n  "plugins": ["prettier-plugin-tailwindcss"]\n}\n' \
      > "$repo_root/.prettierrc"
  else
    printf '{\n  "printWidth": 150,\n  "tabWidth": 2,\n  "singleQuote": true,\n  "bracketSameLine": true,\n  "trailingComma": "es5"\n}\n' \
      > "$repo_root/.prettierrc"
  fi
  echo "Created default .prettierrc"
}

# install_prettier_staged <repo_root>
# Writes .lintstagedrc.json with prettier --check and eslint --max-warnings=0.
# Skips if prettier is already present in any lint-staged config.
# This function owns the lint-staged config — it supersedes ensure_lint_staged_config.
install_prettier_staged() {
  local repo_root="$1"
  local config="$repo_root/.lintstagedrc.json"

  grep -q '"prettier' "$config" 2>/dev/null && return 0
  grep -q '"prettier' "$repo_root/package.json" 2>/dev/null && return 0

  printf '{\n  "*.{js,jsx,ts,tsx}": ["prettier --check", "eslint --max-warnings=0"]\n}\n' \
    > "$config"
  echo "Updated .lintstagedrc.json"
}

# ensure_goimports_available
# Returns 0 if goimports is in PATH. If not, attempts go install.
# Fails with an actionable error if neither goimports nor go is available.
ensure_goimports_available() {
  if command -v goimports >/dev/null 2>&1; then
    return 0
  fi
  if command -v go >/dev/null 2>&1; then
    go install golang.org/x/tools/cmd/goimports@latest
    echo "Installed goimports via go install. Ensure your GOPATH/bin is in PATH."
  else
    echo "ERROR: goimports not found and go is not available. Install Go: https://go.dev/dl/" >&2
    return 1
  fi
}

# install_gofmt_hook <repo_root>
# Merges the gofmt + goimports pre-commit block (mixed repos only).
# Only runs when staged .go files are present. Fails with actionable errors.
install_gofmt_hook() {
  local repo_root="$1"
  local gofmt_block
  gofmt_block='# harness:gofmt:begin
_STAGED_GO=$(git diff --cached --name-only --diff-filter=ACM | grep '"'"'\.go$'"'"' || true)
if [ -n "$_STAGED_GO" ]; then
  if ! command -v gofmt >/dev/null 2>&1; then
    echo "ERROR: gofmt not found. Install Go: https://go.dev/dl/" >&2
    exit 1
  fi
  _FMT=$(echo "$_STAGED_GO" | xargs gofmt -l)
  if [ -n "$_FMT" ]; then
    echo "ERROR: The following Go files are not gofmt-formatted (run gofmt -w <file>):"
    echo "$_FMT"
    exit 1
  fi
  if command -v goimports >/dev/null 2>&1; then
    _IMP=$(echo "$_STAGED_GO" | xargs goimports -l)
    if [ -n "$_IMP" ]; then
      echo "ERROR: The following Go files need import formatting (run goimports -w <file>):"
      echo "$_IMP"
      exit 1
    fi
  fi
fi
unset _STAGED_GO _FMT _IMP
# harness:gofmt:end'
  merge_block "$repo_root/.husky/pre-commit" "gofmt" "$gofmt_block" "append"
}
```

- [ ] **Step 2: Run the tests to verify they all pass**

```bash
bats tests/harness/format.bats
```

Expected: all 30 tests PASS.

- [ ] **Step 3: Run the full suite to confirm no regressions**

```bash
bats tests/harness/
```

Expected: all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add harness/lib/format.sh
git commit -m "feat: add format.sh with Prettier, goimports, and gofmt hook functions"
```

---

### Task 4: Update `generate_workflow_yaml` for formatting checks (TDD)

**Files:**
- Modify: `tests/harness/ci-workflows.bats`
- Modify: `harness/lib/ci-workflows.sh`

Add a `Format (Prettier)` step to all repos and `Install goimports`, `Format (gofmt)`, `Format (goimports)` steps to mixed repos. Write failing tests first, then update the implementation.

- [ ] **Step 1: Append four failing tests to `tests/harness/ci-workflows.bats`**

Add these tests after the existing `generate_workflow_yaml` tests (before the `# ── install_workflow_file ──` section):

```bash
@test "generate_workflow_yaml js pnpm: contains prettier --check, not gofmt" {
  run generate_workflow_yaml "js" "pnpm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"prettier --check"* ]]
  [[ "$output" != *"gofmt"* ]]
}

@test "generate_workflow_yaml js bun: contains prettier --check, not gofmt" {
  run generate_workflow_yaml "js" "bun"
  [ "$status" -eq 0 ]
  [[ "$output" == *"prettier --check"* ]]
  [[ "$output" != *"gofmt"* ]]
}

@test "generate_workflow_yaml mixed pnpm: contains prettier --check and gofmt and goimports" {
  run generate_workflow_yaml "mixed" "pnpm"
  [ "$status" -eq 0 ]
  [[ "$output" == *"prettier --check"* ]]
  [[ "$output" == *"gofmt -l"* ]]
  [[ "$output" == *"goimports -l"* ]]
}

@test "generate_workflow_yaml mixed bun: contains prettier --check and gofmt and goimports" {
  run generate_workflow_yaml "mixed" "bun"
  [ "$status" -eq 0 ]
  [[ "$output" == *"prettier --check"* ]]
  [[ "$output" == *"gofmt -l"* ]]
  [[ "$output" == *"goimports -l"* ]]
}
```

- [ ] **Step 2: Run ci-workflows.bats to confirm the four new tests fail**

```bash
bats tests/harness/ci-workflows.bats
```

Expected: the 4 new tests FAIL. All previously-passing tests still PASS.

- [ ] **Step 3: Commit the failing tests**

```bash
git add tests/harness/ci-workflows.bats
git commit -m "test: add failing generate_workflow_yaml tests for formatting steps (TDD red)"
```

- [ ] **Step 4: Replace `generate_workflow_yaml` in `harness/lib/ci-workflows.sh`**

Replace only the `generate_workflow_yaml` function (lines 29–94). The `_sha256`, `_read_manifest_checksum`, `_write_manifest_entry`, `install_workflow_file`, and `detect_overlapping_workflows` functions are unchanged.

```sh
# generate_workflow_yaml <lang> <pm>
# Emits the full harness-checks.yml content for the given repo type and package manager.
# lang: js | mixed
# pm:   pnpm | bun
generate_workflow_yaml() {
  local lang="$1" pm="$2"

  cat <<'YAML'
name: Harness Checks

on:
  push:
  pull_request:

jobs:
  harness:
    name: harness / checks
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
YAML

  case "$pm" in
    pnpm)
      cat <<'YAML'

      - uses: pnpm/action-setup@v4
        with:
          run_install: false

      - name: Install dependencies
        run: pnpm install --frozen-lockfile
YAML
      ;;
    bun)
      cat <<'YAML'

      - name: Install dependencies
        run: bun install --frozen-lockfile
YAML
      ;;
  esac

  cat <<'YAML'

      - name: Lint (ESLint)
        run: npx eslint .

      - name: Format (Prettier)
        run: npx prettier --check .
YAML

  if [ "$lang" = "mixed" ]; then
    cat <<'YAML'

      - uses: actions/setup-go@v5
        with:
          go-version-file: go.mod

      - name: Lint (golangci-lint)
        uses: golangci/golangci-lint-action@v6
        with:
          version: latest

      - name: Install goimports
        run: go install golang.org/x/tools/cmd/goimports@latest

      - name: Format (gofmt)
        run: |
          unformatted=$(gofmt -l .)
          if [ -n "$unformatted" ]; then
            echo "The following files are not gofmt-formatted:"
            echo "$unformatted"
            exit 1
          fi

      - name: Format (goimports)
        run: |
          unformatted=$(goimports -l .)
          if [ -n "$unformatted" ]; then
            echo "The following files need import formatting:"
            echo "$unformatted"
            exit 1
          fi
YAML
  fi
}
```

- [ ] **Step 5: Run ci-workflows.bats to verify all tests pass**

```bash
bats tests/harness/ci-workflows.bats
```

Expected: all tests PASS including the 4 new ones.

- [ ] **Step 6: Run the full test suite to confirm no regressions**

```bash
bats tests/harness/
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add harness/lib/ci-workflows.sh
git commit -m "feat: add Prettier and gofmt/goimports steps to generated CI workflow"
```

---

### Task 5: Wire `format.sh` into `setup.sh` (TDD)

**Files:**
- Modify: `tests/harness/setup.bats`
- Modify: `harness/setup.sh`

`setup.sh` currently calls `ensure_lint_staged_config` (from `lint.sh`) to write the lint-staged config. `install_prettier_staged` from `format.sh` now owns that config — it writes both ESLint and Prettier in one go. Remove the `ensure_lint_staged_config` call; add `install_prettier_staged` and the new format functions.

- [ ] **Step 1: Append the seven new failing tests to `tests/harness/setup.bats`**

Add these tests at the end of the file:

```bash
@test "creates .prettierrc for JS repo when absent" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  [ -f "$REPO_DIR/.prettierrc" ]
}

@test ".prettierrc excludes tailwind plugin when tailwindcss absent" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  run grep "prettier-plugin-tailwindcss" "$REPO_DIR/.prettierrc"
  [ "$status" -ne 0 ]
}

@test ".prettierrc includes tailwind plugin when tailwindcss in package.json" {
  _pnpm_repo_with_hooks
  printf '{"devDependencies":{"husky":"^9.0.0","tailwindcss":"^3.0.0"}}\n' \
    > "$REPO_DIR/package.json"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "prettier-plugin-tailwindcss" "$REPO_DIR/.prettierrc"
}

@test ".lintstagedrc.json includes prettier --check for JS repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "prettier --check" "$REPO_DIR/.lintstagedrc.json"
}

@test "does not merge gofmt block for JS-only repo" {
  _pnpm_repo_with_hooks
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  run grep "# harness:gofmt:begin" "$REPO_DIR/.husky/pre-commit"
  [ "$status" -ne 0 ]
}

@test "merges gofmt block into pre-commit for mixed repo" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  run bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$status" -eq 0 ]
  grep -q "# harness:gofmt:begin" "$REPO_DIR/.husky/pre-commit"
}

@test "re-run does not duplicate gofmt block for mixed repo" {
  _pnpm_repo_with_hooks
  touch "$REPO_DIR/go.mod"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  bash "$SETUP_SCRIPT" "$REPO_DIR"
  [ "$(grep -c "harness:gofmt:begin" "$REPO_DIR/.husky/pre-commit")" = "1" ]
}
```

- [ ] **Step 2: Run setup.bats to confirm the new tests fail**

```bash
bats tests/harness/setup.bats
```

Expected: the 7 new tests FAIL. All previously-passing tests still PASS.

- [ ] **Step 3: Replace `harness/setup.sh`**

```sh
#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="${1:-$(git rev-parse --show-toplevel)}"

. "$SCRIPT_DIR/lib/detect-language.sh"
. "$SCRIPT_DIR/lib/detect-package-manager.sh"
. "$SCRIPT_DIR/lib/merge-hook.sh"
. "$SCRIPT_DIR/lib/husky.sh"
. "$SCRIPT_DIR/lib/ci-workflows.sh"
. "$SCRIPT_DIR/lib/lint.sh"
. "$SCRIPT_DIR/lib/format.sh"

NVM_BLOCK='# harness:nvm:begin
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
# harness:nvm:end'

REPO_LANG=$(detect_language "$REPO_ROOT")

case "$REPO_LANG" in
  js|mixed)
    REPO_PM=$(detect_package_manager "$REPO_ROOT")
    echo "Detected $REPO_LANG repo — setting up Husky hooks..."
    ensure_husky_installed "$REPO_ROOT"
    ensure_husky_init "$REPO_ROOT"
    ensure_hook_exists "$REPO_ROOT/.husky/pre-push"
    merge_block "$REPO_ROOT/.husky/pre-commit" "nvm" "$NVM_BLOCK" "after-shebang"
    merge_block "$REPO_ROOT/.husky/pre-push" "nvm" "$NVM_BLOCK" "after-shebang"
    ensure_eslint_installed "$REPO_ROOT"
    ensure_eslint_config "$REPO_ROOT"
    ensure_prettier_installed "$REPO_ROOT"
    ensure_prettier_config "$REPO_ROOT"
    ensure_lint_staged_installed "$REPO_ROOT"
    install_lint_staged_hook "$REPO_ROOT"
    install_prettier_staged "$REPO_ROOT"
    if [ "$REPO_LANG" = "mixed" ]; then
      ensure_golangci_lint_available
      ensure_golangci_config "$REPO_ROOT"
      install_golangci_hook "$REPO_ROOT"
      ensure_goimports_available
      install_gofmt_hook "$REPO_ROOT"
    fi
    detect_overlapping_workflows "$REPO_ROOT"
    install_workflow_file "$REPO_ROOT" "$REPO_LANG" "$REPO_PM"
    echo "Done. Husky hooks configured at $REPO_ROOT/.husky/"
    echo "NOTE: Add 'harness / checks' as a required status check in GitHub branch protection to enforce CI linting on PRs."
    ;;
  unsupported)
    echo "ERROR: No package.json found. Pure Go repos are not supported in v1." >&2
    exit 1
    ;;
esac
```

- [ ] **Step 4: Run the full test suite**

```bash
bats tests/harness/
```

Expected: all tests PASS including the 7 new ones. The `install_prettier_staged` call now owns `.lintstagedrc.json`, so the existing Story 9 test "creates .lintstagedrc.json for JS repo when absent" still passes.

- [ ] **Step 5: Commit**

```bash
git add harness/setup.sh tests/harness/setup.bats
git commit -m "feat: wire format.sh into setup.sh — Prettier and gofmt hooks for JS and mixed repos"
```

---

### Task 6: Update `harness/README.md`

**Files:**
- Modify: `harness/README.md`

- [ ] **Step 1: Add Formatting section after the Linting section**

After the closing ` ``` ` of the `gh api` code block under `### Required status check` (around line 116), insert:

```markdown
## Formatting

Setup installs formatting tools and default configs if absent, then merges format hooks into `.husky/pre-commit`.

### JS / TS repos

- Installs `prettier` as a dev dependency (if not already present)
- If `tailwindcss` is detected in `package.json`, also installs `prettier-plugin-tailwindcss`
- Writes a default `.prettierrc` if no Prettier config file exists:
  ```json
  {
    "printWidth": 150,
    "tabWidth": 2,
    "singleQuote": true,
    "bracketSameLine": true,
    "trailingComma": "es5"
  }
  ```
  When `tailwindcss` is detected, `"plugins": ["prettier-plugin-tailwindcss"]` is added.
- Writes `.lintstagedrc.json` targeting `*.{js,jsx,ts,tsx}` with both `prettier --check` and `eslint --max-warnings=0` (in check mode — no auto-fixing)
- The existing `harness:lint` pre-commit block already runs `npx lint-staged`, which triggers both tools on staged files

### Mixed (Go + JS/TS) repos

All of the above, plus:

- Checks for `goimports` in PATH; installs via `go install golang.org/x/tools/cmd/goimports@latest` if absent
- Merges a `harness:gofmt` pre-commit block that runs `gofmt -l` then `goimports -l` on staged `.go` files — fails with actionable errors if any files are not formatted

Formatting failure exits non-zero and outputs which files need formatting — the commit is blocked. Run `gofmt -w <file>` or `goimports -w <file>` to fix.
```

- [ ] **Step 2: Update the `## Directory structure` section**

Replace:

```
    lint.sh                     # ensure_eslint_installed, ensure_golangci_lint_available, install_lint_staged_hook, install_golangci_hook
```

With:

```
    lint.sh                     # ensure_eslint_installed, ensure_golangci_lint_available, install_lint_staged_hook, install_golangci_hook
    format.sh                   # ensure_prettier_installed, ensure_prettier_config, install_prettier_staged, ensure_goimports_available, install_gofmt_hook
```

- [ ] **Step 3: Run all tests to confirm nothing broke**

```bash
bats tests/harness/
```

Expected: all tests PASS.

- [ ] **Step 4: Commit**

```bash
git add harness/README.md
git commit -m "docs: document formatting setup, Prettier config, and gofmt/goimports hooks"
```

---

## Self-Review

### Spec coverage

| AC | Task |
|----|------|
| Harness setup installs Prettier and writes default `.prettierrc` if absent | Task 3 (`ensure_prettier_installed`, `ensure_prettier_config`) + Task 5 (setup.sh) |
| `prettier-plugin-tailwindcss` included when tailwindcss detected | Task 3 (`_has_tailwind` check in both `ensure_prettier_installed` and `ensure_prettier_config`) |
| For mixed repos: installs goimports if absent | Task 3 (`ensure_goimports_available`) + Task 5 (setup.sh mixed block) |
| Husky pre-commit runs Prettier via lint-staged in check mode on staged JS/TS files only | Task 3 (`install_prettier_staged` writes `prettier --check` in `.lintstagedrc.json`); `install_lint_staged_hook` already handles `npx lint-staged` |
| For mixed repos: pre-commit runs gofmt then goimports on staged Go files only | Task 3 (`install_gofmt_hook` — `_STAGED_GO` guard, `gofmt -l`, `goimports -l`) |
| Formatting failure exits non-zero and outputs which files failed | Task 3: `gofmt -l` and `goimports -l` output is captured; non-empty → error message + exit 1. Prettier exits non-zero by design |
| CI workflow runs Prettier `--check` on every PR | Task 4 (`Format (Prettier)` step in `generate_workflow_yaml` for all langs) |
| CI workflow runs gofmt/goimports for mixed repos on every PR | Task 4 (`Format (gofmt)` and `Format (goimports)` steps added to mixed block) |
| CI formatting check is configured as required status check | Same `harness / checks` job — no new job needed; documented in README |

### Placeholder scan

No TBD or TODO entries. All steps include exact code.

### Type consistency

- `_has_tailwind <repo_root>` — called in `ensure_prettier_installed` and `ensure_prettier_config`; both pass `"$repo_root"`. ✓
- `install_prettier_staged` — called in `setup.sh` after `install_lint_staged_hook`. Config written by `install_prettier_staged` supersedes `ensure_lint_staged_config`; `ensure_lint_staged_config` is no longer called from `setup.sh`. ✓
- `ensure_goimports_available` — no args, matches its definition. Called in `setup.sh` inside the `mixed` block alongside `ensure_golangci_lint_available`. ✓
- `install_gofmt_hook <repo_root>` — called in `setup.sh` mixed block; consistent with `install_golangci_hook` pattern. ✓
- `merge_block` calls in `install_gofmt_hook` use 4-arg form (`"append"` position) — consistent with `install_golangci_hook` and `install_lint_staged_hook` in `lint.sh`. ✓
- Block sentinel ID `gofmt` — no conflict with `nvm`, `lint`, `golangci`. ✓
- `generate_workflow_yaml` new Prettier step is always emitted (all langs); gofmt/goimports steps are inside the `if [ "$lang" = "mixed" ]` block — consistent with golangci-lint placement. ✓
