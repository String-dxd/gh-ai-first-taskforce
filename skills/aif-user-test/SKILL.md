---
name: aif-user-test
description: Sets up a user testing session for a design branch. Reads the design-spec or PR body to identify which scenarios need testing, recommends who to interview based on availability, generates a session guide and feedback record for the facilitator, then starts a local tunnel so the participant can access the running app. Triggered by "user test this", "set up user testing", "run a user test session", "user test the design", "I want to test with a user".
---

## Workflow

Copy this checklist and track your progress:

```
User test progress:
- [ ] Step 1: Read the context and identify what to test
- [ ] Step 2: Recommend who to interview
- [ ] Step 3: Prepare the session guide
- [ ] Step 4: Start the tunnel
- [ ] Step 5: Hand off to the facilitator
```

---

## Step 1: Read the context

Accept a PR number, branch name, or pasted content (design-spec or PR body).

- **PR number:** `gh pr view <number> --json body,title,headRefName`
  - Read the "User testing" table from the PR body — these are the scenarios to test and whether they are "Strongly recommended" or "Can defer".
  - If the PR has no user testing table: ask the user to paste the validation checklist from `design-spec.md`.
- **Branch name:** read `design-spec.md` on that branch and extract the validation checklist.
- **Pasted content:** use as-is.

Extract: the scenarios to test, their recommendations, and the feature description (for the context script).

Only test scenarios marked "Strongly recommended" unless the user says otherwise.

## Step 2: Recommend who to interview

Before any setup, output this recommendation:

---

**Who to interview for this session:**

| Option | Interviewee | When to use |
|--------|-------------|-------------|
| Bare minimum | 1 × PM who wrote or reviewed the issue | They know the requirements without being the implementer — closest proxy to user intent |
| Bare minimum (alt) | 1 × designer familiar with the product | If no PM is available; understands the domain |
| Ideal | 2–3 × real end users (the actual persona) | For teacher-facing features: a teacher; for staff-facing: a school staff member. Catches assumptions the team shares but users don't. |
| Avoid | Engineers only | Too close to the implementation to give honest feedback |

The participant doesn't need to be the exact user persona — someone who can genuinely engage with the task without knowing what the "right" answer is will do. A PM or colleague designer is always better than no one.

For sensitive surfaces (e.g. case data, student records): a domain-knowledgeable colleague is the right call over a real user in an informal session.

---

Ask the user to confirm who they have lined up before proceeding to tunnel setup.

## Step 3: Prepare the session guide

Generate a filled-in session guide using the template in [reference/user-testing-guide.md](reference/user-testing-guide.md):

- Fill the **feature context** with 1–2 plain sentences describing what the feature does (not what you built — what it does for the user).
- Fill **Tasks** with one task per scenario from Step 1, framed as what the user would naturally try to do — not "click the button" but "try to [user goal]".
- Leave the observation and follow-up question fields as prompts for the facilitator to fill in during the session.

Also generate a blank feedback record from [reference/feedback-record-template.md](reference/feedback-record-template.md) with the scenario names pre-filled.

Print both documents. The facilitator runs the session using these — the agent is not involved in the session itself.

## Step 4: Start the tunnel

Start the dev server if it is not already running (use the command from CLAUDE.md or the project's standard dev command, e.g. `pnpm dev`).

Start the tunnel — **localtunnel** by default (no account needed):

```sh
npx localtunnel --port <port>
```

If the user has ngrok configured: `ngrok http <port>`.

Print the tunnel URL clearly. Remind the facilitator:
- Keep both the dev server and the tunnel running for the whole session.
- If the tunnel drops, restart with the same command — the URL will change, so share the new one.
- localtunnel URLs are public for anyone with the link. Do not use production data or real user accounts during testing.

## Step 5: Hand off to the facilitator

Print a summary:

> **Ready to test.**
> Tunnel URL: `<url>`
> Session guide and feedback record printed above.
>
> Run the session using the guide. Fill in the feedback record during or immediately after.
> When the session is done, use `aif-apply-feedback` to apply findings to the design branch.

The agent's role ends here. The session is run by the facilitator.
