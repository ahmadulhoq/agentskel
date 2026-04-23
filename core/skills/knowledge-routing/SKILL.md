---
name: knowledge-routing
description: When deciding where to store a piece of knowledge (memory files vs
  Confluence vs Jira). Use when about to document something, capture a lesson,
  create a ticket, or publish a decision.
---

# Knowledge Routing

**Purpose:** Three layers exist — pick the right one.

## The three layers

| Layer | Where it lives | Who owns it |
|---|---|---|
| **Agent operational state** | `.memory/` in repo | Agent, shared via git |
| **Team-canonical knowledge** | Confluence | Humans (tech leads, product) |
| **Tracked work** | Jira | Team |

## Decision table

| Knowledge type | Destination | Why |
|---|---|---|
| Codebase structure (modules, classes, functions) | `.memory/MAP.md`, `.memory/SYMBOLS.md` | Agent reads every session |
| Session state, what's next | `.memory/RESUME.md` | Local-only, session handoff |
| Coding conventions (naming, style, patterns) | `.memory/CONVENTIONS.md` | Read by every session |
| Agent lessons learned (mistakes to avoid) | `.memory/LESSONS.md` | Small, agent-facing |
| Sacred behaviors (code that looks wrong but shouldn't change) | `.memory/SACRED.md` | Small, agent-facing |
| Team roster and roles | `.memory/TEAM.md` | Read during handoffs |
| Jira workflow conventions | `.memory/JIRA_WORKFLOW.md` | Read before Jira writes |
| Tech debt findings | `.memory/TECH_DEBT.md` + optional Jira ticket | Local record + tracked when actionable |
| Architectural decisions (ADRs) | **Confluence** (ADRs parent) + link in LESSONS.md | Team-canonical, durable |
| Post-mortems | **Confluence** (Postmortems parent) | Team-visible, searchable |
| Runbooks | **Confluence** (Runbooks parent) | Referenced during incidents |
| Feature specifications | **Confluence** (Specs parent) | Human-authored and -reviewed |
| Release notes | **Confluence** (or GitHub release) | External audience |
| Tracked work (features, bugs, debt being worked) | **Jira** | Lifecycle-tracked by team |

## The rule

- **Operational / per-agent** → `.memory/`
- **Team-canonical / durable / referenced by humans** → Confluence
- **Lifecycle-tracked work** → Jira

## Cross-layer linking

When knowledge spans layers, cross-reference:
- ADR in Confluence → add one-line entry in `.memory/LESSONS.md` with the Confluence link. So agents recall the decision without loading the full ADR.
- Tech debt in TECH_DEBT.md → add `Ticket: PROJ-1234` column when a Jira ticket tracks the work.
- PR description → reference ticket key and link to Confluence spec if applicable.

## When to ask vs auto-decide

- **Auto-apply:** agent operational state (MAP, SYMBOLS, RESUME, LESSONS about agent mistakes, CONVENTIONS observed).
- **Ask user:** creating Jira tickets, publishing to Confluence, ADR decisions. These are team-visible — don't surprise the team.
- **Config-driven:** transitions, reassignments per `.memory/JIRA_WORKFLOW.md` (if set up). Auto-apply per config; ask for anything not covered.

## What NOT to do

- Don't duplicate canonical knowledge into `.memory/`. If an ADR exists in Confluence, link to it from LESSONS.md — don't copy it.
- Don't put agent operational state in Confluence. MAP.md and SYMBOLS.md belong in memory; they change constantly.
- Don't file a Jira ticket for every finding. Tech debt that's small + local stays in TECH_DEBT.md. Tickets are for work the team plans to schedule.

**No gate.** This is an advisory skill — apply judgment when deciding where knowledge belongs.
