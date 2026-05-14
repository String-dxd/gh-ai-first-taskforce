# Reflections from SuMs Trial

**Author:** Natasha  
**Role:** Software Engineer overseeing SuMs trial  
**Date:** 29 Apr 2026

---

## Executive Summary

<!-- [PROMPT: Summarize key takeaways in 3-5 bullets for busy stakeholders] -->

This trial evaluated the feasibility of coding agents in structured software engineering, specifically testing a multi-agent workflow where distinct human operators acted as **planner/generator** (PM) and **evaluator** (SWE). Key findings center on the critical importance of separating generation and evaluation roles, and the persistent need for human-in-the-loop review to satisfy accountability concerns.

---

## Context & Background

I joined the SuMs project at development kickoff, following one month of PM-led discovery. The PM had already built early features using Claude's coding agent. When preparing to deploy to production, gaps in the codebase surfaced during discussions with DevOps, AI-first lead, engineering manager, and another PM.

My role became bridging these gaps and evaluating whether coding agents could reliably support grassroots practitioners in production software engineering.

---

## Trial Methodology

### Multi-Agent Workflow

Three team members each operated their own coding agents via Claude Enterprise:

| Role | Agent Function |
|------|---------------|
| PM | Planner & Generator (features, bug fixes) |
| SWE (myself) | Evaluator (merge-ready review) |
| DevOps Engineer | Infrastructure-as-code deployment |

On a macro level, this functioned as a **multi-agent architecture**: one operator used agents for planning/generation, another for evaluation.

### My Process as an Evaluator

#### Phase 1: Manual Codebase Review
I performed an initial review on the initiated code created by the coding agent manually. Key issues identified:

- **Security:** Hardcoded credentials (Supabase service role key, admin password) committed to git; 12 unpatched npm vulnerabilities (6 high, 6 moderate)
- **Infrastructure:** Tight Supabase coupling requiring full auth/DB refactor; no defined test environment; build required live DB connection; Prisma schema missing from Docker image; KMS misconfiguration requiring DB teardown; agent attempted unauthorized local prod infra changes
- **Environment:** `.gitignore` used `env*` wildcard, silently excluding `.env.example` and causing production deployment failures
- **Code Quality:** Type errors suppressed with `any` casts; constants redeclared across files instead of shared; deprecated files not cleaned up; build-breaking type errors introduced

Full details in [Trial Review](trial-review.md).

#### Phase 2: PR Review Pattern Analysis
For approximately one week, I manually reviewed PRs authored by the PM's coding agent to identify recurring failure patterns:

- **Branching strategy failures**: Feature branches created off other feature branches, missing rebases on main

- **Type safety bypasses**: Using `any` casts with ESLint disable comments instead of proper typing
- **Code duplication**: Constants redeclared across pages instead of extracted to shared libraries
- **Orphaned files**: Deprecated action files not cleaned up when superseded by new implementations
- **Environment configuration gaps**: Missing `.env.example` entries, dev configs pointing at cloud services
- **Build verification skipped**: Changes committed without running `next build` to verify type safety

#### Phase 3: Setup of Automated Code Scanning Hooks
I set up automated code scanning hooks to run on each commit and pull request to identify issues before they reached the review stage.

#### Phase 4: Development of Pre-Merge Audit and Review Skill
With the patterns identified in Phase 1 and 2, I prompted the coding agent to create a pre-merge audit and review skill that would review code and look out for mistakes seen in these patterns.

The pre-merge-audit skill included checks for: hardcoded credentials, npm vulnerabilities, type safety issues, missing environment variables, and Supabase coupling risks. 

#### Phase 5: Self-Improving Review Skill
I added a prompt to the review skill that would ask the agent to improve the review skill based on the new patterns it would identify with each review it performed.

---

## Key Findings by Agent Role

### 1. AI as Planner

Key architectural decisions defaulted to readily available, well-documented patterns without considering organizational constraints:

