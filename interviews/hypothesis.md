# Hypothesis

## Statement

> Can an engineer implement a UI issue (written by a PM, with reference screenshots) without designer input?

## Context

Issue [#35 in teacher-workspace-pg-frontend](https://github.com/String-dxd/teacher-workspace-pg-frontend/issues/35) is the reference case. It was written by a PM who provided screenshots of the existing implementation (the PG staff portal). There was no designer involved: no Figma file, no design token specs, no component breakdown.

The engineer's gap: given reference screenshots and written acceptance criteria, how do you know which design system components to use, what the layout and spacing rules are, and whether your implementation matches the reference?

## What "without designer input" means

An engineer working from this hypothesis has:
- A written issue (user story, background, acceptance criteria)
- Reference screenshots or a live reference implementation
- Access to the project's design system and component library

An engineer working from this hypothesis does NOT have:
- A Figma file with annotated specs
- Design token selections from a designer
- A component breakdown or redline document
- A designer available to answer questions

## Success criteria

The hypothesis is answered when we can document:

1. Every step in a designer's process when handling an issue like #35 (from receiving the PM's brief to handing off to engineering)
2. Which of those steps can be performed by an engineer alone using AI tooling
3. Which steps cannot, and why
4. A prioritised list of skills or harnesses that close the identified gaps

## Status

- [ ] Designer interviews completed
- [ ] Steps catalogued and mapped to engineer capability
- [ ] Skills list produced and filed as individual issues
