---
name: aif-estimate-issue
description: Use after grooming to estimate a GitHub issue's story points. Run against an issue number to get a calibrated SP estimate benchmarked against the repo's historical estimates, a complexity breakdown, and a blindspots checklist the team should discuss before committing.
---

You are helping a team estimate the story points for a GitHub issue during a sprint grooming session. Your job is to produce a calibrated estimate anchored to the repo's own history, a structured complexity breakdown, and a blindspots checklist that surfaces considerations the team might miss.

## Workflow

### Step 1: Fetch the target issue

If an issue number was provided, attempt to fetch it directly:

```
gh issue view $ARGUMENTS --json number,title,body,labels,assignees
```

- **If the command succeeds**: use the returned data and continue.
- **If the command fails with "command not found" or "'gh' is not recognized"**: `gh` is not installed. Ask the user to paste the issue body directly into the chat, and ask for the issue number so Step 7 can target the right issue later.
- **If the command fails for any other reason** (auth error, invalid issue number, network): surface the real error message and stop. Do not fall back to paste mode.

If no issue number was provided and a prior `gh` command in this session already succeeded, list open issues to help the user choose:

```
gh issue list --state open --json number,title --limit 50
```

Display the issue title and current body so the user can confirm this is the right issue before continuing.

### Step 2: Detect the SP label convention and fetch calibration data

Scan the repo's labels for any that match a `<prefix>:<number>` pattern where the number is a common story point value (1, 2, 3, 5, 8, 13, 21):

```
gh label list --json name --limit 200
```

Look for labels like `sp:3`, `points:5`, `story-points:8`, etc. Extract the prefix (e.g. `sp`). If multiple prefixes match, pick the one with the most labels.

If a SP label convention is found, fetch all issues (open and closed) that carry any SP label:

```
gh issue list --state all --label "<prefix>:<N>" --json number,title,body,labels --limit 50
```

Run this for each SP value found. These are the **calibration anchors** -- historically pointed issues the team has already estimated.

If no SP labels are found in the repo, note this and skip calibration. The skill will still produce a complexity breakdown and blindspots checklist, but will flag that confidence is low due to missing historical data.

### Step 3: Read the codebase

Identify the areas of the codebase relevant to the target issue based on its description, acceptance criteria, and any file paths or components mentioned. Read key files to assess:

- How large the affected surface area is
- What patterns are already established
- Whether there are existing tests covering the area
- What dependencies or integrations are involved
- Whether data models or migrations would be needed

Do not read the entire codebase. Focus on the areas directly relevant to the issue's scope.

### Step 4: Analyze complexity

Evaluate the target issue across these dimensions. For each, assign a rating (Low / Medium / High) and a one-sentence justification:

1. **Scope**: How much code needs to change? How many files, components, or layers are affected?
2. **Unknowns**: How well-specified is the issue? Are there open questions or ambiguous requirements?
3. **Dependencies**: Does this require coordination with other teams, services, or external APIs?
4. **Testing surface**: How much test coverage is needed? Are there edge cases, integration tests, or E2E scenarios?
5. **Data/migration risk**: Are there schema changes, data migrations, or backwards compatibility concerns?
6. **Cross-cutting concerns**: Does this touch auth, logging, monitoring, error handling, or other shared infrastructure?

### Step 5: Compare against calibration anchors

If historical SP data was found in Step 2, compare the target issue against each historically pointed issue:

- Match by similarity of scope, complexity dimensions, and domain area
- Identify the 2-3 closest comparable issues
- Note where the target issue is larger or smaller than each comparable

Use the comparables to anchor the suggested SP value. The estimate should be consistent with how the team has pointed similar work in the past.

If no calibration data exists, base the estimate on the complexity analysis alone and clearly state that the estimate is uncalibrated.

### Step 6: Generate blindspots checklist

Review the target issue for things NOT mentioned that the team should discuss before committing to the estimate. Check for:

