# Design: AI-Assisted Local Pre-Push Review (Issue #13)

**Date:** 2026-05-22
**Status:** Draft
**Issue:** [#13](https://github.com/transformteamsg/ai-first-taskforce/issues/13)

---

## Problem

Developers only get AI review feedback after a PR is opened and CI runs — too late to catch issues before peers look at the code. This story moves that feedback to the developer's terminal, before the push.

---

## Goals

- Surface AI code review in the terminal as part of the pre-push flow
- Zero friction to skip: non-blocking, no key = no error, no Claude = no error
- Installed for all repos by default — no opt-in toggle required

## Non-goals

- Posting anything to GitHub (that is issue #25)
- Blocking the push on review findings
- Supporting non-Claude models in v1

---

## Architecture

```
harness/setup.sh
  └─ sources harness/lib/ai-review.sh
       └─ install_ai_review_hook()
            ├─ installs harness/scripts/ai-review-runner.sh → <repo>/.harness/ai-review-runner.sh
            └─ merges call block into .husky/pre-push
```

Two new files:

- **`harness/lib/ai-review.sh`** — install-time logic: copies the runner script and wires the pre-push hook.
- **`harness/scripts/ai-review-runner.sh`** — the review script itself, installed into the target repo at `.harness/ai-review-runner.sh`. This is where the review logic lives and what the pre-push hook calls.

Keeping the runner as a standalone installed script means it can be read, debugged, and run independently (`sh .harness/ai-review-runner.sh`) without touching the hook.

`setup.sh` sources `ai-review.sh` and calls `install_ai_review_hook` unconditionally after the existing hook setup. `.harness.yml` is read for optional overrides (`model`, `api_key_secret`, `exclude_patterns`) but its absence does not skip the install.

---

## Components

### `harness/scripts/ai-review-runner.sh`

The review script installed into every target repo at `.harness/ai-review-runner.sh`. Contains one function and its invocation:

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

  echo "harness: running AI pre-push review..."
  printf 'Review the following diff for code quality, potential bugs, and logic issues. Be concise.\n\n%s\n' \
    "$diff" | claude --model "$HARNESS_AI_MODEL" -p /dev/stdin || true
}

_harness_ai_review
```

The `HARNESS_AI_MODEL` and `HARNESS_AI_KEY_VAR` environment variables are set by the pre-push hook block (substituted at install time from `.harness.yml`), so the script stays generic and the config lives in one place.

The `exclude_patterns` from `.harness.yml` replace the hardcoded pathspecs in the `git diff` call at install time. If no patterns are configured, the harness defaults above apply.

### `harness/lib/ai-review.sh`

Install-time functions only — no review logic here.

**`parse_harness_config <repo_root> <key>`**
Reads `.harness.yml` at `<repo_root>` and returns the scalar value for a dotted key (e.g. `ai_review.model`). Uses `grep`/`sed` — no external YAML parser. Returns empty string if the file or key is absent.

**`install_ai_review_runner <repo_root>`**
Copies `harness/scripts/ai-review-runner.sh` (with exclude patterns substituted) to `<repo_root>/.harness/ai-review-runner.sh`. Creates `.harness/` if needed.

**`install_ai_review_hook <repo_root> <model> <api_key_var>`**
Calls `install_ai_review_runner`, then merges the call block into `.husky/pre-push` using the existing `merge_block` function:

```sh
# harness:ai-review:begin
HARNESS_AI_MODEL="<model>" HARNESS_AI_KEY_VAR="<api_key_var>" \
  sh "$(git rev-parse --show-toplevel)/.harness/ai-review-runner.sh"
# harness:ai-review:end
```

### `harness/setup.sh`

After the existing hook setup, unconditionally add:

```sh
AI_MODEL=$(parse_harness_config "$REPO_ROOT" "ai_review.model")
AI_KEY_VAR=$(parse_harness_config "$REPO_ROOT" "ai_review.api_key_secret")
install_ai_review_hook "$REPO_ROOT" \
  "${AI_MODEL:-claude-sonnet-4-6}" \
  "${AI_KEY_VAR:-ANTHROPIC_API_KEY}"
echo "AI pre-push review hook installed."
```

### `.harness.yml` (in target repos, optional)

```yaml
ai_review:
  model: "claude-sonnet-4-6"          # optional, default: claude-sonnet-4-6
  api_key_secret: "ANTHROPIC_API_KEY" # name of the local env var, optional
  exclude_patterns:                   # optional, harness defaults apply if absent
    - "**/*.lock"
    - "**/package-lock.json"
    - "**/go.sum"
    - "**/*.generated.*"
    - "**/dist/**"
```

---

## Data Flow

```
git push
  └─ pre-push hook fires
       ├─ [existing hooks: lint, format, typecheck, gitleaks]
       └─ .harness/ai-review-runner.sh
            ├─ claude CLI present?  no → warn + return 0
            ├─ API key set?         no → warn + return 0
            ├─ git diff upstream..HEAD (exclude patterns applied)
            ├─ diff empty?          yes → skip + return 0
            └─ pipe diff to: claude --model <model> -p /dev/stdin
                 └─ review printed to terminal
                      └─ exit 0 always
```

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| `claude` CLI not installed | One-line warning, skip, exit 0 |
| API key env var unset or empty | One-line warning, skip, exit 0 |
| No upstream branch configured | Falls back to `origin/main` |
| Diff is empty after filtering | One-line message, skip, exit 0 |
| `claude` CLI exits non-zero | `|| true` ensures exit 0 (push not blocked) |
| `.harness.yml` absent or `ai_review` block missing | `parse_harness_config` returns empty; setup uses defaults |

---

## Testing

New file: `tests/harness/ai-review.bats`

Scenarios:
- `parse_harness_config` returns correct value for a present key
- `parse_harness_config` returns empty for absent key or missing file
- `install_ai_review_runner` copies the runner script to `.harness/ai-review-runner.sh`
- `install_ai_review_hook` merges the call block into `.husky/pre-push`
- `install_ai_review_hook` is idempotent (re-running does not duplicate the block)
- Setup always installs the hook regardless of `.harness.yml` content
- Runner skips gracefully when `claude` mock is absent (using `tests/mocks/`)
- Runner skips gracefully when API key env var is unset

A mock `claude` binary is added to `tests/mocks/` that echoes a canned review, allowing end-to-end runner execution to be tested without a real API call.

---

## Open Questions

None — all decisions resolved during brainstorming.