- **Vercel for hosting**: Defaulted to Vercel for deployment despite organizational preference for private cloud/on-premises infrastructure
- **Supabase for database/auth**: Chose Supabase (managed service) without awareness that production target was plain PostgreSQL on AWS RDS, requiring significant refactoring later
- **Global SSL certificates**: Defaulted to global certificates without querying regional vs organizational preferences

**Assessment**: These defaults are technically sound for general use but problematic when they conflict with organizational security policies, compliance requirements, or infrastructure standards. The agent lacks awareness of organizational context unless explicitly constrained via `CLAUDE.md` or template skills.

### 2. AI as Generator (Coder)

Speed and volume of delivery far exceeded manual coding. However, quality was inconsistent across domains:

**Generated well:**
- UI components and page layouts
- Basic CRUD operations and API endpoints
- Feature scaffolding and boilerplate reduction

**Generated poorly:**
- **Security-sensitive code**: Hardcoded credentials, exposed secrets, missing input validation
- **Infrastructure code**: KMS misconfigurations, unauthorized local applies, missing Docker packaging requirements
- **Cross-boundary concerns**: Build-time optimizations that failed in isolated CI environments (pre-caching requiring DB connections)
- **Compliance-sensitive areas**: Using external services (Vercel, Supabase) without verifying organizational approval

**Quality trade-off**: The agent prioritizes "working code" over "production-ready code." It lacks awareness of organizational security boundaries, compliance constraints, and deployment environment differences unless explicitly instructed. Speed comes at the cost of requiring substantial human review for security, infrastructure, and compliance correctness.

### 3. AI as Reviewer (Evaluator)

When the same agent that generated code evaluated it, critical gaps were missed. The `pre-merge-audit` skill run by the generator consistently passed code that the separate `review-pr` skill flagged as problematic.

**Specific observation**: Even when explicitly instructed not to expose secrets in `CLAUDE.md`, the generator agent failed to catch its own hardcoded credentials during self-review. Only the separate evaluator context (human operator + distinct agent session) surfaced these issues.

**Root cause**: Agents exhibit leniency when evaluating their own work, confidently praising quality that a human observer would flag as mediocre. This aligns with Anthropic's finding that separating the agent doing the work from the agent judging it is essential for reliable evaluation.

**Practical implication**: Agent-only evaluation is insufficient for production code. A separate evaluator—whether human or distinct agent context—is required to catch what the generator misses.

---

## Critical Insights

### Insight 1: Generator/Evaluator Separation is Essential

The project used two skills:
- `pre-merge-audit` (run by generator)
- `review-pr` (run by separate human operator = separate agent context)

**Finding:** Running `review-pr` as a distinct agent consistently surfaced gaps that `pre-merge-audit` failed to catch.

This aligns with Anthropic's research:

> *"Most notably, it's still unclear whether a single, general-purpose coding agent performs best across contexts, or if better performance can be achieved through a multi-agent architecture."* — [Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)

> *"A second issue... is self-evaluation. When asked to evaluate work they've produced, agents tend to respond by confidently praising the work—even when, to a human observer, the quality is obviously mediocre... Separating the agent doing the work from the agent judging it proves to be a strong lever to address this issue."* — [Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps)

**Practical implication:** Tuning a standalone evaluator to be skeptical is more tractable than making a generator critical of its own work.

### Insight 2: Liability Concerns Override Technical Assurance

Management exhibited skepticism about code quality until explicitly informed that **human software engineers were conducting full manual reviews**. This goes to show that even with robust automated testing and review processes, the perception of human oversight is still crucial for stakeholder confidence. As a software engineer responsible for the codebase as well, I do feel more confident about the code quality when I have personally reviewed it myself, rather than relying solely on automated or agentic reviews. I found the best sweet spot for me to be to perform a quick review of a pull request, and then where I identify there might be an issue, I use a coding agent to confirm my suspicions. 

In the early stages of introducing agentic workflows to our organization, it is hence crucial to still include human oversight and to clearly communicate the role of human oversight and accountability in the process to maintain stakeholder confidence. Otherwise, this may result in a premature loss in trust and confidence in the agentic workflows, preventing further experimentation and adoption.

