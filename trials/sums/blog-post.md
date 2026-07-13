# Building SuMS: what I learned writing code as a PM in government

**Author:** Guang Shin
**Role:** Product Manager (GovTech, forward-deployed to MOE) — Prototyper PM on the SuMS trial
**Intended for:** https://transform.gov.sg/

---

I'm a product manager at GovTech, forward-deployed to MOE. I also write code. Over about four weeks, a small group of us rebuilt SuMS, a survey management system that now runs at sums.digital.moe.gov.sg and replaced a legacy, vendor-built system.

The numbers only make sense with the story behind them, so let me start there.

## What SuMS is, and what we actually did

SuMS is how MOE's School Operations and Policy Branch handles survey and focus-group requests going into schools. It keeps the volume manageable so schools are not buried under research requests, and it issues an approval number for each one.

The old system was vendor-built, end-of-life, and locked to a single supplier with no open tender possible. It cost around $300K a year just to keep running, before anyone talked about paying to build a replacement. We looked at stitching together existing whole-of-government platforms first. They got us part of the way but left gaps in the quota logic and reporting, so a small custom build turned out to be the better fit. The user base was tiny, about five coordinators, and the workflow was clear. Good conditions for building fast.

So here is what "four weeks" actually means. I wrote the product with AI coding agents: PRD to GitHub issues to Claude Code to a working Next.js and Postgres app I could test the same day. Then software engineers came in and hardened it for production. Security scans, credential and dependency fixes, rebuilding the auth and database layer to match our production stack, catching a misconfigured database encryption setup before any data was written to it, and enforcing the deployment guardrails the agent did not follow on its own. The PM built the thing. The engineers made it safe to run. Both parts were the work.

Here is what that taught me, minus the hype.

## The economics only look like magic from outside

The headline is easy to repeat and easy to misread. Four weeks and one person writing the app does not mean the software was the hard part solved cheaply. Writing the app was the fast part. Agents are good at that.

The slow part was everything else. Getting the thing onto a government cloud. Passing security review. The hardening the engineers had to do before it could face real users. Getting colleagues to trust a tool that had appeared in a month.

So the lesson is narrow and specific: agentic coding compresses the build. It does not compress delivery. In government the build was never the bottleneck, so the gains show up somewhere other than the demo.

## The constraint moves, it does not disappear

When you can produce a working feature in an afternoon, the question stops being "can we build this." It becomes "should this exist, who owns it, and who keeps it running after I move teams."

The agent does not know IM8. It does not know our data classification rules, or which survey fields are sensitive, or what a school actually does at the end of a term. I have to know that. That judgment is the job now. The syntax is not.

This is the part I'd tell any PM picking up agentic tooling. You are not being freed from the hard thinking. You are being moved closer to it, faster, with fewer people between you and the consequences.

## Being close to the code widens the job, it does not shrink the team

The normal loop is: a PM writes a spec, hands it to engineers, waits, gets back something slightly off, and iterates through a document. When you build it yourself, that loop is gone. I hit the real edge cases while building them instead of guessing at them in a ticket.

But building the app and shipping it to production are different jobs. I could get to a working system on my own. I could not make it safe for a government cloud on my own, and I should not have tried. The engineers who came in to harden SuMS closed gaps I could not even see. The role gets wider when you can code: you own more of the product's behaviour end to end. It does not mean you are the whole team.

## Bring security in early, not at the end

The tempting failure mode is to build fast and quietly, then present a finished tool to the security people at the very end and hope they wave it through. That is how you turn speed into a fight.

We did the opposite. We brought our MCISO and security folks in while we were still building, so review ran as a conversation alongside the work rather than a gate at the end. It meant issues surfaced early, when they were cheap to fix, and it meant the people accountable for risk were not being handed a surprise. Speed in a government context is only acceptable when the people who carry the risk have been in the room the whole time.

## The maintenance question is real, and I don't have a clean answer

Who owns code that a PM wrote with an agent, after that PM changes roles? The vendor model has an answer. It is slow and expensive, but it exists: a contract and a support line. The agentic model does not have a settled answer yet, at least not in my part of the organisation.

I would rather name that than pretend it is solved. Building fast created a real asset and a real question at the same time. SuMS runs today. The org still needs to decide how tools like it are maintained when the person who built them has moved on.

## What I'd take away

Agentic tooling changed what a small team can build inside government, and how fast. It did not change what government requires of a thing before it can go live, or who is accountable once it does. Security, classification, ownership, migration, trust. None of that got automated. It just got exposed sooner.

The interesting work now sits in that gap: between what a PM can produce in a month with agents, and what a public institution can responsibly run for years. SuMS was a good place to start learning where that line is.
