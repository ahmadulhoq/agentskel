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

Reduces **harness-level permission prompts** for safe, routine operations. When Autopilot Mode is on, the tool (Claude Code / Cursor / etc.) stops asking you "Approve `git status`? Y/N" and "Edit this file? Y/N" for near-zero-risk commands. Trivial permission friction disappears; substantive gates stay.

### What Autopilot Mode does NOT do

Autopilot Mode **does not bypass**:

- **Plan approval.** Every workflow still requires the user to approve a plan before implementation starts. Plan-first is unchanged.
- **Design decisions.** Any real decision the user has to make is still surfaced. Concerns raised by the agent (architecture flags, potential-conflict warnings) are still presented for user response.
- **Significant-change gate.** The v1.65.0 gate for `SIGNIFICANT CHANGE` rows still fires: >30 lines of existing logic altered / public API change / documented behavior removal / sacred behavior touch → separate explicit confirmation required.
- **Concerns.** If the agent has doubts or discovers something the plan didn't anticipate, the agent stops and asks.

The mode is about eliminating **the "approve every tool call" tax**, not about eliminating **the "approve every decision" gate**.

### How it works

Two-layer enforcement lives inside `.claude/settings.json`:

**Layer 1 — expanded `permissions.allow` allowlist:**

The template ships pre-approvals for read-only ops (already in v1.66.0) plus safe writes and safe git operations:

- Reads: `ls`, `cat`, `grep`, `find`, `git log`, `git status`, `git diff`, etc.
- Writes: `Edit(**)`, `Write(**)` — file edits within the project
- Git: `git add`, `git commit`, `git push`, `git pull`, `git fetch`, `git checkout`, `git merge`, `git stash`, `git worktree`
- GitHub CLI: `gh pr *`, `gh issue *`, `gh api *`

**Layer 2 — `pre-bash-safety.sh` hook (installed to `.claude/hooks/`):**

Blocks destructive patterns with exit code 2 + a stderr message, **regardless of what the allowlist accepts**. The allowlist uses glob matchers (`Bash(git push *)` would match `git push --force`), so the safety hook enforces the block explicitly.

Blocked patterns:
- `git push --force` / `-f` / `--force-with-lease`
- `git reset --hard`
- `git branch -D` (force-delete)
- `git checkout -- <file>` (discards uncommitted changes)
- `git checkout .` (discards all uncommitted)
- `git clean -f` (force-remove untracked)
- `rm -rf` / `-fr` / `-Rf` (recursive force delete)
- `git worktree remove --force`

Verified with 14 automated test cases (see PR #54 for the test matrix). Correctly allows `git branch -d` (safe delete), `git checkout main` (branch switch), `git status`, `git commit -m "reset --hard state"` (string in message, not a command).

### What still pauses

Even in Autopilot, these keep the agent honest:

1. **Anything the safety hook blocks** (list above).
2. **Out-of-project paths.** Writes outside the repo root (parent dirs, `/tmp`, system dirs) aren't in `Edit(**)`/`Write(**)` scope — harness prompts.
3. **Dependency upgrades.** Behavioral rule — the agent asks before running `pip install`, `npm install`, `bundle update`, etc.
4. **Sacred behaviors.** Behavioral rule — the agent never modifies `.memory/SACRED.md`-listed behavior without explicit human approval.
5. **Significant changes** (per v1.65.0 gate) — see above.
6. **Plan approval + concerns** — see above.

### Toggling

- **Persistent only:** edit `.memory/CONFIG.md` `Autopilot Mode` field to `on` or `off`.
- **No one-shot prefix.** Autopilot is a sustained working style.
- **Toggling the flag does NOT reload the harness.** The `permissions.allow` allowlist and the safety hook are always active whenever this settings.json is loaded. The flag is a **posture indicator** — reminds you what mode you're in, surfaces the session-start banner, informs behavioral rule application. Whether the harness prompts you is determined by settings.json at session start, not by the flag at runtime.

If you flip the flag from `off` to `on` mid-session and want the harness prompts to actually change, restart your tool.

### Session-start banner

When Autopilot Mode is `on`, `session-start` surfaces a one-line banner at the start of every session:

```
Autopilot Mode is ON. Harness auto-approves safe operations (reads, project writes, non-destructive git). Destructive ops, out-of-project paths, dependency upgrades, sacred behaviors, and significant changes still pause. See docs/AUTONOMY-MODES.md.
```

### Cross-tool coverage

- **Claude Code:** full support — allowlist + hook.
- **Gemini CLI / Antigravity:** the same hook script contract is honored (Gemini format at `core/gemini-hooks/`); allowlist not applicable.
- **Cursor, Windsurf:** hooks work (per v1.62.x fixes); safety hook installs to their respective hook dirs. Allowlist syntax varies per tool.
- **Copilot:** no hooks. Autopilot Mode relies on behavioral rules alone — agent self-refuses destructive patterns per the core-behavior rule bullet.

### Composition with Claude Code's built-in auto mode

Claude Code shipped its own **Auto Mode** starting in v2.1.183 (June 19, 2026), extended in v2.1.193 / v2.1.195 / v2.1.207. It provides overlapping-but-not-identical protection to agentskel's Autopilot Mode. Both can be on simultaneously — they compose as defense in depth.

**Comparison:**

| Property | agentskel Autopilot Mode + `pre-bash-safety.sh` | Claude Code Auto Mode |
|---|---|---|
| **Enforcement mechanism** | Static `permissions.allow` allowlist + a PreToolUse hook that regex-matches destructive patterns and returns exit 2 | Runtime classifier that routes shell/PowerShell through decision layer + hardcoded block list for known-destructive commands (`git reset --hard`, `git checkout -- .`, `terraform destroy`, etc.) |
| **Scope** | Cross-tool — works for Claude Code, Gemini, Cursor, Windsurf, Codex (behavioral for Copilot) | Claude Code only |
| **What it blocks** | Specific regex-matched patterns: `--force`, `--hard`, `-D`, `checkout --`, `checkout .`, `clean -f`, `rm -rf`, `worktree remove --force` | Destructive git, terraform, pulumi, cdk commands + broader classifier judgments on shell input |
| **How to toggle** | `.memory/CONFIG.md` `Autopilot Mode` field (posture); allowlist + hook always active when installed | Claude Code `/config` toggle or `claude auto-mode reset`; `autoMode.classifyAllShell` setting routes all Bash |
| **Signals when blocked** | stderr message from hook naming the matched pattern + exit 2 | Denial reason in transcript, denial toast, `/permissions` recent denials list |
| **Configurability** | Edit the hook (bash regex); add patterns as needed | Managed via Claude Code settings; classifier not user-modifiable |

**How they compose:**

- Claude Code Auto Mode fires **first** (before the PreToolUse hook chain) — if it blocks or prompts, our hook never runs.
- If Claude Code Auto Mode allows the command, our `pre-bash-safety.sh` hook then runs and can still block on our specific patterns.
- Net effect: **strictest of the two wins.** A command must pass BOTH to execute in Autopilot.

**When to disable one:**

- If you're **Claude-only** and want to rely purely on the built-in system: you can leave our hook installed (it doesn't conflict) or comment it out of `.claude/settings.json` PreToolUse for cleaner logs. Recommend leaving it — near-zero cost, one extra layer of specific pattern coverage.
- If you're **cross-tool** (Gemini/Cursor/Windsurf too): keep our hook — Claude Code Auto Mode won't cover those tools.
- If you want to **loosen** protection (e.g., allow `git branch -D` for a specific task): temporarily disable Autopilot Mode + use Claude Code's `--dangerously-skip-permissions` for that command only. Do not remove patterns from the hook globally.

