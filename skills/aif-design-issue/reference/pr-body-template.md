Designs #<issue number>

## Summary

<!-- What was designed and the key decisions made -->

## Acceptance criteria

| Scenario | Test file | Passed |
|----------|-----------|--------|
| <Scenario name> | `<path/to/test.spec.ts>` | ✅ / ❌ |

## User testing

| Scenario | Recommendation | Reason |
|----------|---------------|--------|
| <Scenario name> | Strongly recommended / Can defer | <reason> |

<!-- Run `aif-user-test` to set up sessions for scenarios marked "Strongly recommended". -->

## Designer review checklist

Work through these steps in order before approving:

1. **Read the design spec** — open `design-spec.md` on this branch. Read the intent, per-scenario decisions, and decisions log before looking at any code or screenshots.

2. **Open the app** — check out this branch and run the dev server, or open the tunnel URL if one is provided in the comments.

3. **Walk each scenario** — use the acceptance criteria table above as your guide. For each scenario, does the implementation match the intent in design-spec.md?
   - [ ] `<Scenario name>`
   <!-- aif-design-issue repeats this checkbox for each AC scenario -->

4. **Non-negotiables** — on every scenario:
   - [ ] Text contrast meets AA (4.5:1 body, 3:1 large text and UI components)
   - [ ] Every interactive element reachable by keyboard with a visible focus state
   - [ ] Every form field has a visible label (not placeholder-only)
   - [ ] Destructive actions show consequences and offer undo or confirmation

5. **Layout** — on every scenario:
   - [ ] One clear focal region — the primary task and its single primary action
   - [ ] Reading order matches the task's priority order
   - [ ] Density fits the task
   - [ ] Shared edges align

6. **Copy** — on every scenario:
   - [ ] Error messages state what happened, what it means, and what to do next
   - [ ] Active voice, second person, sentences under 25 words
   - [ ] No AI writing tells or filler openers
   - [ ] Actions named by the action, not the input device ("select", not "click")

7. **Anti-slop** — on every scenario:
   - [ ] No purple or violet gradients
   - [ ] No nested cards
   - [ ] No grids of identical cards as the default layout
   - [ ] No bounce or elastic easing
   - [ ] Cards used only for interactive units

8. **Flow** *(skip if this is not a multi-step interaction)*:
   - [ ] A non-destructive exit exists at every step
   - [ ] In-progress work is preserved or explicitly discarded on interruption — never silently lost
   - [ ] Every async action has a loading, success, and error state
   - [ ] Focus lands somewhere sensible after every step change

9. **Screenshots** — compare the before/after table below against your expectation from the design spec.

10. **User testing** — if any scenario is marked "Strongly recommended" above, run `aif-user-test` before approving.

## Screenshots

<!-- Modification: use the before/after table below — one row per scenario.
     New page or flow: replace the table with inline screenshots under each scenario heading. -->

| Scenario | Before | After |
|----------|--------|-------|
| <Scenario name> | <!-- screenshot --> | <!-- screenshot --> |

---

*🤖 Generated with aif-design-issue*
