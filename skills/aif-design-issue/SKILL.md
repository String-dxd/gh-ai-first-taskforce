---
name: aif-design-issue
description: Runs a structured design phase for a GitHub issue before implementation. Reads acceptance criteria, explores existing codebase components and patterns, maps each scenario to component choices, layout, states, and interactions, implements the design in a design/ branch, and opens a draft PR as handoff. Suitable for designers and engineers alike. Triggered by "design this issue", "design spec", "design before implementing", "prototype this feature", "no designer available".
---

## Workflow

Copy this checklist and track your progress:

```
Design progress:
- [ ] Step 1: Fetch and parse the issue
- [ ] Step 2: Explore the design context
- [ ] Step 3: Map each scenario to design decisions
- [ ] Step 4: Evaluate validation needs
- [ ] Step 5: Create design branch and commit design-spec.md
- [ ] Step 6: Implement each scenario
- [ ] Step 7: User test flagged scenarios
- [ ] Step 8: Open draft PR as handoff
```

## Step 1: Fetch and parse the issue

Accept an issue number or pasted markdown body.

- **Issue number:** `gh issue view $ARGUMENTS --json number,title,body,comments`
  - If `gh` is not found: ask the user to paste the issue body directly.
  - Any other failure: surface the error and stop.
- **Pasted body:** use as-is.

Extract: acceptance criteria scenarios, design assets (screenshots, prototype links), technical context (components identified during grooming).

Read the acceptance criteria before looking at any reference screenshots. The AC scenarios are the source of truth for what to design.

## Step 2: Explore the design context

Look for:

1. **Component library** — check CLAUDE.md and `components/` or equivalent. Read components most relevant to this issue.
2. **Existing similar UI** — find pages or features with structural similarity to this issue's scenarios. Read those files for established layout and interaction patterns.
3. **Design standards** — check CLAUDE.md for a referenced design standard or component usage rules.
4. **Reference prototype** — if the issue links to a prototype or deployed app, note the URL. The main codebase is the source of truth for components; the prototype is visual reference only.

If none of the above yield useful context:

> "I couldn't find a component library or design reference in this codebase. Point me to: (a) the component library path or package, and (b) any design standard document."

## Step 3: Map each scenario to design decisions

For each acceptance criteria scenario:

| Field | Description |
|-------|-------------|
| **Components** | Existing components from the library that apply |
| **Layout** | What appears above, below, left, right of what |
| **States** | All UI states: default, loading, empty, error, restricted, disabled |
| **Interactions** | User actions and what they trigger |
| **New pattern?** | Yes / No — component or layout not present in the codebase |

See [reference/design-spec-template.md](reference/design-spec-template.md) for the full spec structure.

## Step 4: Evaluate validation needs

Flag any scenario where **New pattern? = Yes** or that introduces a new user flow:

> "This scenario introduces [X], which doesn't appear in the existing codebase. Validate it with a user or someone user-adjacent before marking implementation ready for review."

Produce a validation checklist — one item per flagged scenario. Carry it into the spec and the PR.

## Step 5: Create the design branch and commit the spec

```sh
git checkout main && git pull
git checkout -b design/<issue-slug>
```

Write `design-spec.md` using the template in [reference/design-spec-template.md](reference/design-spec-template.md). Commit it before any UI work begins:

```sh
git add design-spec.md
git commit -m "design(<scope>): add design spec for <issue title>"
```

## Step 6: Implement each scenario

Work through the scenarios in order. For each:

1. Implement the UI with Claude Code, referencing existing components and the design standard from Step 2.
2. Review the rendered result for micro-interaction correctness: column alignment, spacing, restricted states, disabled states, empty states. Correct anything that doesn't match the scenario's AC.
3. Update the decisions log in `design-spec.md` with any judgment calls made.
4. Commit before moving to the next scenario.

## Step 7: User test flagged scenarios

For any scenario on the validation checklist:

1. Start the dev server (use the command from CLAUDE.md or the project's standard command).
2. Start a tunnel — use **localtunnel** by default (no account needed):
   ```sh
   npx localtunnel --port <port>
   ```
   If the user already has ngrok: `ngrok http <port>`.
3. Share the tunnel URL. Keep the dev server running for the session.
4. After the session: record the feedback, make any design changes, update `design-spec.md` with what was validated and the outcome, then commit.

## Step 8: Open a draft PR as handoff

Once all scenarios are implemented and the validation checklist is addressed (or explicitly deferred with a reason recorded in `design-spec.md`):

```sh
gh label create "skill:aif-design-issue" --color ededed --description "Designed with the aif-design-issue skill" 2>/dev/null || true

gh pr create --draft \
  --title "design: <issue title>" \
  --label "skill:aif-design-issue" \
  --body-file /tmp/design-pr-body.md
```

See [reference/pr-body-template.md](reference/pr-body-template.md) for the PR body structure.

- **Success:** print the PR URL.
- **`gh` not found:** render the PR title and body as markdown; ask the user to create it manually.
- **Any other failure:** surface the error and stop.

---

## Rules

- Read acceptance criteria before reference screenshots — the AC is the source of truth.
- Every design decision must map to at least one scenario. Don't design outside the AC.
- Use existing components before proposing new ones. Flag new components explicitly in the decisions log.
- `design-spec.md` is a live document — update it throughout implementation, not just at the start.
- Do not open the PR as ready for review until every validation checklist item is addressed or deferred with a reason.