**When agentskel's coverage is broader:**

- `git worktree remove --force` — not in Claude Code Auto Mode's default block list.
- `git checkout -- <file>` (file discard, not `.` bulk) — Claude Code covers `.` variant; our hook covers both.

**When Claude Code's coverage is broader:**

- Terraform / Pulumi / CDK destroy — outside our scope (agentskel doesn't ship infra tooling patterns).
- Runtime classifier judgments on novel shell input — our hook only catches known regex patterns.

**Denial-message parity:** Claude Code's denial reasons appear in `/permissions recent denials` (v2.1.193+). Our hook writes to stderr but doesn't feed that list. Users switching between the two systems will see denials in different places — that's expected.

### Recovering from a false-positive block

If the safety hook blocks a command you genuinely want to run:
1. Read the stderr message — it names which pattern was matched.
2. Rewrite the command in a safer form (e.g. `git branch -d` instead of `-D`, `git checkout main` instead of `git checkout -- <file>`).
3. If the destructive form is genuinely needed, run it manually outside the agent session.

The hook is deliberately strict — false-positives on legitimate destructive intent are the correct trade-off. The alternative (blindly allowing) is unsafe.

---

## Composing the two modes

The two modes are **orthogonal** — they address different friction axes:
- **Direct-Commit Mode** = end-of-workflow ceremony (branch + PR)
- **Autopilot Mode** = mid-workflow harness prompts

Combined use case: **trivial-but-multi-step work**, e.g. "bump 5 dependencies across N projects."

- Direct-Commit Mode skips the PR ceremony for each.
- Autopilot Mode auto-approves the routine `git add / commit / push` prompts along the way.
- Together: user approves the overall plan once, agent executes all 5 bumps + commits directly + reports — no per-step prompts, no per-commit PR.

The combination remains bounded by the same substantive gates — any significant change (e.g. a dependency bump that requires source changes) still pauses regardless of mode, and any destructive command is blocked by the safety hook regardless of mode.

---

## History

- **v1.64.0** — introduced "Fast Execution Mode" (renamed below).
- **v1.65.1** — renamed Fast Execution Mode → Direct-Commit Mode for clarity ("fast" was ambiguous).
- **v1.66.0** — introduced Autopilot Mode + consolidated both modes into this document.
- **v1.66.1** — wired both modes into workflow procedures. v1.66.0 shipped the modes as documented rules with no procedural enforcement: workflow steps unconditionally created branches (broke Direct-Commit) and unconditionally prompted for tool calls (broke Autopilot). Fixed by: (a) git-flow skill now checks the Direct-Commit flag at Branch Creation + Opening a PR and skips those sections when active + qualifying; (b) settings.json ships expanded `permissions.allow` covering safe writes + git ops plus `pre-bash-safety.sh` hook that blocks destructive patterns regardless of allowlist. Also narrowed Autopilot Mode's rule scope — v1.66.0 wording implied it bypassed workflow approval gates (plan/decisions/concerns); it does not. Autopilot is strictly about harness prompt friction for safe operations.
