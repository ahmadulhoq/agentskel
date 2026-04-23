---
name: add-team-member
description: When a single new person joins the team. Use when `.memory/TEAM.md` already exists and you need to append one member (with roles, optional module assignments, and optional Jira account ID) without touching the rest of the roster.
---

# Add Team Member

Append a single team member to `.memory/TEAM.md`, resolving GitHub profile data and
(optionally) Jira account ID automatically. For bulk bootstrap, use `setup-team` instead.

Prerequisites:
- `.memory/TEAM.md` must already exist. If not, stop and suggest running `setup-team` first.
- `gh` CLI is optional but used as an accelerator.
- Atlassian MCP is optional; used only if `.memory/CONFIG.md` has `Jira Site` set.

---

## Pre-flight — Load Memory
- [ ] Read `.memory/RULES.md`
- [ ] Read `.memory/MAP.md`
- [ ] Read `.memory/SYMBOLS.md`
- [ ] Read `.memory/RESUME.md` if continuing prior work
- [ ] Read `.memory/LESSONS.md`
- [ ] Read `.memory/SACRED.md`
- [ ] Verify `.memory/TEAM.md` exists — if not, stop and suggest `setup-team`

---

## Step 1 — GitHub handle
- [ ] Ask: "GitHub handle?"
- [ ] If `gh` is available, run `gh api users/{handle}` to fetch name and email
- [ ] If the handle doesn't resolve, confirm with the user before proceeding

---

## Step 2 — Profile
- [ ] Ask: "Full name?" (pre-filled if `gh` succeeded)
- [ ] Ask: "Email?" (pre-filled if `gh` succeeded)
- [ ] Accept user overrides for either field

---

## Step 3 — Roles
- [ ] Ask: "Role(s)? (tech-lead / senior-reviewer / dev / qa / product, comma-separated)"
- [ ] Validate that each role is one of the allowed values

---

## Step 4 — Module assignments (optional)
- [ ] If `TEAM.md` contains ownership entries, ask: "Assign to modules? List comma-separated, or 'none'"
- [ ] For each listed module, ask: "Role there — code owner / senior reviewer / QA owner / none?"
- [ ] Skip entirely if TEAM.md has no ownership table or user answers 'none'

---

## Step 5 — Jira lookup (if configured)
- [ ] Check whether `.memory/CONFIG.md` has `Jira Site` set
- [ ] If set, invoke the `atlassian-integration` skill
- [ ] Call `lookupJiraAccountId` with the member's email
- [ ] Store the returned Jira account ID alongside the member record
- [ ] If the lookup fails, record the member without a Jira ID and note it for the user

---

## Step 6 — Update TEAM.md
- [ ] Add a new row to the Members table with Status: active
- [ ] Update the Ownership table if module assignments were provided in Step 4
- [ ] Preserve existing rows and formatting — do not rewrite unrelated sections
- [ ] Note that commit to the ai-memory branch happens via the Task Completion Checklist

---

## Step 7 — Confirm
- [ ] Show the updated member row(s) to the user
- [ ] Confirm roles, email, Jira ID (if any), and module assignments are correct

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.
