---
description: Workspace routing — identify platform before any task.
---

# Workspace Routing

Before responding, identify which platform the user's request belongs to:
- Named platform in request → use that platform
- Specific files mentioned → check which subdir contains them
- Ambiguous → ASK the user

Then `cd` into that subdir and read `<subdir>/AGENTS.md`. Execute the task within
that subdir — each platform has its own agentskel installation, rules, memory,
and enforcement hooks.

## Never at workspace root
- Create `.memory/` or `.agents/` (those belong in subdirs).
- Commit application code (there is none here — only dispatcher files).
- Mix rules across platforms.
