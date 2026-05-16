---
name: discussion-continuity
license: MIT
description: When a design discussion or evaluation is interrupted by a task or workflow, or when the user says "present the discussion," "where were we," "show me the discussion," or "resume" — save or resurface the discussion state using Session Notes.
---

# Skill: Discussion Continuity

Discussions have no formal lifecycle. This skill gives them one — a save point
before interruption and a defined retrieval on return.

---

## Operation A — PAUSE (save before switching)

**Trigger:** Agent has an open unanswered gate question AND the user redirects
to a different task or workflow.

Execute as the **first action** before switching — before any file edits,
before any workflow steps.

1. Write a structured entry to `.memory/RESUME.md` Session Notes:

   ```
   DISCUSSION PAUSED: [topic]
   Agreed: [bullet — one line per agreed decision, or "none yet"]
   Open: [bullet — each pending decision with its options]
   Gate: [exact unanswered question the agent was waiting on]
   ```

2. Confirm to the user: "Discussion state saved. Switching to [task]."
3. Then execute the interrupting task.

**Important:** The gate field is what prevents treating the return phrase as
implementation approval. If the gate is recorded, the agent re-asks it on
resume instead of assuming approval.

---

## Operation B — RESUME (resurface on return)

**Trigger:** Any of:
- User says "present the discussion," "where were we," "show me the discussion,"
  "back to [topic]," or "resume"
- task-completion Step 6c detects a `DISCUSSION PAUSED:` entry in Session Notes

Steps:
1. Read `.memory/RESUME.md` Session Notes.
2. Find any entries prefixed `DISCUSSION PAUSED:`.
3. Re-present with full structure — topic, agreed decisions, open decisions
   with options, and the gate question.
4. Re-ask the gate question explicitly. Do NOT treat the return phrase as an
   answer to the gate.
5. Remove the `DISCUSSION PAUSED:` entry from Session Notes only after the
   gate is answered and discussion is resolved or explicitly parked.

---

## Format example

```
DISCUSSION PAUSED: BACKLOG.md design
Agreed: single flat table with Priority column; ID format BL-NNN; Done capped at 5
Open: (1) Backlog Mode field for Jira? options: column vs config field vs none
      (2) Name — BACKLOG vs TODO?
      (3) Capture convention — how "add to todo" maps to a file
Gate: "Want to proceed with implementation, or adjust the design first?"
```

---

## What this does NOT solve

- Agent failing to detect the interruption moment — the PAUSE operation still
  relies on the agent recognizing an open gate + redirect. This is the weakest
  link. task-completion Step 6c provides the safety net for missed saves.
- Multiple simultaneous paused discussions — if two discussions are paused,
  resurface both and ask the user which to resolve first.
