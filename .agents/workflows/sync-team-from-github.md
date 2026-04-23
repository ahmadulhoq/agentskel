---
name: sync-team-from-github
description: When the GitHub team and `.memory/TEAM.md` have drifted. Use when you suspect new joiners, leavers, or rotations have happened on GitHub but `TEAM.md` hasn't been updated, and you want a diff-and-reconcile pass rather than editing member-by-member.
---

# Sync Team From GitHub

Detect and reconcile drift between the GitHub team membership and `.memory/TEAM.md`.
Surfaces new joiners and departures in one pass, then runs per-member add/deactivate
flows with your approval.

Prerequisites:
- `gh` CLI must be installed and authenticated.
- `.memory/TEAM.md` must already exist.
- `.memory/CONFIG.md` should have the org + team name configured.

---

## Pre-flight — Load Memory
- [ ] Read `.memory/RULES.md`
- [ ] Read `.memory/MAP.md`
- [ ] Read `.memory/SYMBOLS.md`
- [ ] Read `.memory/RESUME.md` if continuing prior work
- [ ] Read `.memory/LESSONS.md`
- [ ] Read `.memory/SACRED.md`
- [ ] Verify `gh` CLI is authenticated (`gh auth status`) — if not, stop
- [ ] Verify `.memory/TEAM.md` exists — if not, stop and suggest `setup-team`

---

## Step 1 — Fetch GitHub team
- [ ] Read org + team name from `.memory/CONFIG.md`
- [ ] If either value is missing, ask the user to supply it before proceeding
- [ ] Run `gh api orgs/{org}/teams/{team}/members` to fetch the authoritative list of handles
- [ ] Record the full list for diffing in Step 2

---

## Step 2 — Diff
- [ ] Parse active members from `.memory/TEAM.md` (ignore rows with Status: inactive)
- [ ] **New on GitHub, not in TEAM.md:** list handles and ask "Add [handle]? (y/n)" for each
- [ ] **In TEAM.md (active), not on GitHub:** list handles and ask "Mark [handle] inactive? (y/n)" for each
- [ ] Summarise unchanged members (present in both) as a count only

---

## Step 3 — For each approval
- [ ] If adding: run the `add-team-member` workflow inline to collect profile, roles, module assignments, and Jira ID
- [ ] If marking inactive: update Status to `inactive` in the Members table and run reassignment prompts from `remove-team-member` Step 3 for any owned modules or escalation roles
- [ ] Skip any diff entry the user declines

---

## Step 4 — Commit changes
- [ ] Write all updates to `.memory/TEAM.md` in a single pass
- [ ] Verify the file is valid markdown and all tables are well-formed
- [ ] Note that commit to the ai-memory branch happens via the Task Completion Checklist

---

## Step 5 — Report
- [ ] Report to the user: "Added N, marked M inactive. Unchanged: K."
- [ ] Flag any members left without valid escalation or ownership coverage

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.
