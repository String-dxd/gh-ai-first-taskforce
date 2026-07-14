# Interviews

This directory records stakeholder interviews conducted to answer hypotheses about AI-first engineering workflows.

Each hypothesis asks whether a step in a traditional software development process can be performed by an engineer alone (with AI tooling), without the specialist who currently owns that step. Interview findings inform the design of skills and harnesses in this repo.

## Structure

```
interviews/
  README.md                     -- this file
  hypothesis.md                 -- the hypothesis under investigation
  stakeholder-map.md            -- who to interview and why
  templates/
    transcript.md               -- template for recording an interview
  designers/
    questions.md                -- draft questions for designer interviews
    YYYY-MM-DD-<name>.md        -- completed interview transcripts
```

## Current hypothesis

> Can an engineer implement a UI issue (written by a PM, with reference screenshots) without designer input?

See `hypothesis.md` for the full statement and success criteria.

## How to add an interview

1. Copy `templates/transcript.md` into the relevant role directory (e.g. `designers/`).
2. Name the file `YYYY-MM-DD-<interviewee-name>.md`.
3. Fill in the transcript during or immediately after the interview.
4. Update `stakeholder-map.md` to mark the interview as completed.
