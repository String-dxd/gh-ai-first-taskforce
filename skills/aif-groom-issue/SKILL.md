---
name: aif-groom-issue
description: Use during a technical grooming session to fill in the implementer sections of an existing GitHub issue that has author sections written but no technical implementation details yet.
---

You are helping a team complete the technical (implementer) sections of an existing GitHub issue during an engineering grooming session. The issue already has author sections (user story, acceptance criteria, out of scope, design assets, dependencies) — your job is to fill in the implementer sections below the divider.

The canonical issue structure is defined in `~/.claude/skills/aif-create-issue/issue-template.md`. Refer to it when reconstructing the full issue body for preview or update.

## Workflow

### Step 1: Identify the issue

If an issue number was provided, attempt to fetch it directly:

```
gh issue view <number> --json number,title,body
```

- **If the command succeeds**: use the returned data and continue.
- **If the command fails with "command not found" or "'gh' is not recognized"**: `gh` is not installed. Ask the user to paste the issue body directly into the chat, and ask for the issue number or URL so Step 5 can target the right issue later.
- **If the command fails for any other reason** (auth error, invalid issue number, network): surface the real error message and stop. Do not fall back to paste mode — the error needs to be resolved.

If no issue number was provided and a prior `gh` command in this session already succeeded, list open issues to help the user choose:

```
gh issue list --state open --json number,title --limit 50
```

If no issue number was provided and `gh` is not available, ask the user to paste the issue body directly.

Display the issue title and current body so the user can confirm this is the right issue before continuing.

### Step 2: Gather implementer sections

Ask for the following. Do not invent answers — ask if the user has not provided them.

1. **Relevant area of the codebase**: directory paths where the implementation will live.
2. **Package/file placement**: where new files go and what they are named. Agents will guess from naming conventions if this is blank.
3. **Patterns to follow**: existing files that use the same pattern. Name a specific file path. Agents replicate the referenced pattern.
4. **Data model**: new or modified structs/types with field names, types, and constraints. Agents invent field names if this is blank.
5. **API contract**: method, path, full request and response shapes. Agents invent shapes if this is blank.
6. **Error contract**: for each error case, the HTTP status and response body. Agents make inconsistent choices if this is blank.
7. **Additional test scenarios**: non-user-observable scenarios worth testing (concurrent writes, boundary values, internal error paths). Use the same Given-When-Then format.
8. **Hard constraints**: things the implementer must NOT do (e.g. "do not add a new Go dependency").

### Step 3: Confirm grooming checklist

Confirm each grooming checklist item can be checked:

- API contract filled or confirmed N/A
- Data model filled or confirmed N/A
- Patterns to follow named

If any item cannot be checked, ask the user to provide the missing information before continuing.

### Step 4: Preview and confirm

Render the complete updated issue body in a markdown code block and ask for confirmation before updating.

### Step 5: Update the issue

**If `gh` was available:**

Run:

```
gh issue edit <number> --body "<updated body>"
```

After updating, print the issue URL.

**If `gh` was not available:**

Render the final issue body in a markdown code block for the user to copy and paste into the issue manually.

## Rules

- Never leave a section blank. Every section must be explicitly filled or marked `N/A`.
- Do not alter the author sections (user story, acceptance criteria, out of scope, design assets, dependencies) — only fill in the implementer sections below the divider.
- Do not use em-dashes (`—`) in the issue title or body. Use colons, parentheses, or separate sentences instead.
- Pick one term per concept and use it consistently across all scenarios.
