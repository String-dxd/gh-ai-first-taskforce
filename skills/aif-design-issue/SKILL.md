---
name: aif-design-issue
description: Use when a designer or engineer needs to produce a design for a GitHub issue before implementation. Reads the acceptance criteria, explores existing components and patterns in the codebase, maps each scenario to design decisions, and produces either an implemented design branch (for designers) or a design spec document (for engineers). Triggered by "design this issue", "design spec", "design before implementing", "no designer", "prototype this feature".
---

## Overview

This skill runs a structured design phase before implementation. It works for two audiences:

- **Designer:** produces an implemented design in a `design/` branch, ready for user testing and handoff to an engineer via PR.
- **Engineer (no designer available):** produces a `design-spec.md` that maps each acceptance criteria scenario to component choices, layout, states, and interactions — making the design decisions explicit before coding begins.

Both paths read the acceptance criteria first (not screenshots), explore existing codebase patterns, and flag scenarios that need user validation before implementation.

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

## Step 2: Identify who is running this skill

Ask:

> "Are you a designer building the design in the codebase, or an engineer producing a design spec to guide implementation?"

- **Designer** → continue to Step 3, then follow the Designer path from Step 6 onward.
- **Engineer** → continue to Step 3, then follow the Engineer path from Step 6 onward.

## Step 3: Explore the design context

Before making any design decisions, explore the codebase for existing patterns. Look for:

1. **Component library** — check CLAUDE.md and `components/` or equivalent directories. Read the components most likely relevant to this issue (tables, cards, modals, form fields, stat cards, filters).
2. **Existing similar UI** — search for existing pages or features that share structural similarity with this issue's scenarios. Read those files to understand established layout patterns.
3. **Design standards** — check CLAUDE.md for any referenced design standard document or component usage rules.
4. **Reference prototype** — if the issue or comments link to a prototype repo or deployed prototype, note the URL for the user. Do not rely on it as a source of truth for components — the main codebase is authoritative.

If none of these yield useful context, surface the gap:

> "I couldn't find a component library or design reference in this codebase. Before continuing, point me to: (a) the component library path or package, and (b) any design standard document."

## Step 4: Map each AC scenario to design decisions

For each acceptance criteria scenario, produce:

| Field | Description |
|-------|-------------|
| **Components** | Existing components from the library that apply to this scenario |
| **Layout** | Primary structure — what appears above, below, left, right of what |
| **States** | All UI states needed: default, loading, empty, error, restricted, disabled |
| **Interactions** | User actions and what they trigger |
| **New pattern?** | Yes / No — does this scenario require a component or layout not present in the codebase |

## Step 5: Evaluate validation needs

Flag any scenario marked "New pattern? Yes" or that introduces a new user flow:

> "This scenario introduces [X], which doesn't appear in the existing codebase. Validate it with a user or someone user-adjacent before marking the implementation ready for review."

Produce a validation checklist — one item per flagged scenario. Both the designer and engineer will carry this checklist forward.

---

## Step 6 (Designer path): Create a design branch and implement

Create a `design/` branch from main:

```sh
git checkout main && git pull
git checkout -b design/<issue-slug>
```

Work through the acceptance criteria scenarios in order. For each:

1. Implement the UI using Claude Code, explicitly referencing existing components and the design standard identified in Step 3.
2. Review the rendered result for micro-interaction correctness: column alignment, spacing, restricted states, disabled states, empty states. Correct anything that doesn't match the scenario's acceptance criteria.
3. Commit before moving to the next scenario.

### User testing (for flagged scenarios)

For any scenario on the validation checklist, set up a local tunnel so users can access the running app:

1. Start the dev server: `pnpm dev` (or the equivalent start command in CLAUDE.md).
2. In a second terminal, start a tunnel:
   - ngrok: `ngrok http <port>`
   - localtunnel: `lt --port <port>`
3. Share the tunnel URL with the user or user-adjacent colleague. Keep the dev server running for the duration of the session.
4. After the session, note the feedback and any design changes needed before committing.

### Open a draft PR as handoff

When all scenarios are implemented and the validation checklist is addressed (or explicitly deferred with a reason):

```sh
gh label create "skill:aif-design-issue" --color ededed --description "Designed with the aif-design-issue skill" 2>/dev/null || true

gh pr create --draft \
  --title "design: <issue title>" \
  --label "skill:aif-design-issue" \
  --body-file /tmp/design-pr-body.md
```

PR body (`/tmp/design-pr-body.md`) should include:
- Link to the issue this design addresses
- Design decisions log: component choices made and why
- Screenshots of each key state (attach after capturing from the local dev server)
- Validation checklist: which scenarios were user-tested, which were deferred and why

---

## Step 6 (Engineer path): Produce a design spec

Write `design-spec.md` to the current working directory (or the issue branch if one already exists):

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
- <decision>: <rationale>
```

Present the spec and ask for confirmation:

> "Does this match your understanding of what needs to be built? Make any corrections before we proceed to implementation."

Once confirmed, the engineer can proceed to `aif-implement-issue` using this spec as additional context alongside the issue.

---

## Rules

- Read acceptance criteria before looking at reference screenshots. Screenshots are context; the AC scenarios are the source of truth for what to design.
- Never design outside the acceptance criteria — every design decision must map to at least one scenario.
- Use existing components before proposing new ones. If a new component is genuinely required, flag it explicitly.
- Do not implement during the design phase (Engineer path). The design spec feeds `aif-implement-issue`; mixing the two produces unreviewed code.
