---

name: pre-merge-audit
description: Run a pre-merge audit of the current changes against the SuMS project rules in CLAUDE.md. Each check is classified as [AUTOMATED] (husky hooks), [AGENT E2E] (shell/grep verifiable), or [HUMAN REQUIRED] (requires human execution). Auth flows through OTPaaS or government SSO are always [HUMAN REQUIRED] — agent E2E is structurally blocked. Use after introducing new features or bug fixes, and before making a pull request.

---

## Criterion Classification

Each check in this audit is classified as one of:

- **[AUTOMATED]** — enforced by a husky pre-commit or pre-push hook. No agent or human action is needed beyond confirming the hooks are installed.
- **[AGENT E2E]** — verifiable by shell commands, grep, or automated test runs. The agent can execute and evaluate the result without human involvement.
- **[HUMAN REQUIRED]** — requires a human to manually execute and observe. Cannot be satisfied by agent tooling.

> **Auth flows are always [HUMAN REQUIRED].** Any criterion that passes through the login flow — OTP request, OTP delivery via OTPaaS, code entry, session creation, or logout — must be tested by a human. Agent E2E is **structurally blocked**: OTP delivery requires a real inbox, and OTPaaS requires a government-registered email that cannot be provisioned in an automated test environment.

---

## Automated checks [AUTOMATED]

All checks in this section are enforced by husky hooks. Confirm the hooks are active; no further action is needed for these items.

| Check | Hook | Trigger |
|---|---|---|
| Secret scanning (gitleaks) | `pre-commit` | every commit |
| `any` casts + eslint-disable | `pre-commit` | every commit |
| Dockerfile COPY prisma | `pre-commit` | when Dockerfile staged |
| Build-time DB/API calls | `pre-commit` | when `.ts`/`.tsx` staged |
| Raw SQL unsafe patterns | `pre-commit` | when `.ts`/`.tsx` staged |
| npm audit (high/critical) | `pre-push` | every push |
| tsc --noEmit | `pre-push` | every push |

Verify hooks are installed:
```
cat .husky/pre-commit
cat .husky/pre-push
```

---

## Agent-verifiable checks [AGENT E2E]

### 1. Credentials & Secrets [AGENT E2E]

- Confirm `.env.example` is tracked by git: `git ls-files .env.example`
- Confirm `.gitignore` does not use `env*` wildcard: `grep "env\*" .gitignore`
- Confirm no `.env`, `.env.local`, or `.env.*.local` files are staged: `git diff --name-only --cached | grep "^\.env"`

**Block on:** `.env.example` not tracked, `env*` wildcard in `.gitignore`, any env file staged.

---

### 2. Code Organisation [AGENT E2E]

- Check for shared lookup data (arrays of categories, enums, static lists) declared as local variables in page files rather than imported from `lib/`:
  ```
  grep -rn "const.*=\s*\[" src/app --include="*.tsx" --include="*.ts"
  ```
  Flag any that appear in more than one file.
- Check for files that appear deprecated or superseded (old action files alongside new ones with the same purpose). List them and ask if they should be deleted.

**Block on:** duplicate shared constants across page files.

---

### 3. Docker & Prisma [AGENT E2E]

If `Dockerfile` or `prisma/` was changed (hook catches the COPY rule — verify the rest):
- Confirm `prisma migrate deploy` is present in the deployment runbook or startup script.

---

### 4. Raw SQL Queries [AGENT E2E]

If any file in the diff contains `$queryRaw`, `$executeRaw`, `$queryRawUnsafe`, `$executeRawUnsafe`, or `Prisma.raw`:

```
grep -rn "\$queryRaw\|\$executeRaw\|Prisma\.raw" src --include="*.ts" --include="*.tsx"
```

For each match, verify:
- **No `$queryRawUnsafe` / `$executeRawUnsafe`** is used with any value traceable to user input (request body, query params, headers). These bypass prepared-statement parameterization entirely.
- **No `Prisma.raw()`** wraps a dynamic or user-supplied value — it must only wrap hard-coded string literals (e.g. column/table names controlled entirely in code).
- All user-supplied values reach the query via `$queryRaw` tagged template interpolation (`${value}`), `Prisma.sql`, or `Prisma.join`. Confirm the data-flow from request parsing (e.g. Zod schema) through to the query parameters.

> The husky `pre-commit` hook blocks the obvious patterns (`$queryRawUnsafe`, `Prisma.raw(`) automatically. This check covers the judgment call: is the parameterized usage actually correct end-to-end?

**Block on:** `Prisma.raw()` or `$queryRawUnsafe` / `$executeRawUnsafe` with any value traceable to user input.

---

### 5. Infrastructure [AGENT E2E]