**Key dynamic:** Even when presented with available agentic skills and testing pipelines, stakeholders required human accountability for assurance.

**Takeaway:** Responsibility and liability remain the core concern for leadership, not just technical correctness.

### Insight 3: The Need for Tailored, Self-Improving Review Skill
As a codebase evolves, so does the nature of potential issues and edge cases. What may have been a rare occurrence in the early stages of development could become a common pattern as the codebase grows and changes. This necessitates a review skill that is not only tailored to the specific codebase but also capable of self-improvement over time. 

While the current review skill is a good starting point, it is not sufficient to address all potential issues. It could serve as a start point for codebases but it should expand in scope and depth over time, thorugh both a combination of human review and agent-led reviews. 

That said, different tech stacks and frameworks may require different review skills. For example, a review skill tailored for a React application may not be suitable for a Node.js application. Therefore, it is recommended to have a review skill that is tailored to the specific codebase and can be adapted to different tech stacks and frameworks. 

### Insight 4: Automation over Agentic Workflows
Even when instructed not to do so in `CLAUDE.md` or in prompts, coding agents still pose a probability of exposing sensitive information like API keys and credentials. Be it due to context overflow or other factors, the agent, by virtue of being non-deterministic, has no ability to guarantee that such information will not be exposed.

Therefore, automation over agentic workflows is necessary to ensure that sensitive information is not exposed. The implemention of automated secrets scanning and validation processes prior to code leaving the local development environment is even more crucial than ever when it comes to coding with agents. 

Our current automation approach involves the use of `gitleaks` to scan for secrets in the code changes prior to committing changes. We also have other pre-commit hooks that run linting and formatting checks to ensure code quality. This, coupled with the pre-merge-audit skill, provides a decently robust layer of security and quality assurance. On stakeholder assurance, we can confidently say that there is a 100% guarantee that secrets covered by `gitleaks` will not be exposed.

