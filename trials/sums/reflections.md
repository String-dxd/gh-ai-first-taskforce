# Reflections from Trial
By: Natasha 
Role: Software Engineer overseeing SuMs trial
Date: 29 Apr 2026

# Context
I was unexpectedly roped into the SuMs project right as development started, when one month of discovery had been done by the product manager and there were early features built into the project that were created by the PM using Claude's coding agent. 

In discussing with the DevOps Engineer, AI-first lead, engineering manager and another PM on how to push the codebase to our production environment, we uncovered many gaps in the codebase as it was.

That was when I was roped in to help bridge these gaps and evaluate the feasibility of coding agents in structured software engineering and for enabling grassroots practitioners.

# On AI As a Planner
Key architectural decisions tended to default to readily known patterns. 

## Workflow and Roles
Throughout the course of the project, the PM, myself and the DevOps Engineer each used our own coding agents through our Claude Enterprise plan. Our roles and how we used our coding agent were distinct:

- PM: Plan and create Features and Fix Bugs
- Myself (SWE): Review code for merge-readiness
- DevOps Engineer: Deploy through infrastructure-as-code

On a macro-level, we can be seen to be working in a multi-agent structure, where one of us used a coding agent as a **planner** and **generator** and the other as an **evaluator**. 

# Steps

## Starting With Manual Review of Codebase
On first look of the codebase, I performed a manual review of the code without the help of any coding agent. A quick manual review revealed many basic issues.

## Manual Review of PRs
I went on to perform manual reviews on the PRs for about a week that the coding agent on the PM's side was writing up, to build up an intuition on what were common mistakes performed by the coding agents. 

One key issue was the branching strategy of undertaken by the coding agent. It was messy, with feature branches branched off of another feature branch. Rebasing on main was not done where necessary.

## Stakeholders

I noticed also in meetings with higher management that many had skepticism over the quality of the codebase if not told that a full manual review of each PR was done. It was only after I mentioned that I was manually reviewing each PR that their concerns were quelled.

Takeaway: While management is mostly pushing for AI-driven code, responsibility and liability seems to be the key concern here. Even when told that there are available agentic skills and testing pipelines to check for code quality, they are most assured when code is manually reviewed by a software engineer. 

## Direct Quote from Anthropic

https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents

Most notably, it’s still unclear whether a single, general-purpose coding agent performs best across contexts, or if better performance can be achieved through a multi-agent architecture. 

https://www.anthropic.com/engineering/harness-design-long-running-apps

A second issue, which we haven’t previously addressed, is self-evaluation. When asked to evaluate work they've produced, agents tend to respond by confidently praising the work—even when, to a human observer, the quality is obviously mediocre. This problem is particularly pronounced for subjective tasks like design, where there is no binary check equivalent to a verifiable software test. Whether a layout feels polished or generic is a judgment call, and agents reliably skew positive when grading their own work.

Separating the agent doing the work from the agent judging it proves to be a strong lever to address this issue. The separation doesn't immediately eliminate that leniency on its own; the evaluator is still an LLM that is inclined to be generous towards LLM-generated outputs. But tuning a standalone evaluator to be skeptical turns out to be far more tractable than making a generator critical of its own work, and once that external feedback exists, the generator has something concrete to iterate against.

## Separating Generator and Evaluator Agent
There is a `pre-merge-audit` skill and a `review-pr` skill. The assumption at first would be that when the PM uses Claude to generate code, it would run the `pre-merge-audit` before merging, thus resulting in merge-ready code.

The review-pr skill is run by myself, the software engineer, and hence is effectively a separate agent. Doing this almost always revealed gaps that the `pre-merge-audit` skill failed to catch.

## Self-Improving Review Skill

# On AI As a Coder (Generator)
There is no question on the speed of delivery of coding agents versus manual coders. By sheer speed and volume, the coding agent has 

# On AI As a Reviewer (Evaluator)

# Personal Recommendations


