# Autonomy Modes — agentskel

agentskel has two independent toggles in `.memory/CONFIG.md` that reduce friction during agent work. They address **different** sources of friction and can be used independently or combined.

| Mode | What it skips | When to use | Toggle |
|---|---|---|---|
| **Direct-Commit Mode** | End-of-workflow ceremony: branch + PR | Trivial work where review value is near zero (typo fix, version marker, lockfile bump) | `Direct-Commit Mode \| on` in CONFIG.md, OR one-shot `direct:` prefix |
| **Autopilot Mode** | Mid-workflow per-step approval prompts | Routine work where the plan is clear and you trust the agent to execute within scope | `Autopilot Mode \| on` in CONFIG.md (persistent only) |

The two modes are **orthogonal**. You can have neither, either, or both on:

| Direct-Commit | Autopilot | Resulting flow |
|---|---|---|
| off | off | Traditional: prompts at every step + branch+PR ceremony |
| **on** | off | Direct commits to default branch + still prompts per step |
| off | **on** | Branch+PR flow + no per-step prompts (work proceeds smoothly within approved plan) |
| **on** | **on** | Minimum friction: direct commits + no per-step prompts (only significant changes pause) |

---

## Direct-Commit Mode

### What it does

Skips the **branch + PR ceremony**. Agent commits and pushes directly to `[Default Branch]`. Everything else stays: plan-first approval gate, task-completion checklist, validator, sacred-behaviors check.

### Procedure when active

1. Plan-first still applies — user must approve the change before any Edit/Write tool call.
2. Surface a banner BEFORE any commit:
   ```
   DIRECT-COMMIT MODE ACTIVE — committing directly to [DEFAULT_BRANCH] (no PR).
   ```
   Surfacing is non-optional — ceremony-skipping must be visible.
3. Verify the work is genuinely trivial. Anything touching logic, security, schema, or sacred behaviors → Direct-Commit Mode does NOT apply; fall back to the full flow and inform the user.
4. Commit directly to `[Default Branch]` (no feature branch).
5. Push directly to origin (no PR opened).
6. Task-completion checklist still runs in full: CHANGELOG, TIME_LOG, RESUME, memory commit. Validator still runs.

### Toggling

- **Persistent:** edit `.memory/CONFIG.md` `Direct-Commit Mode` field to `on` or `off`.
- **One-shot:** prefix a single request with `direct:` (e.g. `direct: bump python in versions.md`). The flag stays off; only that one task uses Direct-Commit Mode.

### When to refuse

The agent refuses Direct-Commit Mode for:
- Changes to `.agents/`, `core/`, `roles/`, or any skill/workflow/rule logic
- Changes to `.memory/SACRED.md`-listed behavior
- More than ~3 files modified
- Any non-trivial logic change

If the user invokes Direct-Commit Mode for one of these, surface a one-line objection:
```
Refusing Direct-Commit Mode — change touches X; switching to full flow.
```
and proceed with the normal branch + PR flow.

---

## Autopilot Mode

### What it does

After a plan has been approved, the agent **proceeds within the plan's scope without per-step approval prompts**. Reduces interruptions that hamper flow once the user has already signed off on the approach.

### What stays paused (even in Autopilot)

The mode reduces *procedural* friction without removing *substantive* gates. The agent **always pauses** for:

1. **Significant change** (per v1.65.0 gate) — any of:
   - More than 30 lines of existing logic altered (not counting whitespace, comments, or pure-additions)
   - Public API signature change (exported function, REST endpoint, schema)
   - Documented behavior removed or replaced
   - `.memory/SACRED.md`-listed behavior touched
2. **Destructive operations** — `rm -rf`, `git push --force`, `git reset --hard`, `git branch -D`, DB drop, `--no-verify`
3. **Out-of-project paths** — anything outside the project's repo root (parent dirs, `/tmp`, system dirs)
4. **Dependency changes** — toolchain or library version bumps (existing rule)
5. **Scope deviations** — work the approved plan didn't cover. If the agent realises it needs to do something the plan didn't anticipate, that's a re-plan, not autopilot work.

For each pause, the agent surfaces a one-line `PAUSE: <reason>` and waits for explicit confirmation before proceeding.

### Procedure when active

1. **Plan-first still applies.** Autopilot Mode does **not** skip the planning phase. The agent still drafts a plan and waits for approval before any Edit/Write tool call. Autopilot kicks in *after* the plan is approved.
2. The plan should explicitly enumerate the scope (files to modify, behaviors to change). This is what defines "in-scope" for autopilot execution.
3. While executing the approved plan:
   - Routine ops within scope → proceed without prompting
   - Out-of-scope work or any of the pause categories above → pause and confirm
4. Task-completion checklist still runs in full at the end.
5. Validator still runs.

### Toggling

- **Persistent only:** edit `.memory/CONFIG.md` `Autopilot Mode` field to `on` or `off`.
- **No one-shot prefix.** Per-task autopilot didn't seem useful — autopilot is a sustained working style, not a one-off ask.

### Session-start banner

When Autopilot Mode is `on`, `session-start` surfaces a one-line banner at the start of every session so the user is reminded:

```
Autopilot Mode is ON. Agent will proceed within the approved plan without per-step approvals. Significant changes, destructive ops, and out-of-scope work still pause.
```

If the user has changed their mind, they can toggle it off before starting work.

### When to refuse

Autopilot Mode is automatically suspended (not refused outright — only suspended for the current step) when the agent encounters any of the "always pauses" categories. The flag stays `on`; the next routine step resumes autopilot behavior.

If the user explicitly invokes Autopilot Mode for a project that has no `.memory/CONFIG.md` file yet, or where the plan has not been approved, surface an objection:
```
Refusing Autopilot Mode — no approved plan in scope. Autopilot requires plan approval first.
```

---

## Composing the two modes

Combined use case: **trivial-but-multi-step work**, e.g. "bump 5 dependencies across N projects."

- Direct-Commit Mode skips the PR ceremony for each.
- Autopilot Mode skips the per-step approval for each.
- Together: user approves the overall plan once, agent executes all 5 bumps + commits directly + reports.

The combination remains bounded by the same gates — any significant change (e.g. a dependency bump that requires source changes) still pauses, regardless of mode.

---

## Harness-side complement (Claude Code, Cursor, etc.)

The harness layer (`.claude/settings.json` permission allowlist) is separate from agentskel's modes but complements them. Agentskel ships a recommended default `permissions.allow` list for read-only Bash patterns (`ls`, `grep`, `find`, `git log`, `git status`, `git diff`, etc.) so the harness stops prompting on near-zero-risk commands. This applies regardless of which agentskel mode is on; it's a baseline.

For write operations and shell commands not in the default allowlist, the harness will still prompt — agentskel's modes don't override the harness's permission model. Users wanting *minimum* harness prompts can run their session with `--permission-mode acceptEdits` (Claude Code) or equivalent in their tool, but that's a per-session decision, not an agentskel setting.

---

## History

- **v1.64.0** — introduced "Fast Execution Mode" (renamed below).
- **v1.65.1** — renamed Fast Execution Mode → Direct-Commit Mode for clarity ("fast" was ambiguous).
- **v1.66.0** — introduced Autopilot Mode + consolidated both modes into this document.