However, it is improtant to note that `gitleaks` does not cover other types of sensitive data, such as personal identifiable information (PII) or other organizational data that may be inadvertently included in the code. This necessitates the creation of an internal automation tool to scan for such data, which is currently being developed sporadically. The Github repo for the tool can be found here: [Personal data detection tool](https://github.com/String-sg/personal-data-detection-tools).

This is just the specific example for secrets scanning, but the same principle of automation over agentic workflows applies to other areas as well. For instance, while we do have an IM8 compliance skill developed, we should ensure that whatever can be automated for IM8 compliance should be created as an automation first, and only the remaining parts that cannot be automated should be handled by the coding agent and reviewed by a human.

### Insight 5: The Need for Opiniated Deployment Strategy
The coding agent defaults to deploying and testing code in Vercel, which raised many questions pertaining to security and compliance. After discussion with the Cybersecurity and Information Officer, he confirmed that as long as there were no sensitive data being processed, the use of Vercel was acceptable. 

While we could confirm that there was no sensitive data within the development codebase and no test database that contained production data as of the point of discussing with the CISO, there was no guarantee that with every new code added by the coding agent, the same level of data sensitivity would be maintained. 

For example, there was a risk that the coding agent might introduce sensitive data into the seed data script, such as if the grassroots practitioner prompted the agent to create synthetic data similar to a given sample of actual production data. 

Even outside of Vercel, there were other concerns regarding the use of external services and platforms. For instance, the coding agent defaulted to using Supabase for database and authentication services, which raised concerns about data sovereignty and compliance with organizational policies. 

There was also an instance where the coding agent used actual production credentials in creating an `env.example` file, thinking that it was providing an example of the variables that should be used in the `.env` file. This was fortunately caught during a manual review process, but since the manual review process was rescinded by the tech lead to truly embody the AI-first approach, relying on the coding agent's own review capabilities, there was no guarantee that such issues would be caught in the future. While this was an `env` file that would not be seen on the client-side, the same thing could happen with other files that are exposed to the client-side, such as API keys or other sensitive information.

However, this default behavior deviates from the organization's established development and deployment practices, which typically involve on-premises or private cloud environments. This deviation in practice needs to be addressed to ensure alignment with organizational security policies and compliance requirements.

My recommendation would be to create a custom deployment skill that is tailored to the organization's specific needs and requirements on codebase initiation. This would involve creating a skill that is aware of the organization's development and deployment practices, and that can be configured to use the appropriate services and platforms. This would ensure that the coding agent is aligned with the organization's security policies and compliance requirements, and that the default behavior is consistent with the organization's established practices. These template skills are drafted in the `templates` directory.


### Insight 6: Agentic Evaluators Cannot Substitute for Functional Testing

While a generator agent can produce code against its own plan and write a PR with manual testing criteria for a human or agentic evaluator, there is currently no workflow for either agent to take those criteria and verify them through actual test execution.

**The gap in practice:** When prompted to check code changes against a set of stated manual testing criteria (e.g. login as a specific role, submit a form, confirm values persist), the evaluator agent performed a code-level static analysis rather than running any tests. It returned a full `PASS` on all five criteria based solely on reading the implementation.

Manual testing subsequently revealed that Criterion 2 (editing prefilled division values before submit) did not work as expected. Investigation showed the root cause: `ADMIN_DIVISION=DxD` was set for the admin role, but division codes are case-sensitive, causing a mismatch. This class of bug — one arising from a misconfigured environment value, not a code logic error — is invisible to a static code review.

**No tests existed for any criterion.** When the evaluator was explicitly asked whether tests had been written for the stated criteria, it confirmed that none existed across all five criteria. The generator had neither written tests corresponding to the PR's manual testing steps, nor flagged their absence.

**E2E tests are additionally limited by authentication constraints.** Even where automated testing is feasible in principle, applications that require manual token entry — such as those using OTPass for government SSO — present a hard blocker for agentic E2E testing. Without a sandbox environment that provides whitelisted credentials with generic, stable pins, an agent cannot complete the login flow programmatically. This is not a gap in agent capability but a structural constraint: the authentication mechanism is specifically designed to resist automation. Until a sandbox with test-account bypass exists, any test criteria that involves logging in as a real role cannot be executed by an agent, and must remain a human testing responsibility.

**Assessment:**

- The generator agent should have context to write automated tests that correspond to the manual testing steps stated in the PR description.
- The evaluator agent should, when reviewing a PR with stated testing criteria, do two things: (1) check whether tests have been written for each criterion, and (2) if not, implement the automated tests rather than simply evaluating the code changes.
- E2E test coverage by agents is structurally blocked for any flow that passes through authentication requiring manual token entry (e.g. OTPass) without a dedicated sandbox. This boundary should be explicitly documented in the project's testing strategy so that human testers know which criteria fall outside agent scope.
- There appears to be a need for a dedicated QA agent role — for example, to catch edge cases such as creating an admin with an invalid division code. Whether this is best handled by a separate QA agent/skill, or by extending the generator or evaluator agent's existing skills, requires further testing to determine.

### Insight 7: Auth Flow Bugs Require Human Testing — and the Process Must Enforce It

Auth-specific bugs represent a category where static code analysis is structurally insufficient, and where human complacency in the review process poses a compounding risk.

**The pattern observed:** A bug was identified where clicking the "Send OTP" button triggered multiple OTP sends. The agent was able to propose a fix based on static code analysis — identifying the likely cause and producing a code change. Because the agent cannot complete the OTP login flow programmatically (see Insight 6), it could not verify its own fix through functional testing. The PR was raised with a clear, step-by-step human test plan attached.

However, human manual testing following the agent's test plan revealed that the fix did not resolve the issue. The agent's static analysis had correctly identified a probable cause but missed a second contributing factor that only became visible through runtime execution of the auth flow.

**What the agent got right:** Despite failing to resolve the bug completely, the agent produced a clear and actionable test plan that guided the human tester effectively. This is a meaningful contribution — structuring what to test and in what order is non-trivial, and the agent's ability to produce this plan reduced the cognitive load on the human reviewer.

**The process gap:** The review skill currently lacks the ability to distinguish between test criteria that can be automated and criteria that structurally require human execution. Without that distinction, the human reviewer has no explicit signal about which items they are responsible for verifying. In practice, this creates a risk of complacency: if the review skill returns a `PASS` or highlights issues without a hard gate, a human reviewer may proceed to merge assuming the agent's assessment was sufficient.

**Recommended process changes:**

1. **Refine the pre-merge audit skill** to explicitly classify each test criterion as `[AUTOMATED]`, `[AGENT E2E]`, or `[HUMAN REQUIRED]`. For auth flows involving OTP or government SSO (OTPass), any criterion that passes through the login flow must be marked `[HUMAN REQUIRED]` with a note that agent E2E is structurally blocked.

2. **Update the review PR skill** to surface a distinct "Human Testing Required" section in its output, listing only the criteria marked `[HUMAN REQUIRED]`. This section should not be buried in a broader assessment — it should be a top-level callout so the human reviewer cannot overlook it.

3. **Introduce a merge blocker for uncompleted human testing.** To prevent human complacency from defaulting to the review skill's output without performing the required manual steps, there should be an explicit gate — such as a required PR checklist item or a label that must be manually applied — confirming that human testing was completed before the branch can be merged. The review skill's output alone should not be sufficient to satisfy this gate.

**Takeaway:** The agent's role in auth-flow bug fixes is as a diagnostic and planning tool, not a verification tool. The process must be designed to reflect this distinction, with explicit enforcement so that the agent's acknowledged limitations translate into required human action rather than an optional step.

---

## Recommendations

### For Leadership
- **Communicate human oversight explicitly**: Stakeholder confidence depends on knowing human engineers review agent-generated code. Document and communicate the human-in-the-loop process clearly to prevent premature loss of trust.
- **Invest in deterministic automation first**: Where possible (secrets scanning, IM8 compliance, type checking), implement deterministic automation before relying on agentic workflows. Automation provides guarantees that agents cannot.

### For Practitioners (Software Engineers)
- **Adopt the "quick review + agent confirmation" pattern**: Perform a quick manual scan of PRs first, then use coding agents to confirm suspicions rather than relying solely on agentic or automated review.
- **Maintain separate generator/evaluator contexts**: Never rely on the same agent session to both generate and evaluate code. Use distinct skills or separate human operators for evaluation.
- **Build self-improving review skills**: Start with a baseline review skill and iteratively expand it as new patterns emerge. Document patterns discovered during manual review to feed back into the skill.

### For Platform Teams
- **Create opinionated template skills**: Develop deployment and initialization skills tailored to organizational standards (e.g., AWS RDS over Supabase, regional over global certificates). Template skills in the `templates` directory should be the default for new projects.
- **Implement pre-commit automation**: Deploy `gitleaks`, linting, and PII detection as mandatory pre-commit hooks. Agents cannot guarantee they won't expose secrets; automation can.
- **Provide compliant test environments**: Grassroots practitioners need org-approved test environments to avoid using dev environments for user testing, which creates compliance exposures.

### For Main Product Team Integration
- **Require `CLAUDE.md` constraints for all agentic work**: Document organizational constraints (no Vercel, no Supabase, no local prod applies) in project-level `CLAUDE.md` files.
- **Gate CI/CD on deterministic checks**: Run `npm audit`, `tsc --noEmit`, and secret scanning in CI before any agent-generated code can merge.
- **Establish review skill maintenance as shared responsibility**: Treat review skills as living documents that the team collectively maintains, not one-time setup items.

---

## Appendix: Supporting Evidence

- [Anthropic: Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [Anthropic: Harness Design for Long-Running Apps](https://www.anthropic.com/engineering/harness-design-long-running-apps)


