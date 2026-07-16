---
name: aif-design-issue
description: Runs a structured design phase for a GitHub issue before implementation. Reads acceptance criteria, establishes intent, explores existing components, produces a design plan, implements the design in a design/ branch with non-negotiable quality checks applied throughout, and opens a draft PR as handoff. Suitable for designers and engineers alike. Triggered by "design this issue", "design spec", "design before implementing", "prototype this feature", "no designer available".
---

## Workflow

Copy this checklist and track your progress:

```
Design progress:
- [ ] Step 1: Fetch and parse the issue
- [ ] Step 2: Explore the design context
- [ ] Step 3: Establish intent
- [ ] Step 4: Produce the design plan (new page/flow or modification)
- [ ] Step 5: Human gate — approve the plan
- [ ] Step 6: Create design branch and commit design-spec.md
- [ ] Step 7: Implement each scenario with E2E test
- [ ] Step 8: Run full E2E suite and fix failures
- [ ] Step 9: User test flagged scenarios
- [ ] Step 10: Open draft PR as handoff
```

---

## Step 1: Fetch and parse the issue

Accept an issue number or pasted markdown body.

- **Issue number:** `gh issue view $ARGUMENTS --json number,title,body,comments`
  - If `gh` is not found: ask the user to paste the issue body directly.
  - Any other failure: surface the error and stop.
- **Pasted body:** use as-is.

Extract: acceptance criteria scenarios, design assets (screenshots, prototype links), technical context (components identified during grooming).

Read the acceptance criteria before looking at any reference screenshots — the AC scenarios are the source of truth for what to design.

## Step 2: Explore the design context

Look for:

1. **Component library** — check CLAUDE.md and `components/` or equivalent. Read components most likely relevant to this issue.
2. **Component manifest** — if `.tfx/component-manifest.json` or equivalent exists, use it to determine which components are stable and available. Do not compose components outside this list without flagging it.
3. **Existing similar UI** — find pages or features with structural similarity. Read those files for established layout and interaction patterns.
4. **Design standards** — check CLAUDE.md for a referenced design standard, token scale, or component usage rules.
5. **Reference prototype** — if the issue links to a prototype or deployed app, note the URL. The main codebase is authoritative; the prototype is visual reference only.

If no component library or design reference is found:

> "I couldn't find a component library or design reference. Point me to: (a) the component library path or package, and (b) any design standard document."

## Step 3: Establish intent

Before planning anything, record:

1. **Purpose** — what must the user accomplish on this surface? One sentence. Does this help them work faster with less friction? If not, raise it before designing anything.
2. **The user and the moment** — who is this for and in what context? Name a specific user type and the moment this serves (e.g. "a teacher entering marks the week before reports are due").
3. **Surface type** — is this a new page or flow, or a modification to an existing one?
   - **New page or flow** → run all steps including a diverge phase in Step 4.
   - **Modification** (add a field, restyle a component, adjust a layout region) → run a scoped plan in Step 4. Skip the diverge phase.
4. **Done-criteria** — 3–5 statements the plan will be graded against. Write these before producing any design options.

## Step 4: Produce the design plan

### New page or flow — diverge first

Produce 2–3 structurally different options. For each option:
- Layout structure (regions, primary focal point, reading order)
- Which existing components it composes
- How the flow is divided across steps (for multi-step interactions)
- One sentence on the trade-off

Then recommend one and explain why. The user picks.

Expand the chosen option into a full plan:
- Page/step structure and the component for each region
- **Interaction plan** — name specific interactions (entrance, state transitions, hover/reveal) described concretely (what moves, from what to what). Reuse existing motion conventions. No bounce or elastic easing.
- **Async states** — for every async action, name the loading, success, and error states, and which component or pattern handles each
- **Flow map** (for multi-step interactions) — entry points, the done state, every exit (back, cancel, abandon), what happens to in-progress work on interruption, and how partial completion is resumed
- **Copy outline** — headings, labels, error messages. Write these now, not during implementation. Error messages follow the anatomy: what happened → what it means → what to do next
- **E2E test mapping** — for each AC scenario, name the E2E test that will verify it: what it navigates to, what it interacts with, and what observable outcome it asserts
- **Validation needs** — flag any scenario that introduces a new pattern or new user flow (see below)

### Modification — scoped plan

Name only the controls and regions the changed surface touches. A modification still binds its non-negotiables — adding a field triggers accessible label requirements; restyling a component triggers token and contrast requirements.

## Step 5: Human gate — approve the plan

**Stop here.** Show the full plan and ask for approval before creating any branch or writing any code. This is the cheapest place for human judgment — structural mistakes caught here cost a conversation, not a rebuild.

Confirm which scenarios are on the **validation checklist** (new patterns or new user flows that need user or user-adjacent feedback before the PR is marked ready).

Do not proceed until the plan is explicitly approved.

## Step 6: Create the design branch and commit the spec

```sh
git checkout main && git pull
git checkout -b design/<issue-slug>
```

Write `design-spec.md` using the template in [reference/design-spec-template.md](reference/design-spec-template.md). Commit it before any UI work:

```sh
git add design-spec.md
git commit -m "design(<scope>): add design spec for <issue title>"
```

## Step 7: Implement each scenario with E2E test