If any infrastructure code (`terraform/`, `*.tf`, Dockerfile, CI/CD pipeline configs) was changed:
- Confirm no KMS configuration was modified without an explicit comment explaining the human review that approved it.
- Confirm no `aws apply` or equivalent is wired to run locally from a developer machine.
- Confirm TLS/certificate type (regional vs global) is documented in the PR description.

**Block on:** autonomous KMS modification, local prod apply wired in pipeline.

---

### 6. Environment Configuration [AGENT E2E]

- Confirm `.env.example` is up to date — every `process.env.X` referenced in the codebase should have a placeholder entry:
  ```
  grep -rn "process\.env\." src --include="*.ts" --include="*.tsx" | grep -oE "process\.env\.[A-Z_]+" | sort -u
  ```
  Compare against keys in `.env.example`.
- Confirm no new env vars were introduced without a corresponding `.env.example` entry.

**Block on:** env var used in code with no `.env.example` entry.

---

### 7. Test Plan Coverage [AGENT E2E]

Extract the test plan from the PR description (section headed "Test plan", "Steps to test", "Testing", or "How to test"). For each step:

1. Identify 2–3 keywords from the step (e.g. "prefill", "resetForm", "division", "empty").
2. Search for those keywords across all test files:
   ```
   grep -rn "<keyword>" src/test/ tests/api/ --include="*.test.ts" --include="*.test.tsx"
   ```
3. If no test file contains a match for a step: flag it as uncovered.

If the PR description has no test plan section at all: flag it as missing.

> **Note:** Test plan steps that exercise the login flow or OTP delivery cannot be covered by automated tests. Do not flag these as automated-coverage gaps — they belong in the [HUMAN REQUIRED] auth checklist (Section 8) instead.

**Block on:** any non-auth test plan step with no corresponding automated test coverage.

---

## Human-required checks [HUMAN REQUIRED]

### 8. Auth & Login Flow Testing [HUMAN REQUIRED]

> **Agent E2E is structurally blocked for this entire section.**
> OTP delivery requires a real inbox. OTPaaS requires a government-registered email address. No agent tool can execute or verify these flows end-to-end. A human tester must complete every applicable item below.

**Applies when any of the following paths appear in the diff:**

```bash
git diff main...HEAD --name-only | grep -E "(app/\(auth\)|app/login|lib/otpaas|app/api/auth|next-auth|nextauth|middleware\.ts)"
```

If no auth-related paths are found: mark this section **N/A**.

If applicable, a human tester must verify all of the following before the branch is merge-ready:

**OTP request flow:**
- [ ] Enter a registered email address on the login page and submit
- [ ] Confirm the OTP email arrives in the inbox within the expected time
- [ ] Confirm the "Resend code" button is disabled during the request round-trip and re-enabled after

**OTP entry & session creation:**
- [ ] Enter the correct OTP code → confirm redirect to the expected post-login page
- [ ] Enter an incorrect OTP code → confirm a clear, user-friendly error message is shown (no raw JSON blob)
- [ ] Enter an expired OTP code → confirm an appropriate error message is shown

**Error handling:**
- [ ] Enter an unregistered email address → confirm a user-friendly error is shown (not `code: 2005` raw from OTPaaS)
- [ ] Submit with an empty email field → confirm client-side validation blocks submission

**Session persistence & logout:**
- [ ] Refresh the page after login → confirm the session is preserved and the user remains logged in
- [ ] Click logout → confirm the session is destroyed and the user is redirected to the login page
- [ ] After logout, navigate directly to a protected route → confirm redirect back to login

**Block on:** any of the above steps failing.

---

## Summary

After reviewing, output two distinct sections.

### Agent-Verifiable Results

| Check | Classification | Status | Findings |
|---|---|---|---|
| Husky hooks active | AUTOMATED | PASS / FAIL | |
| Credentials & Secrets | AGENT E2E | PASS / FAIL | |
| Code Organisation | AGENT E2E | PASS / WARN | |
| Docker & Prisma | AGENT E2E | PASS / FAIL / N/A | |
| Raw SQL Queries | AGENT E2E | PASS / FAIL / N/A | |
| Infrastructure | AGENT E2E | PASS / FAIL / N/A | |
| Environment Config | AGENT E2E | PASS / FAIL | |
| Test Plan Coverage | AGENT E2E | PASS / FAIL / N/A | |

**FAIL on any Critical or High item = not merge-ready.** WARN items should be resolved before go-live but do not block merge.

### Human Testing Required

Output this block every time — it must not be omitted even when no other issues are found:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
HUMAN TESTING REQUIRED — NOT SATISFIED BY THIS AUDIT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Auth & Login Flow Testing (Section 8):  APPLICABLE / N/A

If APPLICABLE: a human tester must complete all steps in Section 8
before this branch is merge-ready.

The agent audit above does NOT satisfy this gate.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
