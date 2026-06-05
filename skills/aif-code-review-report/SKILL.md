---
name: aif-code-review-report
description: Use when asked to review code changes and produce a written feedback report with code snippets and suggestions. Triggers on "review this", "give me feedback on", "review my changes", or any request for a review output document.
---

# Code Review Report

Produce a structured markdown review report for a set of code changes. Each finding shows the relevant code snippet, the problem, and a concrete suggestion — so the author can act without context-switching.

Use `superpowers:requesting-code-review` instead when you need a fast pass during active development and no saved report is needed.

---

## Severity Labels

- **Critical** — data loss, security flaw, crash on reachable path
- **Important** — logic bug, broken contract, missing error handling
- **Suggestion** — cleanup, simplification, reuse opportunity, style

---

## Process

1. Get branch name: `git rev-parse --abbrev-ref HEAD`
   - If the branch is `main`, `master`, `develop`, or `dev`, **stop immediately** and tell the user: "Code reviews are for feature branches only — switch to a feature branch and re-run."
   - Sanitise the branch name for use as a directory: replace `/` with `-`, strip characters outside `[a-zA-Z0-9._-]`. Use this sanitised name (`<safe-branch>`) in all subsequent steps.
2. Check for prior reports: `ls review/<safe-branch>/` (if the directory exists)
   - If prior reports exist, read the most recent one to find the last reviewed HEAD SHA (recorded in the report's "Reviewed Commits" section) and collect all prior findings. Do not prompt the user yet — reconciliation happens after the diff is obtained.
3. Get the diff:
   - **Detect the default branch:** try `main`, then `master`, then `develop`, then `dev` — use whichever resolves as a local ref (`git rev-parse --verify <name>`). If none resolve, stop and tell the user: "Cannot find a base branch — please run: `git fetch origin` and ensure the default branch is checked out locally".
   - **First review:** `git log <base>..HEAD --oneline` to list all branch commits, then `git diff $(git merge-base HEAD <base>)...HEAD` for the full diff. Record every commit SHA + message.
   - **Subsequent review:** Use the last reviewed HEAD SHA from the prior report. Run `git log <last-sha>..HEAD --oneline` to list new commits only, then `git diff <last-sha>..HEAD` for the delta. Record only the new commits.
4. **[Subsequent review only] Large-delta check** — run this before any analysis to decide whether to treat this as a fresh review:
   - Compute `delta_files`: `git diff --name-only <last-sha>..HEAD | wc -l`
   - Compute `branch_files`: `git diff --name-only $(git merge-base HEAD <base>)...HEAD | wc -l`
   - Compute `delta_lines`: insertions + deletions from `git diff --stat <last-sha>..HEAD`
   - Compute `branch_lines`: insertions + deletions from `git diff --stat $(git merge-base HEAD <base>)...HEAD`
   - **Large drift detected** if either condition holds:
     - `delta_files / branch_files > 0.6` — the delta touches more than 60% of the files ever changed on this branch
     - `delta_lines / branch_lines > 0.75` — the delta rewrites more than 75% of the original change volume
   - If large drift is detected: inform the user ("The updated diff is substantially different from what was last reviewed — treating this as a fresh review of the entire branch."), switch to **full-branch diff** (`git diff $(git merge-base HEAD <base>)...HEAD`) and treat as a first review for the 7 review angles. Prior findings are still auto-reconciled in step 9.
5. Run all 7 review angles on the appropriate scope (delta diff for normal subsequent reviews; full-branch diff for first reviews and large-drift cases); collect candidates with `file`, `line`, `summary`, `failure_scenario`
6. Deduplicate near-duplicates (same defect, same location → keep one)
7. Verify each candidate — label as **CONFIRMED**, **PLAUSIBLE**, or **REFUTED**
   - PLAUSIBLE by default for: races, nil on rare-but-reachable paths, falsy-zero, off-by-one, regex missing anchor
   - REFUTED only when provably wrong — cite the exact line or invariant that rules it out
8. For each CONFIRMED or PLAUSIBLE finding, validate the suggestion before writing it:
   - Look for `package.json`, `go.mod`, `requirements.txt`, or `Gemfile` at the repo root
   - If found: check the installed version of any library referenced in the suggestion; if the suggestion uses an API or option not available in that version, revise it to match or note the required upgrade explicitly
   - If none found: note that no manifest was detected, skip version validation, and ensure any shell commands are mentally traced against the failure modes described in the finding
9. Drop all REFUTED findings — see Rules › Refuted findings
10. **[Subsequent review only] Auto-reconcile prior findings** — check each prior finding against the current code (do this silently, without prompting):

    | Prior finding state | Preliminary disposition |
    |---------------------|-------------------------|
    | Code at the flagged location is fixed | **Resolved** |
    | Code at the flagged location is gone (refactored away, deleted) | **No longer applicable** |
    | Finding is still present, unchanged | **Persists** |
    | Finding partially addressed but problem remains | **Partially addressed** |

11. **[Subsequent review only] Prompt about persisting findings** — only after auto-reconciliation, present the findings still marked Persists or Partially addressed and ask:

    > "After reviewing the updated code, N prior finding(s) are still present:
    > 1. [One-line summary] — `file:line`, still present
    > 2. ...
    >
    > For each, will it be fixed? If not, please give a reason."

    Wait for the user's response, then apply final dispositions:

    | User response | Final disposition |
    |---------------|-------------------|
    | Will be fixed | **Persists** — carry forward into Findings with a `(carried over)` note |
    | Won't fix — reason given | **Won't fix** — record reason in the Prior Review table; do not carry into Findings |
    | Not mentioned | Keep the auto-reconciled disposition from step 10 |

12. Count total kept findings (new findings + carried-over prior findings):
    - **< 10:** all findings get full entries including Suggestions
    - **≥ 10:** Critical and Important get full entries; Suggestions roll into a "Cleanup Notes" bullet list
13. Group findings under `### Critical`, `### Important`, `### Suggestion` subsections — omit any subsection with no entries
14. Write the report to `review/<safe-branch>/report-<DDMMYYYYHHMMSS>.md` — create the directory if needed: `mkdir -p review/<safe-branch>`

---

## Review Angles

Run all seven. Each surfaces up to 6 candidates.

| Angle | What to look for |
|-------|-----------------|
| **Line-by-line** | Inverted conditions, off-by-one, null deref, missing `await`, error swallowed in catch |
| **Removed behavior** | Deleted guards, dropped error paths, narrowed validation, deleted tests covering real cases |
| **Cross-file** | Callers broken by changed signature/return shape/precondition; callees made unsafe |
| **Reuse** | New code re-implementing something that already exists in shared/utility modules |
| **Simplification** | Redundant state, copy-paste with slight variation, deep nesting, dead code |
| **Efficiency** | Redundant computation, repeated I/O, sequential work that could be parallel, hot-path blocking |
| **Altitude** | Special-case bandaids layered on shared infrastructure instead of fixing the underlying mechanism |

---

## Re-review

**Scope:** Only the new commits (delta since last review) are analysed for new findings through the 7 review angles, unless large drift is detected (see step 4) — in which case the full branch diff is analysed. Prior findings are auto-reconciled against the current code (step 10) and the user is only prompted about those still present (step 11).

**Large-drift fallback:** When the delta is too large relative to the original reviewed scope, the review defaults to full-branch mode. This prevents a partial delta review from missing regressions introduced alongside the rewrite. Prior findings are still reconciled either way.

---

## Report Template

```markdown
# Code Review — <branch> (<YYYY-MM-DD HH:MM>)

> **File:** `review/<safe-branch>/report-<DDMMYYYYHHMMSS>.md`
> **Based on:** commits up to `<HEAD short SHA>` *(first review: full branch since `<base>`; subsequent: delta since `<prior HEAD SHA>`)*
> *(Large-drift review: full branch diff used — delta exceeded threshold)* ← include only if large drift was detected

## Summary

| Severity | Count |
|----------|-------|
| Critical | N |
| Important | N |
| Suggestion | N |

<One paragraph: what the change does well, the biggest risk, recommended next step.>

---

## Reviewed Commits

| SHA (short) | Message |
|-------------|---------|
| `abc1234` | feat: add X |

*First review: all commits on branch since diverging from the default branch. Subsequent reviews: only commits since the last reviewed SHA. The bottom row of this table is the HEAD SHA — it is used as the delta anchor for the next review.*

---

## Prior Review  *(omit on first review)*

> Previous report: `review/<safe-branch>/report-<prior-DDMMYYYYHHMMSS>.md`

| # | Finding | Disposition |
|---|---------|-------------|
| 1 | <one-line summary> | ✅ Resolved / ➖ No longer applicable / ⚠️ Persists / 🔶 Partially addressed / 🚫 Won't fix — <reason> |

*Persists and Partially addressed findings are carried forward into Findings below.*

---

## Findings

### Critical

#### 1. <One-sentence summary>

**File:** `path/to/file.ext` · **Line:** 42
*(carried over from <prior date> — partially addressed)* ← include only if applicable

```<lang>
// 5–15 lines of context; mark the problem line with // ←
```

**Problem:** What breaks, what input/state triggers it, what goes wrong.

**Suggestion:**
```<lang>
// Corrected version
```

> Optional one-line tradeoff note.

---

### Important

#### 1. <One-sentence summary>

*(same structure as Critical)*

---

### Suggestion  *(omit when total findings ≥ 10 — use Cleanup Notes instead)*

#### 1. <One-sentence summary>

*(same structure as Critical)*

---

## Cleanup Notes  *(only when total findings ≥ 10)*

- One bullet per suggestion-level finding — no code excerpts needed

---

## What Looks Good

- 2–4 specific strengths — name the design decision, not just "good code"
```

---

## Output File

- Path: `review/<safe-branch>/report-<DDMMYYYYHHMMSS>.md` relative to the repo root (`<safe-branch>` defined in step 1)
- Datetime: local time, 24-hour — e.g. `report-03062026143045.md`
- After writing (step 14), print: `Report saved: review/<safe-branch>/<filename>.md`

---

## Rules

**Code excerpts:** 5–15 lines of context · correct language fence identifier · mark problem line with `// ←`

**Problem statements:** name the concrete failure — inputs → wrong output/crash/data loss; never "this could be a problem"

**Suggestions:** always show corrected code; if no single fix is right, show two options with a one-line tradeoff note

**What looks good:** always include; specifics only; 2–4 bullets max

**Scope:** every confirmed or plausible Critical/Important — no cap; Suggestions in full when < 10 total, rolled into Cleanup Notes when ≥ 10

**Refuted findings:** drop silently — no struck-through text, no "considered but dismissed" note, no mention at all
