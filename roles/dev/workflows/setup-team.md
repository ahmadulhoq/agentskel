---
name: setup-team
description: When bootstrapping a project's team roster. Use when `.memory/TEAM.md` has not yet been populated and you need to establish members, roles, ownership, and escalation contacts for the first time.
---

# Setup Team

Populate `.memory/TEAM.md` for this project, pulling members from GitHub where possible
and falling back to manual entry. Establishes roles, module ownership, and escalation
contacts that downstream workflows (code review, QA handoff, incident response) rely on.

Prerequisites:
- CWD must be a project with `.memory/` mounted (not a workspace dispatcher).
- `gh` CLI is optional but strongly recommended as an accelerator.
- Skeleton path must be resolvable (see `.memory/CONFIG.md`).

---

## Pre-flight — Load Memory
- [ ] Read `.memory/RULES.md`
- [ ] Read `.memory/MAP.md` (note the module registry for Step 4 suggestions)
- [ ] Read `.memory/SYMBOLS.md`
- [ ] Read `.memory/RESUME.md` if continuing prior work
- [ ] Read `.memory/LESSONS.md`
- [ ] Read `.memory/SACRED.md`
- [ ] Confirm CWD is a project with `.memory/` mounted (NOT a workspace dispatcher — abort if dispatcher-only)

---

## Step 1 — Try GitHub (accelerator)
- [ ] Run `gh auth status` to check if `gh` CLI is authenticated
- [ ] If authenticated: ask user to confirm org + team name (pre-fill from `.memory/CONFIG.md` if present)
- [ ] Run `gh api orgs/{org}/teams/{team}/members` to fetch the member list
- [ ] Read `.github/CODEOWNERS` if present — extract handles that appear as owners
- [ ] If `gh` is unavailable or not authenticated, skip to Step 2 (manual entry)

---

## Step 2 — Confirm/extend members
- [ ] Show auto-detected members to user: "Found: alice, bob, charlie. Add more or confirm?"
- [ ] User adds any missing handles as a comma-separated list
- [ ] Build the final roster list before moving on

---

## Step 3 — Fill roles and details per member
- [ ] For each member, ask: "[handle] — full name?" (pre-fill from `gh api users/{handle}` if available)
- [ ] Ask: "[handle] — role(s)? (tech-lead / senior-reviewer / dev / qa / product, comma-separated)"
- [ ] Record email if returned by `gh api users/{handle}` (may be null for private profiles)

---

## Step 4 — Ownership map (optional)
- [ ] Ask "Do you have distinct modules or areas with specific owners? (y/n)"
- [ ] If yes: "List modules (comma-separated)" — suggest modules from MAP.md module registry
- [ ] For each module, ask: code owner / senior reviewer / QA owner (pick from team members)
- [ ] Skip this step entirely if the user answers no

---

## Step 5 — Escalation contacts
- [ ] Ask: "Blockers → tag who?"
- [ ] Ask: "Spec questions → tag who?"
- [ ] Ask: "Production incidents → tag who?"
- [ ] All three escalation contacts must resolve to members already captured in Step 3

---

## Step 6 — Write TEAM.md
- [ ] Read the template from `[SKELETON_PATH]/core/memory/TEAM.md`
- [ ] Populate the Members, Ownership, and Escalation tables from Steps 3–5
- [ ] Write the populated file to `.memory/TEAM.md`
- [ ] Verify the file is valid markdown and all tables are well-formed

---

## Step 7 — Confirm and next steps
- [ ] Show the written `TEAM.md` to the user for review
- [ ] If Atlassian MCP is connected: "Run `setup-jira` next? I'll auto-fill Jira account IDs for each member."
- [ ] Note that commit to the ai-memory branch happens via the Task Completion Checklist

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.
