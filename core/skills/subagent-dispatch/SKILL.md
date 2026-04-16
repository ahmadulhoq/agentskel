---
name: subagent-dispatch
description: When delegating work to a subagent — implementation, review, research,
  or exploration. Use when a task benefits from a fresh context window, parallel
  execution, or isolated scope.
---

# Subagent Dispatch

**Principle:** The parent agent has full context (rules, memory, conventions). It
creates the plan. Subagents execute plan steps — they don't rediscover the project.

---

## When to Dispatch

| Signal | Why |
|---|---|
| Plan has independent steps that can run in parallel | Concurrent execution saves time |
| Context window is getting large | Fresh subagent avoids attention decay |
| Research would pollute main context with raw file reads | Subagent returns a summary |
| Code review needs a fresh perspective | Reviewer hasn't seen implementation reasoning |

**Do NOT dispatch when:** steps have sequential dependencies, or the task is simpler
to do directly than to explain.

---

## How to Dispatch

The parent creates the plan first (via task-planner or workflow Phase 1), then
identifies which steps can run in parallel.

### Implementation dispatch
Pass the specific plan steps. The parent already checked rules, conventions, and
sacred behaviors when creating the plan — the subagent doesn't need to re-read them.

```
"Execute steps 3-5 from the plan:
 - Step 3: [exact instruction]
 - Step 4: [exact instruction]
 - Step 5: [exact instruction]
 Files to modify: [list].
 Do not commit or push."
```

### Review dispatch
The reviewer needs to know what to check against. Include references to constraints.

```
"Review the changes made to [files].
 Read .memory/SACRED.md — verify no sacred behaviors were modified.
 Read .memory/CONVENTIONS.md — verify code follows project conventions.
 Check against the plan: [paste or summarize the plan].
 Report: issues found, verdict (approve/request changes)."
```

### Research dispatch
Pass the question. No rules needed.

```
"How does [module X] connect to [module Y]? Read MAP.md for orientation.
 Report: answer, evidence (file:line), relevant files."
```

---

## Validate Results

- [ ] Read the subagent's output
- [ ] Verify it meets the plan's success criteria
- [ ] Check for side effects (unexpected file changes)
- [ ] If validation fails, re-dispatch with corrected instructions

---

## Rules

1. **Subagents do NOT run session-start.** They execute plan steps, not session init.
2. **Subagents do NOT commit or push.** The parent handles git.
3. **One task per subagent.** Don't batch unrelated work.
4. **Only dispatch independent steps.** Sequential dependencies stay with the parent.

---

**No gate.** Dispatch is a judgment call based on task size and parallelism opportunity.
