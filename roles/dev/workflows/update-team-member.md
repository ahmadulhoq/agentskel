---
name: update-team-member
description: When an existing team member's roles, ownership, or contact info changes. Use when a member stays on the team but their responsibilities, email, or handle need to be updated without adding or removing anyone.
---

# Update Team Member

Update roles, module ownership, or contact info for a member that already exists in
`.memory/TEAM.md`. For adding new people use `add-team-member`; for departures use
`remove-team-member`.

Prerequisites:
- `.memory/TEAM.md` must already exist.
- The member being updated must already be present in the Members table.

---

## Pre-flight — Load Memory
- [ ] Read `.memory/RULES.md`
- [ ] Read `.memory/MAP.md`
- [ ] Read `.memory/SYMBOLS.md`
- [ ] Read `.memory/RESUME.md` if continuing prior work
- [ ] Read `.memory/LESSONS.md`
- [ ] Read `.memory/SACRED.md`
- [ ] Verify `.memory/TEAM.md` exists — if not, stop

---

## Step 1 — Identify
- [ ] Ask: "Which member? (GitHub handle or name)"
- [ ] Resolve to an exact row in the Members table
- [ ] If no match, ask the user to disambiguate or suggest `add-team-member`

---

## Step 2 — What to change
- [ ] Ask: "What to change? (roles / ownership / contact info / all)"
- [ ] Record the set of fields the user wants to modify

---

## Step 3 — Apply changes
- [ ] If roles: ask "New role(s)?" and apply (validate against allowed values)
- [ ] If ownership: ask "Add to / remove from which modules? What role in module?" and apply
- [ ] If contact: ask "New email? GitHub handle (if changed)?" and apply
- [ ] Confirm each change before writing

---

## Step 4 — Update JIRA_WORKFLOW.md if needed
- [ ] If roles changed and the member was referenced in handoff rules (e.g. QA owner for a module), note that handoff rules will now resolve to a different person
- [ ] If `.memory/JIRA_WORKFLOW.md` exists, review it for direct references to this member by name or handle
- [ ] Flag any downstream rule changes to the user for confirmation

---

## Step 5 — Save and commit
- [ ] Write the updated rows to `.memory/TEAM.md`
- [ ] Preserve all other members and tables untouched
- [ ] Note that commit to the ai-memory branch happens via the Task Completion Checklist

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.
