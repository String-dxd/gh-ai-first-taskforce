---
name: aif-design-issue
description: Use when a designer or engineer needs to produce a design for a GitHub issue before implementation. Reads the acceptance criteria, explores existing components and patterns in the codebase, maps each scenario to design decisions, implements the design in a branch, and opens a draft PR as handoff. Triggered by "design this issue", "design spec", "design before implementing", "no designer", "prototype this feature".
---

## Overview

This skill runs a structured design phase before implementation. It is for designers and engineers alike — both follow the same process: read the acceptance criteria, explore existing patterns, implement the design scenario by scenario, and open a draft PR as the handoff artifact.

The output is always a `design/` branch with an implemented UI and a `design-spec.md` that records every decision made during the design phase.

---

## Step 1: Fetch and parse the issue

Accept an issue number or pasted markdown body.

- **Issue number:** run `gh issue view $ARGUMENTS --json number,title,body,comments` and read the result.
  - If `gh` is not found: ask the user to paste the issue body directly.
  - If the command fails for any other reason: surface the error and stop.
- **Pasted body:** use it directly.

From the issue, extract:
- All acceptance criteria scenarios (the primary design input — read these before looking at screenshots)
- Design assets section (reference screenshots, deployed links, prototype repo links)
- Technical context section (any components or patterns already identified during grooming)

## Step 2: Explore the design context

Before making any design decisions, explore the codebase for existing patterns. Look for:

1. **Component library** — check CLAUDE.md and `components/` or equivalent directories. Read the components most likely relevant to this issue (tables, cards, modals, form fields, stat cards, filters).
2. **Existing similar UI** — search for existing pages or features that share structural similarity with this issue's scenarios. Read those files to understand established layout and interaction patterns.
3. **Design standards** — check CLAUDE.md for any referenced design standard document or component usage rules.
4. **Reference prototype** — if the issue or comments link to a prototype repo or deployed prototype, note the URL for the user. Do not rely on it as a source of truth for components — the main codebase is authoritative.

If none of these yield useful context, surface the gap:

> "I couldn't find a component library or design reference in this codebase. Before continuing, point me to: (a) the component library path or package, and (b) any design standard document."

## Step 3: Map each AC scenario to design decisions

For each acceptance criteria scenario, produce:

| Field | Description |
|-------|-------------|
| **Components** | Existing components from the library that apply to this scenario |
| **Layout** | Primary structure — what appears above, below, left, right of what |
| **States** | All UI states needed: default, loading, empty, error, restricted, disabled |
| **Interactions** | User actions and what they trigger |
| **New pattern?** | Yes / No — does this scenario require a component or layout not present in the codebase |

## Step 4: Evaluate validation needs

Flag any scenario marked "New pattern? Yes" or that introduces a new user flow:

> "This scenario introduces [X], which doesn't appear in the existing codebase. Validate it with a user or someone user-adjacent before marking the implementation ready for review."

Produce a validation checklist — one item per flagged scenario. This checklist is carried into the `design-spec.md` and the draft PR.

## Step 5: Create the design branch

```sh
git checkout main && git pull
git checkout -b design/<issue-slug>
```

Write `design-spec.md` to the branch root and commit it before any UI work begins:

```markdown
# Design spec: <issue title>

## Design context
- Component library: <path or package>
- Design standard: <link or N/A>
- Reference prototype: <link or N/A>

## Per-scenario decisions

### <Scenario name>
- **Components:** ...
- **Layout:** ...
- **States:** ...
- **Interactions:** ...

## Validation checklist
- [ ] <Scenario>: <what to validate and with whom, before PR is marked ready for review>

## Design decisions log
<!-- Updated throughout implementation as judgment calls are made -->
```

Commit:
```sh
git add design-spec.md
git commit -m "design(<scope>): add design spec for <issue title>"
```

## Step 6: Implement the design

Work through the acceptance criteria scenarios in order. For each:

1. Implement the UI using Claude Code, explicitly referencing existing components and the design standard identified in Step 2.
2. Review the rendered result for micro-interaction correctness: column alignment, spacing, restricted states, disabled states, empty states. Correct anything that doesn't match the scenario's acceptance criteria.
3. Update `design-spec.md` — add any judgment calls made during implementation to the decisions log.
4. Commit before moving to the next scenario.

## Step 7: User testing (for flagged scenarios)

For any scenario on the validation checklist, set up a local tunnel so users can access the running app on their own device:

1. Start the dev server (use the command from CLAUDE.md, or the project's standard dev command).
2. Start a tunnel — ask the user which tool they prefer:
   - **ngrok:** `ngrok http <port>` (requires a free ngrok account)
   - **localtunnel:** `lt --port <port>` (no account needed: `npx localtunnel --port <port>`)
3. Share the tunnel URL. Keep the dev server running for the duration of the testing session.
4. After the session, note the feedback. Make any design changes before the next commit. Update `design-spec.md` with what was validated and the outcome.

## Step 8: Open a draft PR as handoff

When all scenarios are implemented and the validation checklist is addressed (or explicitly deferred with a reason recorded in `design-spec.md`):

```sh
gh label create "skill:aif-design-issue" --color ededed --description "Designed with the aif-design-issue skill" 2>/dev/null || true
```

Write the PR body to `/tmp/design-pr-body.md`, then:

```sh
gh pr create --draft \
  --title "design: <issue title>" \
  --label "skill:aif-design-issue" \
  --body-file /tmp/design-pr-body.md
```

PR body structure:

```markdown
Designs #<issue number>

## Summary
<!-- What was designed and the key decisions made -->

## Validation
<!-- Which scenarios were user-tested, which were deferred and why -->

## Screenshots
<!-- Attach screenshots of each key state from the local dev server -->

---
*🤖 Generated with aif-design-issue*
```

- **If the command succeeds:** print the PR URL.
- **If `gh` is not found:** render the PR title and body as markdown and instruct the user to create the draft PR manually.
- **If the command fails for any other reason:** surface the error and stop.

---

## Rules

- Read acceptance criteria before looking at reference screenshots. Screenshots are context; the AC scenarios are the source of truth for what to design.
- Never design outside the acceptance criteria — every design decision must map to at least one scenario.
- Use existing components before proposing new ones. If a new component is genuinely required, flag it explicitly in the design decisions log.
- The design spec is a live document — update it throughout implementation, not just at the start.
- Do not open the PR as ready for review until every item on the validation checklist is either addressed or explicitly deferred with a reason.
