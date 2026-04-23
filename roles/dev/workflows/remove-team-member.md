---
name: remove-team-member
description: When someone leaves the team or rotates off the project. Use when you need to mark a member inactive (or delete them outright) in `.memory/TEAM.md` and reassign any ownership or escalation responsibilities they held.
---

# Remove Team Member

Remove or mark inactive a team member in `.memory/TEAM.md`. Surfaces and reassigns any
ownership or escalation responsibilities the member held so downstream workflows remain
well-defined.

Prerequisites:
- `.memory/TEAM.md` must already exist.
- Default removal mode is "mark inactive" — history is preserved unless the user
  explicitly chooses to delete the row.

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
- [ ] Ask: "Which member to remove? (GitHub handle or name)"
- [ ] Resolve the input to an exact row in the Members table
- [ ] If multiple matches or no match, ask the user to disambiguate

---

## Step 2 — Impact check
- [ ] Show what this member owns in the Ownership table (if any)
- [ ] Show whether they appear as blocker / spec / incident escalation contact (if any)
- [ ] If nothing is impacted, note it and skip Step 3

---

## Step 3 — Reassignment
- [ ] If they own modules: "Reassign [module] (code owner) to whom? Reassign (QA owner) to whom?" — pick from remaining active members
- [ ] If they're an escalation contact: "New [blocker / spec / incident] contact?"
- [ ] Confirm all reassignments with the user before applying

---

## Step 4 — Removal mode
- [ ] Ask: "Mark inactive (preserves history) or delete entirely?"
- [ ] Default to "mark inactive" if the user doesn't specify
- [ ] Confirm the chosen mode before applying

---

## Step 5 — Update TEAM.md
- [ ] If inactive: change Status to `inactive` in the Members table
- [ ] If delete: remove the row from the Members table entirely
- [ ] Apply reassignments from Step 3 to the Ownership and Escalation tables
- [ ] Note that commit to the ai-memory branch happens via the Task Completion Checklist

---

## Step 6 — Confirm
- [ ] Show the updated TEAM.md sections to the user
- [ ] Confirm the member is no longer referenced in any active ownership or escalation role

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.
