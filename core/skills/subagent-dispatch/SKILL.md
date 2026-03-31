---
name: subagent-dispatch
description: When delegating work to a subagent — implementation, review, research,
  or exploration. Use when a task benefits from a fresh context window, parallel
  execution, or isolated scope.
---

# Subagent Dispatch

**Purpose:** Formalize how to delegate tasks to subagents with explicit context,
scope boundaries, and result validation.

---

## Step 1 — Decide Whether to Dispatch

Dispatch a subagent when any of these apply:

| Signal | Why dispatch helps |
|---|---|
| Task is self-contained with clear inputs/outputs | Subagent works in focused context without main-session noise |
| Main context window is getting large | Fresh subagent avoids attention decay on earlier instructions |
| Multiple independent tasks can run in parallel | Subagents execute concurrently |
| Task requires exploration that would pollute main context | Research results come back summarized, not raw |
| Code review benefits from a fresh perspective | Reviewer hasn't seen the implementation reasoning |

**Do NOT dispatch when:** the task requires awareness of the full conversation history,
or when the overhead of writing the prompt exceeds doing the work directly.

---

## Step 2 — Select a Prompt Template

Choose the appropriate template from `prompts/`:

| Template | Use when |
|---|---|
| `implementer.md` | Subagent writes code — features, fixes, refactors |
| `reviewer.md` | Subagent reviews code for quality, spec compliance, or bugs |
| `researcher.md` | Subagent explores codebase, reads docs, investigates a question |

---

## Step 3 — Fill the Template

- [ ] Fill all template variables (marked with `[BRACKETS]`)
- [ ] Set explicit scope boundaries: which files to read, modify, and NOT touch
- [ ] Include relevant `.memory/` context — at minimum `CONVENTIONS.md` and `SACRED.md`
- [ ] Define success criteria the subagent can self-verify against
- [ ] Define the expected output format (diff, report, test results, summary)

---

## Step 4 — Launch and Validate

- [ ] Launch the subagent with the filled prompt
- [ ] Read the subagent's output
- [ ] Verify it meets the success criteria
- [ ] Check for side effects (unexpected file changes, dependency additions)
- [ ] If validation fails, re-dispatch with corrected instructions — do not manually
      fix the subagent's work unless the fix is trivial

---

## Rules

1. **Subagents do NOT run session-start.** They don't need full memory context —
   the parent provides relevant context in the prompt.
2. **Subagents DO follow core-behavior rules.** Include a reference to `.agents/rules/`
   if the subagent will make decisions.
3. **Subagents do NOT commit or push** unless the parent explicitly authorized
   implementation in the prompt.
4. **One task per subagent.** Never dispatch a subagent with multiple unrelated tasks.
5. **Include enough context.** The subagent has no memory of the conversation. If it
   needs to know about a constraint, put it in the prompt.

---

## Common Rationalizations

| Rationalization | Why it's wrong | Do this instead |
|---|---|---|
| "I can do this myself faster" | Subagents preserve your context window. Future-you benefits from a cleaner main context. | Dispatch. |
| "The task is too complex to explain in a prompt" | If you can't write the prompt, the task isn't well-defined enough. | Break it down further, then dispatch. |
| "I'll review the code myself instead of dispatching a reviewer" | Self-review catches fewer issues than a fresh-context review. | Dispatch a reviewer. |
| "Setting up the prompt template is overhead" | The template takes 2 minutes. Manual context management takes longer and is error-prone. | Use the template. |
| "The subagent might get it wrong" | That's what Step 4 validation is for. A wrong result you catch is better than a polluted context window. | Dispatch, then validate. |

---

**Gate:** Do not dispatch a subagent without filling a prompt template (Step 3)
and defining success criteria.