Work through the scenarios in order. For each:

1. Implement the UI referencing existing components and the design standard from Step 2.
2. Apply the non-negotiables and quality checks below.
3. Write the E2E test for this scenario, mapped from the plan's E2E test mapping. The test must assert user-observable outcomes (what appears on screen, what the user can do) — not implementation details. Confirm the new test passes before continuing.
4. Update the decisions log in `design-spec.md` with judgment calls made.
5. Commit the UI change and its E2E test together before moving to the next scenario.

### Non-negotiables (apply to every scenario)

These never bend. If one seems impossible, surface it as a blocking question rather than making a judgment call:

- **Contrast** — AA minimum (4.5:1 for normal text, 3:1 for large text and UI components)
- **Keyboard reach** — every interactive element reachable by keyboard with a visible focus state
- **Visible labels** — every form field has a visible label (not placeholder-only)
- **Destructive actions** — show consequences and offer undo or confirmation before executing

### Layout checks

- One clear focal region — the user's primary task and its single primary action
- Visual reading order matches the task's priority order
- Density fits the task (data-dense tasks like tables warrant compact density; onboarding warrants more space)
- Shared edges align

### Flow checks (for multi-step interactions)

- A non-destructive exit exists at every step; in-progress work is preserved or explicitly discarded on interruption — never silently lost
- Every async state change has a loading, success, and error state
- Keyboard traversal works across the whole journey, not just within each screen
- Focus lands somewhere sensible after every step change

### Copy checks

Write copy during implementation, not as a cleanup pass:

- State what happened → what it means → what to do next (error messages)
- Active voice, second person, sentences under 25 words
- No AI writing tells: no "seamless", "empower", "supercharge", "delve", em-dash chains, or filler openers ("In order to…", "It is important to note that…")
- Name the action, not the input device: "select", "choose", "view" — not "click", "tap", "press"

### Anti-slop checks

The default AI aesthetic is a defect. Before committing each scenario:

- No purple or violet gradients
- No nested cards (use space, type, and dividers to group instead)
- No grids of identical cards as a default layout
- No bounce or elastic easing on interface elements
- No decorative animations on critical paths
- Cards only for interactive units — static content grouped with spacing and dividers, not card chrome
- Complex multi-section tasks get a page, not a modal

## Step 8: Run full E2E suite and fix failures

Once all scenarios are implemented, run the full E2E suite — not just the newly added tests. Use the command from CLAUDE.md, or the project's standard E2E command (e.g. `pnpm test:e2e`, `npx playwright test`).

For each failing test, determine its cause before acting:

- **Outdated test** — the test covered UI that the design changed (different copy, new layout, removed element). Update the test to match the new design and confirm it passes. Record the update in `design-spec.md` under the decisions log.
- **Real regression** — the design broke behaviour that should still work. Fix the implementation, not the test. Do not delete or skip a failing test to make the suite pass.
- **Flaky test** — the test is intermittent and unrelated to this change. Note it explicitly; do not let it block the PR, but do not silently ignore it either.

All tests — new and pre-existing — must pass before proceeding. Do not open the PR with a failing suite.

## Step 9: User test flagged scenarios

For any scenario on the validation checklist:

1. Start the dev server (use the command from CLAUDE.md or the project's standard dev command).
2. Start a tunnel — use **localtunnel** by default (no account needed):
   ```sh
   npx localtunnel --port <port>
   ```
   If the user already has ngrok: `ngrok http <port>`.
3. Share the tunnel URL. Keep the dev server running for the session.
4. After the session: record feedback, make design changes, update `design-spec.md` with what was validated and the outcome, then commit.

## Step 10: Open a draft PR as handoff

Once all scenarios are implemented and every validation checklist item is addressed or explicitly deferred with a reason recorded in `design-spec.md`, write the PR body to `/tmp/design-pr-body.md` using the template in [reference/pr-body-template.md](reference/pr-body-template.md).

Fill the acceptance criteria table with one row per AC scenario: the scenario name, the path to its E2E test file, and whether it passed (✅) or failed (❌) in the Step 8 run. Every row must be filled — do not omit scenarios or leave the pass/fail column blank.

```sh
gh label create "skill:aif-design-issue" --color ededed --description "Designed with the aif-design-issue skill" 2>/dev/null || true

gh pr create --draft \
  --title "design: <issue title>" \
  --label "skill:aif-design-issue" \
  --body-file /tmp/design-pr-body.md
```

See [reference/pr-body-template.md](reference/pr-body-template.md) for the PR body structure.

- **Success:** print the PR URL.
- **`gh` not found:** render the PR title and body as markdown; instruct the user to create it manually.
- **Any other failure:** surface the error and stop.

---

## Rules

- Read acceptance criteria before reference screenshots — the AC is the source of truth.
- Every design decision must map to at least one scenario. Don't design outside the AC.
- Non-negotiables always apply. If one seems impossible, it is a blocking question — not a judgment call.
- Use existing components before proposing new ones. Flag new components explicitly.
- Write copy during implementation — not as a cleanup pass afterward.
- `design-spec.md` is a live document — update it throughout implementation.
- Do not open the PR as ready for review until every validation checklist item is addressed or deferred with a reason.