- **Missing error/edge cases**: What happens when inputs are invalid, services are down, or data is malformed?
- **Untested integration surfaces**: Are there API contracts, webhook handlers, or third-party integrations that need testing?
- **Performance implications**: Will this affect load times, query performance, or memory usage?
- **Security considerations**: Does this touch authentication, authorization, user input handling, or sensitive data?
- **Data migration or backwards compatibility**: Will existing data need to be transformed? Can old clients still work?
- **Observability/monitoring gaps**: Are there new failure modes that need alerts, logs, or dashboards?
- **Documentation or user communication needs**: Do docs, changelogs, or user-facing messages need updating?
- **Dependencies on other teams or external services**: Is anything blocked or dependent on work outside the team's control?
- **Accessibility**: Are there UI changes that need accessibility review?
- **Rollback strategy**: If this goes wrong in production, how do you undo it?

Only include items that are genuinely missing from the issue. Do not pad the list with items already covered in the acceptance criteria.

### Step 7: Present the estimate

Present the full analysis in this format:

```markdown
## Story Point Estimate: #<number> - <title>

### Suggested Estimate: <N> story points
**Confidence:** <High/Medium/Low>

<2-3 sentence rationale explaining the estimate>

#### Comparable Issues
| Issue | SP | Similarity |
|---|---|---|
| #<number> - <title> | <N> | <why it's comparable> |
| #<number> - <title> | <N> | <why it's comparable> |

> If no calibration data: "No historically pointed issues found in this repo. Estimate is based on complexity analysis only. Confidence is low -- consider pointing a few past issues to build calibration data."

### Complexity Breakdown
| Dimension | Rating | Notes |
|---|---|---|
| Scope | <Low/Med/High> | <one sentence> |
| Unknowns | <Low/Med/High> | <one sentence> |
| Dependencies | <Low/Med/High> | <one sentence> |
| Testing surface | <Low/Med/High> | <one sentence> |
| Data/migration risk | <Low/Med/High> | <one sentence> |
| Cross-cutting concerns | <Low/Med/High> | <one sentence> |

### Blindspots Checklist
Items not addressed in the issue that the team should discuss:

- [ ] <blindspot item 1>
- [ ] <blindspot item 2>
- ...

---

*Estimated with aif-estimate-issue*
```

Ask the user:
1. Whether the estimate looks right, or if they want to adjust the SP value
2. Whether to post this as a comment on the issue

### Step 8: Post comment and apply label

Once the user confirms (or adjusts) the SP value:

Ensure the usage-tracking label exists:

```sh
gh label create "skill:aif-estimate-issue" --color ededed --description "Estimated with the aif-estimate-issue skill" 2>/dev/null || true
```

Ensure the AI SP label exists (using the confirmed SP value):

```sh
gh label create "ai-sp:<N>" --color 7057ff --description "AI-recommended story points: <N>" 2>/dev/null || true
```

Remove any existing `ai-sp:*` labels from the issue first (in case of re-estimation), then apply the new one:

```sh
# Remove existing ai-sp labels
gh issue view $ARGUMENTS --json labels --jq '.labels[].name' | grep '^ai-sp:' | while read label; do
  gh issue edit $ARGUMENTS --remove-label "$label"
done

# Apply new labels
gh issue edit $ARGUMENTS --add-label "ai-sp:<N>" --add-label "skill:aif-estimate-issue"
```

**If `gh` was available**, write the analysis to a temp file and post as a comment:

```sh
gh issue comment $ARGUMENTS --body-file /tmp/estimate-body.md
```

After posting, print the issue URL.

**If `gh` was not available**, render the analysis in a markdown code block for the user to copy and paste.

## Rules

- Never invent historical comparables. Only cite issues that actually exist in the repo with real SP labels.
- If calibration data is sparse (fewer than 3 comparable issues), explicitly state this and lower confidence.
- Do not pad the blindspots checklist. Only include genuinely missing considerations.
- Do not alter the issue body. The skill only adds a comment and a label.
- The `ai-sp:<N>` label is a recommendation. Make it clear the team decides the final estimate.
- Use Fibonacci-like values for story points: 1, 2, 3, 5, 8, 13, 21. Do not suggest non-standard values.
- Do not use em-dashes in the comment body. Use colons, parentheses, or separate sentences instead.
