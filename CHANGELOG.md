# agentskel Changelog

## v1.66.1 — 2026-07-18

### Wire Direct-Commit + Autopilot Mode enforcement (v1.66.0 shipped modes as prose-only)

Bug fix. v1.66.0 introduced both autonomy modes as documented rules with **no procedural enforcement**. Result: flipping the flag did nothing. This release wires both modes into workflow procedures + harness settings so the flag actually changes behavior.

**What was broken in v1.66.0:**
- `git-flow` Branch Creation section was unconditional — never checked Direct-Commit Mode flag. Same for Opening a PR.
- `implement-task.md` Phase 1b and `develop-feature.md` Pre-Flight unconditionally created branches.
- `.claude/settings.json` `permissions.allow` only covered read-only Bash. Writes, safe git ops, and safe gh commands still prompted regardless of Autopilot Mode.
- Autopilot Mode's rule wording implied it bypassed workflow approval gates (plan/decisions/concerns) — user clarified it does NOT.

**Direct-Commit Mode wiring:**
- `git-flow` skill Branch Creation: prepends a Direct-Commit Mode check. If flag on OR request prefixed `direct:` AND change qualifies → skip section entirely, stay on default branch, surface banner. If disqualified → surface refusal + continue full flow.
- `git-flow` skill Opening a PR: same check — if Direct-Commit Mode was active, skip section entirely; push directly to default branch instead.
- `implement-task.md` Phase 1b: rewritten to route through git-flow's mode-aware Branch Creation.
- `develop-feature.md` Pre-Flight step 5: same routing.

**Autopilot Mode wiring — two layers:**
- **Layer 1 — expanded `permissions.allow` allowlist.** Added safe write patterns (`Edit(**)`, `Write(**)`) and safe git/gh ops (`git add / commit / push / pull / fetch / checkout / merge / stash / worktree`, `gh pr / issue / api`). Now the harness stops prompting on the routine operations that constitute the bulk of an implementation session.
- **Layer 2 — new `pre-bash-safety.sh` hook.** Because glob matchers (`Bash(git push *)`) also match destructive variants (`git push --force`), a safety hook enforces the "always pause" boundary explicitly. Blocks: `--force` / `-f` / `--force-with-lease` on push; `--hard` on reset; `-D` on branch; `--` and `.` on checkout (file discard); `-f` on clean; recursive-force rm; `--force` on worktree remove. Blocks with exit code 2 + a clear stderr message. 14 automated test cases verify block/allow accuracy including that patterns inside commit message strings don't false-positive.

**Autopilot rule scope narrowed** (per user correction):
- v1.66.0 wording: "agent proceeds within plan's scope without per-step approvals" — implied bypassing workflow approval gates.
- v1.66.1 wording: "harness auto-approves safe operations (reads, project writes, non-destructive git/gh) via expanded permissions.allow + pre-bash-safety.sh hook — so trivial permission prompts don't interrupt work. Does NOT bypass plan approval, decisions, or concerns."
- Propagated to canonical `core-behavior.md` + all 10 inline rule files.

**docs/AUTONOMY-MODES.md rewritten** for Autopilot section with the correct model — two-layer harness enforcement, what stays paused, recovery from false-positives, cross-tool coverage, session-restart requirement to load new settings.

**Downstream migration — sync-skeleton Step 5k (new):**
- Merges expanded `permissions.allow` into project's `.claude/settings.json` (preserves user-edited entries).
- Installs `pre-bash-safety.sh` to `.claude/hooks/`.
- Wires the hook into `PreToolUse.Bash.hooks` before the existing pre-commit / pre-memory-push hooks.
- Cross-tool coverage instructions for Gemini/Cursor/Windsurf/Codex/Copilot.
- Session-restart hint at the end.

**Cross-tool coverage:**
- Claude Code: full support (allowlist + hook).
- Gemini/Cursor/Windsurf: hook script contract compatible per v1.62.x fixes.
- Codex: same script format as Claude.
- Copilot: no hooks — behavioral rule only.

**Files touched (~16):**
- git-flow skill ×2 (source + .agents/)
- implement-task workflow ×2
- develop-feature workflow ×2
- 4 core-behavior copies (canonical ×2 + .agents mirror + .claude mirror)
- 10 inline rule files (5 templates + 5 installed copies)
- new `core/claude-hooks/pre-bash-safety.sh` + `.claude/hooks/pre-bash-safety.sh`
- `core/claude-hooks/settings.json` + `.claude/settings.json`
- sync-skeleton workflow ×2 (new Step 5k)
- `docs/AUTONOMY-MODES.md`
- version markers (5) + top-level CHANGELOG

affected: git-flow, implement-task, develop-feature, core-behavior, sync-skeleton

## v1.67.0 — 2026-08-05

### Two new dev-role skills: `database-migration` and `data-model-mapping`

**1. `database-migration` (new).** Advisory skill covering safe schema-migration practices across any tool (Alembic, Rails, Prisma, Room, Core Data, Flyway, Liquibase, raw SQL). Requires locating the project's existing migration convention before writing a new one, mandatory tested reversibility (up/down), zero-downtime sequencing (additive first — never rename/drop a column in the same migration that introduces its replacement), an explicit-confirmation gate on destructive operations, backfill-before-`NOT NULL` ordering, and a hard rule against editing an already-applied migration.

**2. `data-model-mapping` (new).** Advisory skill targeting a specific recurring failure: a field added to one side of a mapping (model, DTO, DB/ORM entity, cross-platform counterpart) but never propagated to the others, so it's silently dropped. Requires locating every mapped side before editing a model, propagating the change to all of them in the same edit, updating Blueprint parity/domain specs for cross-platform models, tracing the field end-to-end to confirm it survives serialization, and adding a round-trip mapping test.

Both are dev-role skills (`roles/dev/skills/`), same pattern as `developer` / `test-driven-development` — loaded when the triggering scenario applies, not at every session.

affected: database-migration, data-model-mapping

## v1.66.0 — 2026-06-23

### Autopilot Mode + Direct-Commit Mode rename (autonomy modes consolidated)

Two changes folded into one PR — initially scoped as v1.65.1 PATCH (just the rename) and expanded to v1.66.0 MINOR when the new Autopilot Mode joined.

**1. Autopilot Mode (new).** When `Autopilot Mode | on` in `.memory/CONFIG.md`, after a plan has been approved, the agent proceeds within the plan's scope without per-step approval prompts. Reduces interruptions that hamper flow once the user has already signed off on the approach.

**Always pauses for** (reuses v1.65.0 significant-change definition; *substantive* gates preserved):
- Significant changes (>30 lines of existing logic / public API change / documented-behavior removal / sacred touch)
- Destructive ops (rm -rf, git push --force, git reset --hard, branch -D)
- Out-of-project paths
- Dependency changes
- Scope deviations beyond the approved plan

Persistent toggle only — no one-shot prefix (per-task autopilot wasn't useful). `session-start` surfaces a one-line banner each session when the mode is on so the user is reminded. Composable with Direct-Commit Mode (orthogonal axes: Autopilot = mid-workflow friction; Direct-Commit = end-of-workflow ceremony).

**2. Rename: Fast Execution Mode → Direct-Commit Mode.** Original name was ambiguous ("fast" could mean any kind of speed). New name describes the actual behavior — direct commits to default branch instead of branch + PR ceremony.

Renamed across:
- CONFIG.md field `Fast Execution Mode` → `Direct-Commit Mode`
- Banner: `FAST MODE ACTIVE` → `DIRECT-COMMIT MODE ACTIVE`
- One-shot prefix: `fast:` → `direct:`
- Refusal text + section heading in git-flow skill

**3. New doc: `docs/AUTONOMY-MODES.md`.** Canonical reference for both modes — definitions, boundaries, procedure, refusal cases, mode-combination matrix. Linked from CONFIG.md and core-behavior. Replaces the previous duplicated docs in git-flow skill — the skill now keeps a condensed summary + link.

**4. Default `permissions.allow` in settings.json template.** Read-only Bash patterns (`ls`, `cat`, `grep`, `find`, `git log/status/diff/show/branch/remote/ls-files`, etc.) pre-approved so the harness stops prompting on near-zero-risk commands. Applies regardless of which agentskel mode is on; baseline friction reduction.

**5. session-start banner step.** Step 3 (alerts) now reads both mode flags and surfaces a one-line banner when either is on. Both banners appear if both modes are on.

**Validator hardening.** `REQUIRED_PHRASES` extended with `Autopilot Mode` fingerprint (alongside renamed `Direct-Commit Mode`). All 10 inline-rule files verified to contain both phrases. 482 ok / 0 fail.

**Downstream migration.** `sync-skeleton` Step 5j extended:
- Renames `Fast Execution Mode` → `Direct-Commit Mode` (preserves value) for projects synced at v1.64.0 / v1.65.0
- Adds `Autopilot Mode | off` field for any pre-v1.66.0 project
- Merges `permissions.allow` block into `.claude/settings.json` if missing (preserves user-edited entries)

**Files touched (~22):** 4 core-behavior + 10 inline rule files + 2 git-flow + 2 sync-skeleton + 2 session-start + new docs/AUTONOMY-MODES.md + CONFIG template + agentskel's own CONFIG + settings.json template + .claude/settings.json + validator + 5 version markers + top-level CHANGELOG.

affected: core-behavior, git-flow, session-start, sync-skeleton

## v1.65.0 — 2026-06-10

"Fast Execution Mode" was ambiguous — "fast" could mean any kind of speed (fast model, fast response, fast typing) rather than the specific behavior of the mode. The mode skips the **branch + PR ceremony** and commits directly to the default branch. New name maps 1:1 to that behavior.

**Renames:**
- CONFIG.md field: `Fast Execution Mode` → `Direct-Commit Mode`
- `core-behavior.md` rule bullet (both canonical sources + 10 inline-rule files per v1.64.0 propagation discipline)
- `git-flow` skill section heading: `Fast Mode Bypass` → `Direct-Commit Mode` (dropped "Bypass" — direct-commit *is* the bypass)
- Banner text: `FAST MODE ACTIVE` → `DIRECT-COMMIT MODE ACTIVE`
- One-shot prefix: `fast:` → `direct:`
- Refusal message: `Refusing fast mode` → `Refusing Direct-Commit Mode`

**Files touched (16):** core-behavior ×4 (source + .agents/ for both rule families) + 5 inline templates + 5 installed copies + `git-flow` skill ×2 (source + .agents/) + `core/memory/CONFIG.md` + agentskel's own `.memory/CONFIG.md` + validator `REQUIRED_PHRASES` + sync-skeleton migration step (Step 5j) + 5 version markers.

**Downstream migration:** `sync-skeleton` Step 5j renames the CONFIG.md field in projects synced at v1.64.0 / v1.65.0 (preserves the existing `on`/`off` value). Projects pre-v1.64.0 add the field directly from the template via existing field-additions logic — no rename needed.

**No behavior change.** Mode behavior is identical to v1.64.0–v1.65.0; only naming changed.

482 ok / 0 fail on validator.

## v1.65.0 — 2026-06-10

### Agent rigor improvements (3 internal-team-feedback items, one PR)

Internal team feedback surfaced three recurring failure patterns in agent behavior. Each addressed at the workflow / skill / rule level. Bundled into one PR but committed in 4 logical commits (architecture survey, commit granularity, ticket rigor, version + memory) — dogfooding Fix 2's commit-granularity rule.

**Fix 1 — Architecture awareness.** Agents shipped without considering existing architecture and silently worked around patterns that looked wrong.

- `develop-feature.md` and `implement-task.md`: new mandatory **Architecture Survey** sub-step before Phase 1's plan write-up. Agent reads 2-3 nearest existing implementations of the same kind, lists patterns to follow, and surfaces any architectural concern as `FLAG: architecture concern — <description>` in the plan. The user decides whether to fix or proceed — silent deviation is the failure mode being prevented.
- Skip-if-trivial carve-out for typo fixes, version bumps, dependency pins, and one-line copy edits. Plan must state `Architecture survey: skipped — trivial change` when skipping.
- `developer` skill Design Philosophy: new rule "Match existing architecture by default; deviation needs a reason; if existing architecture looks wrong, surface as a FLAG."
- Plan template line added: `Architecture survey result`.

**Fix 2 — Commit granularity instructions persist for the workflow.** Agents treated "smaller commits" as a one-shot instruction and reverted to one-giant-commit on the next step.

- New `## Commit Granularity` section in `git-flow` skill: default is one commit per logical change; user instruction ("smaller commits", "atomic", "per file") applies to **every commit until the workflow ends**, not just the next one. Ambiguous instructions trigger one clarification ask. Plan template line added: `Commit granularity`.
- New bullet in `core-behavior.md` (canonical sources) propagated to all 10 inline-rule files (per v1.64.0 propagation discipline): canonical × 2 + AGENTS.md template & copy + GEMINI.md template & copy + Cursor / Windsurf / Copilot templates & copies.
- Validator's `REQUIRED_PHRASES` extended with fingerprint `Honor user-specified commit granularity`. 482 ok / 0 fail.

**Fix 3 — JIRA ticket rigor.** Agents implemented ticket text verbatim without reviewing existing implementation, enumerating edge cases, or flagging significant logic changes.

`implement-from-ticket.md` Phase 2 (Plan) expanded from one 5-line step into four mandatory sub-steps with a "tickets are not the whole truth" preamble:

- **2.1 Existing implementation review** — for each area the ticket would touch, read current code, summarize behavior in the plan, flag pre-existing bugs / conflicts. STOP if the ticket conflicts with existing behavior.
- **2.2 Edge case enumeration** — empty / null / missing inputs, boundary values, error paths, concurrency, backwards-compatibility. List each with intended handling (`handled` / `not applicable` / `out of scope — flagged`). STOP if the ticket has no acceptance criteria — comment on Jira asking for them.
- **2.3 Significant-change gate** — if the planned change alters >30 lines of existing logic, removes a documented behavior, changes a public API signature, or touches `SACRED.md`, write `SIGNIFICANT CHANGE: <description>` in the plan. Initial plan approval does **not** authorize significant changes — they require a **separate explicit confirmation** ("Confirming the significant change to `<X>` — proceed?"). Intentional friction.
- **2.4 Draft and present the plan** — includes existing-impl summary, edge case list, SIGNIFICANT CHANGE rows, architecture survey result (from Fix 1), commit granularity (from Fix 2).

This is the highest-impact fix — ticket-driven workflows are where most production-affecting agent work happens.

**Files touched:** ~25 (3 workflows + 1 skill + 6 canonical/inline rule files + 5 templates + 5 installed copies + validator + version markers + memory).

affected: develop-feature, implement-task, implement-from-ticket, git-flow, developer, core-behavior

## v1.64.0 — 2026-06-07

### Three new behavior rules: Fast Execution Mode + PR-link presentation + mandatory post-merge cleanup

User-requested. Encoded across `core-behavior.md` (both source + Claude-rules copy), `git-flow` skill, and `CONFIG.md` template.

**Fast Execution Mode (new toggle).** `.memory/CONFIG.md` gains a `Fast Execution Mode` field (default `off`). When `on`, the agent skips the branch + PR ceremony and commits / pushes directly to `[Default Branch]`. Everything else stays: plan-first approval, task-completion checklist (CHANGELOG/TIME_LOG/RESUME/memory commit), validator, sacred-behaviors check. Surfaces a `FAST MODE ACTIVE — committing directly to <branch> (no PR).` banner before any commit so ceremony-skipping is visible.

- Persistent toggle: edit the CONFIG field.
- One-shot: prefix a request with `fast:` (e.g. `fast: bump dep X`) — flag stays off, just that one task is fast.
- Refusal cases: change touches `.agents/`/`core/`/`roles/`/skills/workflows/rules logic, sacred behaviors, >~3 files, or non-trivial logic → agent says `Refusing fast mode — change touches X; switching to full flow.` and falls back to normal flow.

The `git-flow` skill gains a `Fast Mode Bypass` section with the procedure and refusal heuristics.

**PR-link presentation rule.** When a turn opens multiple PRs (common: memory branch + main branch), each URL goes on its own line in the end-of-turn summary, format `PR #N: <url>`. No comma-separated inline lists. The user needs to click each one independently.

**Mandatory post-merge cleanup.** Strengthens the existing `git-flow` Post-Merge Cleanup section: when the user confirms a merge ("merged", "done", or equivalent), the cleanup procedure (checkout default, pull, `git branch -d`, `git remote prune`, RESUME update) is non-optional and runs BEFORE any next task. New gate: do not begin the next task until `git branch -a` is clean (only default + legitimate long-lived branches like `ai-memory`).

**Self-sync:** rule added to both `core/rules/core-behavior.md` and `core/claude-rules/core-behavior.md` so Claude Code's native auto-load picks it up. CONFIG.md template gets the field; agentskel's own `.memory/CONFIG.md` backfilled. git-flow skill copied to `.agents/`.

**Cross-tool propagation (gap fix).** The three rules above were initially landed in only two places (`core/rules/core-behavior.md` + `.claude/rules/core-behavior.md`). Audit caught the gap: 5 other tool integrations carry their own inline rule files that wouldn't have seen the new rules — same drift class as the v1.61.0/v1.62.0 stub regeneration issue.

Updated all 5 inline-rule templates + their installed copies:

- `core/AGENTS.md.template` + `AGENTS.md` (Codex/universal entry point)
- `core/GEMINI.md.template` + `GEMINI.md` (Gemini CLI / Antigravity)
- `core/cursor-rule.mdc.template` + `.cursor/rules/agentskel.mdc`
- `core/windsurf-rule.md.template` + `.windsurf/rules/agentskel.md`
- `core/copilot-instructions.md.template` + `.github/copilot-instructions.md`

Condensed rules added as a `## Git Discipline` section in the four condensed templates (Gemini/Cursor/Windsurf/Copilot). `AGENTS.md.template` got the rules appended as bullets under the existing `Core Behavior (always active)` block.

**Validator hardening.** New check `inline rules propagation` in `scripts/validate.py` (now 11 checks, 482 ok). Verifies that each v1.64.0 git-discipline rule fingerprint (`Fast Execution Mode`, `PR URL on its own line`, `Post-merge cleanup is mandatory`) appears in all 10 inline-rule files. Coarse but catches the "forgot to propagate" class going forward — when a future rule joins the propagation guard, append its phrase to `REQUIRED_PHRASES`.

affected: core-behavior, git-flow, AGENTS.md template + 4 tool-specific rule templates, validator

## v1.63.2 — 2026-06-07

### Fix: 3 silent bugs caught by code-review bot on the Muslim-Pro-Android v1.63.1 sync PR

Code-review bot reviewing the downstream sync PR ([bitsmedia/Muslim-Pro-Android#5296](https://github.com/bitsmedia/Muslim-Pro-Android/pull/5296)) found three bugs that have been latent in shipped agentskel hook scripts and one workflow.

**Bug A — Skeleton-only check regex misfires on every downstream**

`pre-commit-check.sh` had this regex to gate skeleton-only checks (VERSION ↔ README ↔ MASTER_PLAN consistency):

```
grep -q 'Skeleton Path.*\.' .memory/CONFIG.md
```

The `\.` in the regex matched ANY dot anywhere after "Skeleton Path" on the line. So `| Skeleton Path | ../agentskel |`, `| Skeleton Path | ~/.agentskel/skeleton |`, `| Skeleton Path | ./agentskel |` ALL matched — meaning every downstream project triggered the skeleton-only checks. Downstream projects don't have agentskel's README/MASTER_PLAN version markers at the project root, so the checks would always fail to find the version, causing… silent confusion at best.

Fix: strict regex anchored on the markdown table row with literal `.` value:

```
grep -qE '^\|[[:space:]]+Skeleton Path[[:space:]]+\|[[:space:]]+\.[[:space:]]+\|' .memory/CONFIG.md
```

Test matrix (verified): `.` → match; `../agentskel`, `~/.agentskel/skeleton`, `./agentskel`, `/abs/path`, optional-placeholder → no match.

**Bug B — Commit message text triggers structural skip-clauses**

Two skip-clauses grep'd the full bash command line for sentinel substrings:

- `grep -q '\.memory'` (intent: skip when committing inside `.memory/`) — but `git commit -m "fix .memory mount issue"` ALSO matched, bypassing enforcement.
- `grep -qE '\-\-amend|merge'` (intent: skip amends and merges) — but `git commit -m "implement merge logic"` matched on "merge", and `git commit -m "--amend was needed"` matched on "--amend".

Innocuous commit messages silently bypassed CHANGELOG/TIME_LOG enforcement.

Fix: strip `-m "..."` / `-m '...'` / `--message "..."` / `--message '...'` from the command via sed before the structural checks. Patterns are then tightened to require the right syntactic context (`cd .memory`, `git -C .memory`, `--amend` as a flag, `git merge` as a command). Verified with 10 test cases including all false positives.

**Bug C — `create-blueprint` Final Step contradicts the workflow's own architecture**

`roles/dev/workflows/create-blueprint.md` Steps 5/6 + Notes explicitly establish: "The blueprint has no ai-memory branch. All persistent agent state lives in each project's own `.memory/`." But the Final Step then instructed the agent to update `RESUME.md`, `TIME_LOG.md`, `SYMBOLS.md`, `MAP.md` — files that don't exist in a blueprint repo. Self-contradiction.

Fix: Final Step now disambiguates that memory updates target the **calling project's** `.memory/`, not the blueprint's. The blueprint itself only gets the files created during the workflow (specs, CHANGELOG.md, etc., which are regular files not memory).

**Scope**

- Bug A + B fixed in all 4 hook scripts: `core/{claude,gemini,cursor,windsurf}-hooks/pre-commit-check.sh`. Self-synced to `.claude/hooks/`.
- Bug C fixed in `roles/dev/workflows/create-blueprint.md`. Self-synced to `.agents/workflows/`.

**Tests**

Both regex/strip fixes verified empirically before commit. 472 ok, 0 fail on validator (no parity check covers hook script semantics, so the tests were inline shell test cases — recorded in the commit).

affected: create-blueprint

## v1.63.1 — 2026-06-07

### Doc: sync-skeleton gains CONFIG.md field-add enumeration + AI tool restart hint

Two minor doc gaps from the self-audit of downstream-migration coverage. Both improve sync-skeleton's user-facing guidance without changing any logic.

**Step 5 (memory update) — enumerate historical CONFIG.md field additions.** Old text said "Apply any memory file template updates" — vague. Downstream projects on older skeleton versions had no way to know v1.49.0 added Atlassian fields, v1.57.0 added External Platform Skills fields, etc. Step 5 now explicitly tells the agent to diff the project's CONFIG.md against the template, with a hint list of historical additions (v1.22 Supported Tools, v1.23 Last Skeleton Check, v1.49.0 Atlassian section, v1.57.0 External Platform Skills + Last External Skills Check).

**Step 8 (session reload) — restart-required tools.** Previous text told the agent to re-execute session-start. That picks up skill/rule/workflow changes (most tools watch those dirs). But hook config changes (`.cursor/hooks.json`, `.windsurf/hooks.json`, `.gemini/settings.json`, `.claude/settings.json`, `.codex/hooks.json`) are loaded once at session start and don't reload live. Sync-skeleton now explicitly says: if the sync touched any hook config, tell the user to restart their AI tool. Per-tool restart behavior documented inline.

affected: sync-skeleton

## v1.63.0 — 2026-06-07

### Cartography refresh: MAP.md + SYMBOLS.md after the v1.60–v1.62.x cross-tool work

Memory-only refresh. No code or workflow changes. Three releases of structural work compounded into cartography drift; this brings MAP.md, SYMBOLS.md, and RESUME.md Cartography State back in sync with the actual repo.

**MAP.md**
- Architecture pattern section: replaced single-line "Entry points: CLAUDE.md / GEMINI.md / .agent symlink" with explicit per-tool entry-point list covering every supported AI tool (Claude, Gemini, Cursor, Windsurf, Copilot, Codex). Each tool's native files are enumerated.
- `.agent` symlink documented as **legacy compat path** (Gemini docs only mention `.agents/` plural; symlink is harmless and stays for any older installs that may still reference it).
- Module registry now reflects v1.60–v1.62.x reality:
  - `core/cursor-hooks/`: 5 files (4 Cursor-format scripts + hooks.json) — was 1
  - `core/gemini-hooks/`: **new directory** in v1.61.0 (4 scripts + settings.json)
  - `core/windsurf-hooks/`: 5 files (4 Windsurf-format scripts + hooks.json) — was 1
  - `core/codex-hooks/`: 1 file (hooks.json; scripts sourced from core/claude-hooks/, verified compatible)
  - `core/copilot-hooks/`: **DELETED in v1.62.0** (Copilot has no hooks concept)
  - `.gemini/skills/`: new (50 stubs, v1.61.0)
  - `.cursor/rules/`: 51 .mdc files (1 always-on `agentskel.mdc` + 50 per-name with `alwaysApply: false`, v1.62.0)
  - `.cursor/hooks.json`: moved from `.cursor/hooks/hooks-cursor.json` (v1.62.0)
  - `.windsurf/workflows/`: new (33 files, v1.62.0)
  - `.github/prompts/`: new (33 prompt files, v1.62.0)
  - `.claude/skills/`: now directory layout `<name>/SKILL.md` (v1.60.0)
- `scripts/`: validate.py grown to 10 deterministic checks (was 5).
- New top-level entry: `gemini-extension.json`.

**SYMBOLS.md** — scripts/validate.py updates:
- Removed: `check_stub_parity` (refactored away in v1.62.0).
- Added: `_stub_parity_for`, `_flat_stub_parity` (helpers), `check_claude_stub_parity`, `check_gemini_stub_parity`, `check_cursor_rule_parity`, `check_windsurf_workflow_parity`, `check_copilot_prompt_parity`.

**RESUME.md Cartography State** — HEAD SHA + counts refreshed. Coverage target jumped from ~262 to ~430 source files (per-tool stub/workflow/prompt generation across 5 releases).

**Out of scope**
- `.agent` singular symlink cleanup: decided to keep (harmless, no signal it's truly unused; risk of breaking older installs).
- Full per-file re-index via cartographer workflow: surgical refresh is sufficient for the current state.

affected: none (memory-only — no workflows/skills touched)

## v1.62.2 — 2026-06-07

### Fix: Windsurf hook scripts had wrong I/O contract (silent allow on every commit/push)

Continuing the v1.62.1 self-audit. Verified Windsurf and Codex hook I/O contracts against current docs (deferred item from v1.62.0).

**Windsurf — silent bug found and fixed**

The pre-v1.62.2 install copied scripts from `core/claude-hooks/` to `.windsurf/hooks/`. Claude's scripts read the command from `tool_input.command` on stdin — but **Windsurf nests it as `tool_info.command_line`**. Result: the `COMMAND` variable in every Windsurf install was always empty, and `pre-commit-check.sh` / `pre-memory-push.sh` silently allowed every git commit and ai-memory push regardless of state. This bug has been live since whenever Windsurf hooks were first shipped.

Per Windsurf's docs (https://docs.devin.ai/desktop/cascade/hooks):
- stdin: JSON with `agent_action_name` + `tool_info` (event-specific keys: `command_line` for `pre_run_command`, `file_path` for `pre_write_code`)
- stdout: informational (UI display when `show_output: true`)
- stderr: error / rejection reason
- exit codes: 0 = allow, 2 = block (**pre-hooks only**), other = error → action proceeds

Fix:
- 4 new Windsurf-format scripts in `core/windsurf-hooks/` (pre-commit-check, pre-memory-push, pre-edit-check, stop-verify) that read `tool_info.command_line` / `tool_info.file_path` from stdin.
- New `pre_write_code` event wired in `core/windsurf-hooks/hooks.json` (plan-gate reminder — matches the other tools' coverage).
- `stop-verify.sh` adjusted: `post_cascade_response` is a post-event, so it cannot block (exit 2 is pre-hooks only per docs). Warnings go to stderr, script exits 0.
- setup-skeleton install steps source from `core/windsurf-hooks/` (was `core/claude-hooks/`).
- sync-skeleton gains a v1.62.2 migration block: force-overwrite the four scripts in `.windsurf/hooks/` from the new location.

**Codex — verified, no changes needed**

Per Codex docs (https://developers.openai.com/codex/hooks): stdin JSON uses `tool_input.command` — same key as Claude. Exit codes and matchers match too. Sourcing `.codex/hooks/` scripts from `core/claude-hooks/` is intentional and supported. setup-skeleton text updated to reflect this is verified, not just an assumption.

**Validator** — no new checks. 471 ok, 0 fail (unchanged from v1.62.1; new scripts add no new validations).

affected: setup-skeleton, sync-skeleton

## v1.62.1 — 2026-06-07

### Fix: plugin manifest version drift + setup-skeleton clarity

Self-audit of the v1.60.0 / v1.61.0 / v1.62.0 release series surfaced three issues:

- **Plugin manifest versions stale.** v1.61.0 bumped `gemini-extension.json` and `.claude-plugin/plugin.json` to 1.61.0, but v1.62.0 missed bumping them to 1.62.0. Users running `gemini extensions install` or `/plugin install agentskel` would have seen 1.61.0 even though the repo was on 1.62.0. Bumped both to 1.62.1.
- **Validator didn't catch the drift.** `check_version_consistency` covered README, MASTER_PLAN, and `.memory/CONFIG.md` but not the plugin manifests — which is why the v1.62.0 drift went unnoticed. Extended the check to cover both manifest files. Verified the validator catches the bug by running it against the pre-fix state: it correctly flagged both manifests as `1.61.0 != VERSION 1.62.0` (regression-test in spirit).
- **setup-skeleton hook-install text was ambiguous.** Windsurf and Codex install steps said "Copy the same 3 hook scripts to `.windsurf/hooks/`" — the reader had to scroll up to figure out which scripts. Replaced with explicit `[SKELETON_PATH]/core/claude-hooks/` source paths + per-script destinations. Also added an honest note that Windsurf and Codex hook I/O contracts haven't been formally verified to match Claude's; if either differs (like Cursor turned out to), those scripts may not block correctly — a `v1.62.x` audit will verify and write tool-specific scripts if needed.

affected: setup-skeleton

## v1.62.0 — 2026-06-07

### Cross-tool discoverability + dead-code cleanup for Cursor, Windsurf, Copilot

Completes the cross-tool parity series begun with v1.60.0 (Claude) and v1.61.0 (Gemini). Audited Cursor, Windsurf, Copilot, and Codex against current docs. Codex needed no changes; the other three each had a mix of silently broken artifacts and missing first-class discoverability.

**Cursor — 3 major fixes + workflow discoverability**
- **Hooks were silently inactive on every Cursor install since v1.22.** We installed `.cursor/hooks/hooks-cursor.json`; Cursor reads `.cursor/hooks.json` at workspace root. Renamed the source, changed setup-skeleton to install to the correct path, added v1.62.0 migration to sync-skeleton.
- Matcher syntax in the old file used invented `"shell(git commit*)"` — replaced with regex matchers per Cursor's spec. Hook events changed from generic `preToolUse` to `beforeShellExecution` for shell commands.
- Removed the `sessionStart` reference that pointed at `./hooks/session-start`, a script we never shipped.
- Replaced Claude-format scripts (which Cursor would have silently ignored, since Cursor's I/O contract is `command` at the top of stdin JSON and `{permission,user_message,agent_message}` JSON out) with 4 Cursor-format scripts in `core/cursor-hooks/`.
- Generated 50 per-file `.cursor/rules/<name>.mdc` with `alwaysApply: false` so each skill/workflow is agent-requested-discoverable. Existing always-on `agentskel.mdc` stays for core rules.

**Windsurf — 1 major fix + workflow discoverability**
- **`stop` hook was a silent no-op** — Windsurf has no `stop` event. Replaced with `post_cascade_response` per docs.
- Generated 33 first-class `.windsurf/workflows/<name>.md` files — slash-invokable as `/<name>`. Before, workflows were buried in one always-on rule with no slash binding.

**Copilot — major dead-code removal + slash prompts**
- **`core/copilot-hooks/` and `.github/hooks/` were silently dead** — GitHub Copilot has no hooks concept. Deleted source directory; setup-skeleton no longer installs Copilot hook artifacts.
- Generated 33 `.github/prompts/<name>.prompt.md` slash-invokable prompts.

**Codex** — verified `core/codex-hooks/hooks.json` event names (`PreToolUse`, `Stop`) and matcher syntax match the spec. No changes needed.

**Validator** — three new checks: `cursor rule parity`, `windsurf workflow parity`, `copilot prompt parity`. Common logic factored into `_flat_stub_parity()`. 470 ok, 0 fail at v1.62.0 (was 354).

**Downstream migration** — `sync-skeleton` Step 4c gains explicit v1.62.0 migration: rename Cursor hooks file via `git mv`, re-copy scripts from `core/cursor-hooks/` (pre-v1.62.0 sourced from `core/claude-hooks/`), fix Windsurf `stop` → `post_cascade_response`, `git rm -rf .github/hooks/`. Migrations show as renames/deletes in the sync PR.

affected: setup-skeleton, sync-skeleton

## v1.61.0 — 2026-06-07

### Gemini CLI / Antigravity parity bundle

Follow-up to v1.60.0's Claude Code fix. Audited agentskel's integration against the current Gemini CLI spec (`docs.code.claude.com` style ref at `github.com/google-gemini/gemini-cli/docs/`) and closed three gaps in one bundle.

**Item 1 — Workflow discoverability as Gemini skills**

Gemini auto-discovers skills from `.gemini/skills/<name>/SKILL.md` (and `.agents/skills/` as an interop alias). agentskel's first-party skills in `.agents/skills/` are picked up via the alias, but the 33 workflows in `.agents/workflows/` are not on Gemini's discovery path. Generated 50 stubs in `.gemini/skills/<name>/SKILL.md` so every workflow and skill is discoverable, gets a `/<name>` slash-command auto-binding, and supports progressive disclosure / `/skills disable|enable`. `setup-skeleton` Step 5b1 (new) and `sync-skeleton` Step 4c (extended) generate / refresh these for Gemini installs. Validator gains a `gemini stub parity` check that mirrors `claude stub parity`.

**Item 2 — Real Gemini extension manifest**

`gemini-extension.json` already existed at repo root but was pinned to v1.26.0 (stale by 35 releases). Bumped to v1.61.0 and clarified the description to set expectations: `gemini extensions install https://github.com/ahmadulhoq/agentskel` now loads agentskel's `GEMINI.md` as global context; full per-project install still goes through `setup-skeleton`. Also bumped `.claude-plugin/plugin.json` from 1.26.0 → 1.61.0 to match.

**Item 3 — Gemini-format enforcement hooks**

New `core/gemini-hooks/` with four hook scripts that mirror Claude's enforcement layer but follow Gemini's strict JSON I/O contract (stdin = JSON event payload; stdout = JSON-only decision; stderr = rejection reason on exit 2; "Silence is Mandatory"):

- `pre-commit-check.sh` — `BeforeTool` on `run_shell_command`, blocks git commit if CHANGELOG/TIME_LOG missing, lints multi-line YAML in staged skill/workflow files
- `pre-memory-push.sh` — `BeforeTool` on `run_shell_command`, auto-pulls --rebase before ai-memory push (skips when remote tip is already an ancestor or remote doesn't exist)
- `pre-edit-check.sh` — `BeforeTool` on `replace`/`write_file`, emits plan-gate reminder as `systemMessage` (advisory, allows)
- `stop-verify.sh` — `AfterAgent`, blocks stop if uncommitted project or `.memory/` changes remain (sets `decision:"deny"` so the model addresses it rather than silently stopping)

Wired via `core/gemini-hooks/settings.json` (project-level template). `setup-skeleton` Step 5b3 extended with a Gemini install block; `sync-skeleton` Step 4c table now lists Gemini alongside the other tools.

**Why bundle:** all three are Gemini-side parity work. Each was researched against current Gemini CLI docs; none required guesses. Bundling keeps the review surface coherent and downstream sync to one PR.

**Out of scope (future):**
- Bundling skills in the Gemini extension itself (currently extension only ships `GEMINI.md` context; skills come from per-project install)
- `.agent` singular symlink deprecation — Gemini docs only mention `.agents/` but legacy installs may still rely on it; leave as-is until a Gemini-only team confirms it's safe to drop

affected: setup-skeleton, sync-skeleton

## v1.60.0 — 2026-06-06

### Fix: Claude Code skill discovery — migrate stubs from flat to directory layout

**Root cause of "Claude misses all workflows."** Every project-level `.claude/skills/<name>.md` (flat file) was silently ignored by Claude Code's skill loader. Claude Code's spec requires the directory layout `.claude/skills/<name>/SKILL.md`. agentskel has shipped the flat layout since v1.26 (March 2026) — every Claude session in every downstream project has been blind to agentskel's skills and workflows for ~3 months.

**Diagnosis:** HelpDesk transcript audit (12,639 lines, 33 implementation prompts, ~5 sessions): 0 session-start runs, 1 task-completion run, 0 develop-feature / implement-task / debug-issue invocations. Compared against expected workflow routing — totally missed. Empirically confirmed by creating one test skill in the correct directory layout and watching it appear in `available-skills` immediately (live discovery works); flat files do not.

**What changed:**
- All 50 skeleton stubs migrated from `.claude/skills/<name>.md` to `.claude/skills/<name>/SKILL.md` (mechanical rename, content unchanged).
- `setup-skeleton` Step 5b now writes stubs in directory layout.
- `sync-skeleton` Step 4c gains a pre-step that auto-migrates pre-v1.60.0 flat stubs in downstream projects (uses `git mv` so the rename appears in the PR diff).
- `scripts/validate.py` `check_stub_parity` updated for the new layout and explicitly flags any legacy flat files as a parity failure so they don't silently regress.

**Side benefit:** with skills now properly discoverable, Claude Code auto-binds each to a slash command — `/debug-issue`, `/develop-feature`, `/session-start`, etc. all become invokable without further work. CSO description matching also works, so "fix this bug" can auto-trigger debug-issue.

**Out of scope (future PATCHes):** auto-firing `session-start` via the `SessionStart` hook event (v1.60.1 candidate); strengthening Stop hook to actually enforce `task-completion` (v1.60.2 candidate). Skill layout fix alone covers discoverability; auto-invocation at session start and post-task is a separate concern.

affected: setup-skeleton, sync-skeleton

## v1.59.2 — 2026-06-03

### Fix: suppress misleading `fatal:` git stderr in install-agent.sh and sync-skeleton self-update
- `scripts/install-agent.sh` and `sync-skeleton` Step 0 ran `git pull` without redirecting stderr. When the pull failed for any reason (no network, no remote, stale worktree), git printed `fatal: …` to the user's screen — alarming, because the script handles the failure cleanly with a friendly "Warning — continuing" message immediately after. Surfaced by v1.59.1 dogfood test in a sandbox without `origin`.
- Both call sites now redirect stderr to `/dev/null`, matching the pattern already used in `session-start` and `pre-memory-push.sh`. The `||` fallback continues to print the agentskel-friendly warning.
- `setup-skeleton` Step 1 instruction text updated to match.
- affected: setup-skeleton, sync-skeleton

## v1.59.1 — 2026-06-03

### Fix: external skill symlinks auto-link on session-start (no manual `install-agent.sh`)
- After a sync that introduced new external skill entries (v1.58.0+ shared
  store), teammates pulling the merged sync had to remember to run
  `scripts/install-agent.sh` to materialise the gitignored symlinks. The
  agent's first session post-pull would silently miss the external skills.
- New `session-start` Step 1b detects manifest entries in
  `.agents/skills/.gitignore` that have no matching symlink, runs
  `install-agent.sh` once (idempotent), and surfaces any "shared store
  missing pack" warnings the script prints. Offers to run
  `update-external-skills` if a pack needs installing.
- `sync-skeleton` Step 7 PR body template now includes an "After merge —
  for teammates pulling this branch" section explaining the auto-link
  behavior. Replaces the misleading ad-hoc "symlinks point at non-existent
  dir" wording that surfaced during a recent sync.
- affected: session-start, sync-skeleton

## v1.59.0 — 2026-05-31

### Canonical skeleton location (~/.agentskel/skeleton/)

setup-skeleton and sync-skeleton now auto-resolve and auto-update the skeleton
source — no "where is your agentskel clone?" prompt.

- **Resolution order** (both workflows): (1) `Skeleton Path` in CONFIG.md;
  (2) `$CLAUDE_PLUGIN_ROOT`; (3) `~/.agentskel/skeleton/`; (4) `../agentskel`
  legacy probe; (5) not found → auto-clone to `~/.agentskel/skeleton/`.
- **Auto-pull**: once resolved to `~/.agentskel/skeleton/`, runs
  `git pull --ff-only origin main` before reading — skeleton is always fresh.
  Pull failure warns and proceeds with local copy (same pattern as install-agent.sh).
- **Existing setups unaffected**: `Skeleton Path` in CONFIG.md takes precedence;
  custom clone paths keep working as-is.
- **README**: updated Manual Install section to document `~/.agentskel/skeleton/`
  as the canonical path with migration note for existing clones.
affected: setup-skeleton, sync-skeleton

## v1.58.0 — 2026-05-31

### Shared external skills store (~/.agentskel/)

External skill packs now install to a machine-level shared store at
`~/.agentskel/skills/` instead of directly into each project. Projects get
gitignored symlinks in `.agents/skills/` — one update refreshes all projects
on the machine simultaneously.

- **`core/external-skills.yml`** (new) — machine-readable pack registry. Each entry
  declares `id`, `name`, `author_tag`, `platform_match`, `install_cmd`, `clone_url`,
  `description`, and `license`. Adding a new pack requires only a manifest entry —
  no workflow changes needed.
- **`~/.agentskel/`** — machine-level agent workspace. `skills/` is the first
  subdirectory; structure accommodates future `workflows/`, `integrations/`, `memory/`.
- **`roles/dev/workflows/update-external-skills.md`** (new) — dedicated workflow to
  refresh shared store, verify install via author-tag scan, recreate broken symlinks,
  regenerate stubs + AGENTS.md catalog, and update CONFIG timestamps.
- **`roles/dev/workflows/setup-skeleton.md`** Step 9c — install target changed to
  `~/.agentskel/skills/[pack.id]/`; creates gitignored symlinks in `.agents/skills/`;
  reads pack details from manifest rather than hardcoded Android logic.
- **`roles/dev/workflows/sync-skeleton.md`** Step 4d — staleness check and
  re-suggestion now delegate to `update-external-skills` instead of inline logic.
- **`scripts/install-agent.sh`** — new section reads `.agents/skills/.gitignore` to
  discover external skills, finds them in `~/.agentskel/skills/`, and recreates
  symlinks. If shared store is missing, prints instructions and names missing skills.
- **`docs/PLATFORM-SKILLS.md`** — rewritten to explain shared-store architecture,
  symlink model, manual install commands targeting `~/.agentskel/skills/`, and how
  to add new packs via the manifest.
affected: setup-skeleton, sync-skeleton, update-external-skills

## v1.57.3 — 2026-05-31

### Fix: setup-skeleton Step 9c install verification gate
- Tightens the install outcome wording in `setup-skeleton` Step 9c. The
  previous text said "If found, set flag to `installed`" — implicitly
  leaving "not found" undefined. Agents could (and in dogfood testing did)
  set the flag eagerly without verifying the filesystem scan returned any
  Google LLC author SKILL.md files.
- New wording is explicit: on scan miss, DO NOT set flag, report to user
  with scan output, stop. Bug surfaced by E2E test against a downstream
  Android install — flag was `installed` but no SKILL.md files were
  present, only orphan `references/` subdirectories from a partial clone.
- `sync-skeleton` Step 4d's reconcile logic was already correct (scan miss
  + flag `installed` → reset to `(empty)`) so any in-the-wild bogus
  `installed` flags self-correct on next sync.
affected: setup-skeleton

## v1.57.2 — 2026-05-21

Fix two setup-skeleton bugs introduced or exposed in v1.57.0.

- `roles/dev/workflows/setup-skeleton.md`, `.agents/workflows/setup-skeleton.md`:
  **Fix 1 — Step 9c ordering:** Steps 9b and 9c (workspace registration and platform
  skills) restructured as subsections inside Step 9, placed before the git commit
  block. Previously Step 9c ran after `git checkout [DEFAULT_BRANCH]`, causing the
  agent to switch back to `chore/setup-skeleton` to commit regenerated stubs/AGENTS.md
  — leaving the worktree on the setup branch and blocking later branch deletion.
  **Fix 2 — ai-memory as default branch:** After `git push origin ai-memory` in Step 3,
  `gh repo edit [GITHUB_SLUG] --default-branch [DEFAULT_BRANCH]` now explicitly pins
  the GitHub default branch (brand-new repos take the first-pushed branch as default).
  Verification gate added after `git checkout [DEFAULT_BRANCH]` in both Step 3 and
  the new Step 9 commit section.
affected: setup-skeleton

## v1.57.0 — 2026-05-21

### External platform skills — Android (reference, don't vendor)

agentskel covers cross-platform agent behavior; platform-specific deep skills
come from canonical external sources. First entry: Google's
[android/skills](https://github.com/android/skills) (open agentskills.io
standard, Apache-2.0, installs to `.agents/skills/` — same path we use).

- **`docs/PLATFORM-SKILLS.md`** (new) — Android section, install + update
  guidance, scope note. iOS / web / KMP placeholders for future entries.
- **`setup-skeleton` Step 9c** (new) — for Android projects, suggests
  `android skills add --all --project=.` (or manual clone fallback) if not
  already installed and not previously declined. Three-option prompt
  (install / ask again / decline). Outcome recorded in CONFIG.md.
- **`sync-skeleton` Step 4d** (new) — every sync re-checks: re-suggests
  install if `(empty)`, reminds to refresh when `Last External Skills Check`
  is >=30 days old, stays silent for `declined` and recent `installed`.
- **`core/memory/CONFIG.md` template** — new fields:
  `External Platform Skills` (`(empty)`/`installed`/`declined`),
  `Last External Skills Check` (timestamp).
- **`developer/SKILL.md` Android section** — pointer to PLATFORM-SKILLS.md.

### Validator — third-party skill awareness

`scripts/validate.py` now distinguishes first-party skills/workflows (those
with sources in `core/` or `roles/`) from third-party ones present only in
`.agents/`. Parity checks (stub parity, AGENTS.md catalog parity) skip
third-party entries — they're outside agentskel's parity contract. Without
this change, downstream projects that installed Android skills would have
seen the validator fail on every Android skill stub.

## v1.56.1 — 2026-05-17

Fix stop-verify.sh false positive on RESUME.md.

- `core/claude-hooks/stop-verify.sh`, `.claude/hooks/stop-verify.sh`: exclude
  `RESUME.md` from the `.memory/` dirty check. RESUME.md is intentionally
  local-only and never committed to ai-memory — the hook was incorrectly blocking
  every session end when RESUME.md had any modifications.

## v1.56.0 — 2026-05-17

Option D: behavioral enforcement + advisory Edit/Write hook for plan-first gate.

- `core/rules/core-behavior.md`, `core/claude-rules/core-behavior.md`,
  `.claude/rules/core-behavior.md`, `.agents/rules/core-behavior.md`:
  "Plan first" moved to position 1 in "How You Work". New rule added at position 2:
  "Never modify files without explicit approval — verify go-ahead in *current exchange*
  before calling Edit or Write. Urgency is not an exception."
- `core/condensed-rules.md`: Added "Never Modify Files Without Explicit Approval"
  section for tight-character-limit tools (Cursor, Windsurf).
- `core/claude-hooks/pre-edit-check.sh` (new), `.claude/hooks/pre-edit-check.sh` (new):
  Advisory hook — prints plan-gate reminder to stdout and exits 0 (non-blocking).
  Fires before every Edit and Write tool call.
- `core/claude-hooks/settings.json`, `.claude/settings.json`: Added PreToolUse matchers
  for "Edit" and "Write" pointing to `pre-edit-check.sh`.
- `.memory/LESSONS.md` Lesson 006: Extended with specific trigger — Edit/Write tool
  call is the exact moment the gate must be checked; prior approval does not carry
  forward across exchanges.
- `MASTER_PLAN.md` point 11: Updated to describe the new advisory hook mechanism.

## v1.55.4 — 2026-05-17

Replace broken Stop hook with deterministic shell script.

- `core/claude-hooks/stop-verify.sh` (new): checks for uncommitted project
  or `.memory/` changes before the agent finishes. Exits 0 (allow) or 2
  (block with message). No conversational response — no loop.
- `settings.json` (core + installed): Stop hook changed from `"type": "prompt"`
  (caused infinite loop) to `"type": "command"` pointing to `stop-verify.sh`.
- `sync-skeleton` must install `stop-verify.sh` to `.claude/hooks/` on sync
  (Step 4c hook refresh already handles this).
- Added LESSONS.md entry 006: plan-first applies even to urgent-seeming bugs.

## v1.55.3 — 2026-05-17

- Remove Stop hook `"type": "prompt"` from `settings.json` (core + installed). Root
  cause of infinite loop: prompt-type Stop hook injects a message → Claude responds
  → triggers Stop again → repeats forever. Pre-commit hook already enforces
  CHANGELOG/TIME_LOG at commit time — Stop hook was redundant and broken.
- Fix v1.55.2 missing `affected: task-completion` in both CHANGELOG files.

## v1.55.2 — 2026-05-17

Fix: add precision rule to `affected:` checklist — only include a workflow/skill
name if its file was directly modified, not merely mentioned in prose.
Caught by dogfooding the triage feature (v1.55.1 removed the false positive;
this hardens the rule to prevent recurrence).

affected: task-completion

## v1.55.1 — 2026-05-17

Fix false positive: removed `skill-authoring` from v1.55.0 `affected:` line.
No skill-authoring files were modified in v1.55.0 — the entry was written too broadly.

## v1.55.0 — 2026-05-17

### Post-sync workflow/skill triage via `affected:` field

Downstream projects now learn which workflows and skills were updated after
a skeleton sync, and agents re-read any that are currently active.

- **`affected:` field in CHANGELOG:** skeleton CHANGELOG entries that touch any
  workflow or skill file must now include `affected: name, name, ...` at the end
  of the entry. Machine-read by sync-skeleton; omitted for non-workflow/skill changes.
- **skeleton-contribution-checklist:** new `CHANGELOG affected: line` section
  documents the rule and the machine-read contract.
- **task-completion SKILL.md Step 1:** inline reminder to write `affected:` for
  skeleton repo changes.
- **sync-skeleton Step 4d:** after applying files, collects all `affected:` values
  from applied CHANGELOG entries and writes `SYNC PENDING TRIAGE: [names]` to
  RESUME.md Session Notes.
- **sync-skeleton Final Step:** post-sync triage — checks each name against active
  session state; re-reads active workflows/skills with new version, surfaces
  non-active ones to user, then clears the triage entry.
- **Backfilled:** `affected:` added to v1.54.2 CHANGELOG entry retroactively.

affected: sync-skeleton, task-completion

## v1.55.1 — 2026-05-17

Fix false positive: removed `skill-authoring` from v1.55.0 `affected:` line.
No skill-authoring files were modified in v1.55.0 — the entry was written too broadly.

## v1.54.2 — 2026-05-17

### Workflow plan gate strengthening

Closes the "concerns ≠ plan" rationalization loophole observed in downstream projects.
Agents were listing concerns/tradeoffs and then proceeding to implement without waiting
for explicit approval — the existing gate text ("wait for approval") was too vague.

- **develop-feature, implement-task, fix-tech-debt, refactor-code:** Strengthened the
  plan presentation step with an explicit definition: a plan must state (1) proposed
  approach, (2) files to modify, (3) open decision points. Concerns and tradeoffs alone
  are not a plan.
- **debug-issue:** Added a missing approval gate (step 10b) between Phase 3 (Root Cause
  Isolation) and Phase 4 (Fix). Previously had no gate — agent could go straight from
  root cause confirmation to writing code.
- 10 files changed (5 source workflows in `roles/dev/workflows/` + 5 `.agents/` copies).

affected: develop-feature, implement-task, fix-tech-debt, refactor-code, debug-issue

## v1.54.1 — 2026-05-16

### agentskills.io standard compliance — Gaps 1, 2, 4: license, compatibility, references/

- **Gap 1 (license):** Added `license: MIT` to all 17 source + 17 `.agents/` SKILL.md
  files (34 total). Matches repo root LICENSE.
- **Gap 2 (compatibility):** Added `compatibility: Designed for Claude Code.` to
  `skill-authoring` only — the one skill whose body explicitly references `.claude/`
  paths. Other skills omitted per spec guidance (include only if skill has specific
  env requirements).
- **Gap 4 (references/):** Moved `task-completion/skeleton-contribution-checklist.md`
  to `task-completion/references/skeleton-contribution-checklist.md` (both core/ and
  .agents/ copies). Updated reference path in SKILL.md body. Follows agentskills.io
  convention for supporting documentation.
- **skill-authoring Step 1:** Updated frontmatter template to document `license` and
  `compatibility` optional fields with usage guidance.
- **Gap 5 (skills-ref CI):** Closed as N/A — official tool is marked "demonstration
  only, not production." agentskel's `validate.py` serves as the compliance check.

## v1.54.0 — 2026-05-16

### agentskills.io standard compliance — Gap 3: multi-line YAML description support

Removes the single-line description constraint that diverged from the
agentskills.io open standard (which allows up to 1024 chars and recommends
multi-line YAML folded scalars for richer triggering descriptions).

- `scripts/validate.py` — replaced `check_single_line_descriptions()` with
  `check_description_length()` (≤1024 chars, per spec). Added
  `_extract_description()` helper that handles single-line, folded (`>`), and
  block (`|`) YAML scalars. Updated `check_frontmatter()`, `check_stub_parity()`,
  and `check_agents_catalog_parity()` to use it.
- `core/claude-hooks/pre-commit-check.sh` + `.claude/hooks/pre-commit-check.sh`
  — replaced inline multi-line lint with a 1024-char limit check using the same
  YAML-aware extraction logic.
- `core/skills/skill-authoring/SKILL.md` + `.agents/` copy — Step 2 Rule 5 now
  says "under 1024 chars; multi-line YAML folded scalars (`>`) are supported."
  Step 7 stub format updated to note normalization requirement.
- `roles/dev/workflows/sync-skeleton.md` + `.agents/` copy — Step 4c stub
  generation updated to use YAML-aware extraction instead of `grep -m1`.
- Also fixed two pre-existing validator failures: `AGENTS.md` missing
  `discussion-continuity` row (from v1.53.0); `README.md` and `MASTER_PLAN.md`
  version refs stale at v1.50.0.

## v1.53.1 — 2026-05-09

### Fix session-start not triggered post-setup; add post-merge branch cleanup

- `setup-skeleton` — removed separate Step 11 (easy to skip; agents stopped at
  "Final Step" label). Merged session-start reload into Final Step as mandatory
  step 2, immediately after task-completion. Added explicit "Do not skip" gate.
- `git-flow` — new Post-Merge Cleanup section: confirm branch, checkout default,
  pull, `git branch -d` (safe — refuses if unmerged), `git remote prune origin`,
  update RESUME.md. `-D` force-delete explicitly blocked without user instruction.

## v1.53.0 — 2026-05-09

### discussion-continuity skill — formal discussion lifecycle

Discussions had no formal lifecycle; context was lost when interrupted by
workflows. This ships two coordinated pieces:

- New `core/skills/discussion-continuity/SKILL.md` — PAUSE operation saves
  topic/agreed/open/gate to Session Notes before switching tasks; RESUME
  operation retrieves and re-presents on return or on explicit user request
  ("where were we", "present the discussion"). Gate field prevents treating
  return phrase as implementation approval.
- `task-completion` Step 6c — hard-enforcement safety net: after every
  workflow, checks Session Notes for `DISCUSSION PAUSED:` entries and
  invokes discussion-continuity (Operation B) if found. Fires even when
  agent missed the PAUSE step.
- `.claude/skills/discussion-continuity.md` — Claude Code stub for
  CSO auto-discovery.

## v1.52.0 — 2026-05-09

### Session Notes, task capture routing, and backlog grooming

Three related improvements to the task/backlog model:

- `core/memory/RESUME.md` — new `Session Notes` section between Next Task
  and Context Notes. Within-session parking lot for "add to todo" items.
  Unresolved notes carry to next session; agent clears when addressed.
- `core/rules/core-behavior.md` — new `Task Capture` section maps natural
  language to correct file: "add to todo" → Session Notes, "add to backlog"
  → BACKLOG.md, ambiguous → agent confirms. Also clarifies: Next Task = top
  P0 pointer only; multiple next-session items go to BACKLOG.md P0.
- `roles/dev/workflows/janitor.md` — new Step 3 Backlog Grooming: flags P0
  items older than 14 days, P1 older than 30 days, P2 older than 60 days.
  Non-blocking — user can skip. Also fixes `cd [BLUEPRINT_PATH]` → `git -C`
  in commit step (same Bash CWD bleed fix as sync-skeleton/setup-skeleton).

## v1.51.1 — 2026-05-09

### BACKLOG.md: Jira ticket linking column

Added `Jira Ticket` column to BACKLOG.md template. When Jira is configured,
agent prompts for ticket key on new entries — blank means local-only intention
not yet planned in Jira. Makes planned vs unplanned items visible at a glance
without creating a second source of truth.
Files: core/memory/BACKLOG.md, core/skills/task-completion/SKILL.md,
.agents/skills/task-completion/SKILL.md.

## v1.51.0 — 2026-05-09

### Shared BACKLOG.md — persistent task queue across sessions

New memory file `BACKLOG.md` gives agents a durable, session-spanning task
queue. Items survive context resets; the agent pulls the next P0/P1 into
RESUME.md Next Task at each task-completion.

- `core/memory/BACKLOG.md` — new template (P0/P1/P2 table + Done section,
  ID format BL-NNN, Done capped at 5 entries)
- `session-start` Step 2 — line-count check, surfaces count if > 15 lines
- `task-completion` Step 6 — split into 6a (RESUME) + 6b (BACKLOG sync:
  mark done, pull next P0/P1 into RESUME Next Task)
- `setup-skeleton` Step 4 — creates BACKLOG.md during install; also fixes
  remaining `cd .memory / cd ..` pattern (replaced with `git -C .memory`)
- `sync-skeleton` Step 5i — migration for existing projects (create
  BACKLOG.md if absent, skeleton v1.50.2 → v1.51.0)

## v1.50.2 — 2026-05-09

### Fix setup-skeleton Step 9: return to default branch after PR push

After `git push origin chore/setup-skeleton` the main worktree stayed on the
setup branch. Attempting to delete that branch (after merging the PR) or
checkout `ai-memory` (already a worktree) both fail with fatal errors. Added
`git checkout [DEFAULT_BRANCH]` immediately after the PR creation step.
Files: roles/dev/workflows/setup-skeleton.md, .agents/workflows/setup-skeleton.md.

## v1.50.1 — 2026-05-09

### Fix pre-memory-push hook: skip rebase-pull when remote already integrated

`pre-memory-push.sh` ran `pull --rebase origin ai-memory` unconditionally before
every push. When the local branch had already merged remote (via `git merge`),
the rebase would conflict on old commits that the merge had already resolved.
Fix: check `merge-base --is-ancestor` first — if `origin/ai-memory` is already
an ancestor of HEAD, skip the pull. Updated in both `.claude/hooks/` and
`core/claude-hooks/` (template).

## v1.50.0 — 2026-04-24

### Static validator + CI
- New `scripts/validate.py` — deterministic checks that run in seconds and
  prove the skeleton's shape before shipping. Six checks: frontmatter shape
  (every skill/workflow has `description:`), single-line descriptions (no
  multi-line folding), version consistency (VERSION matches README,
  MASTER_PLAN, `.memory/CONFIG.md`), stub parity (`.claude/skills/*.md` match
  `.agents/` sources — no drift, orphans, or missing), AGENTS.md catalog
  parity (the Skills/Workflows tables feed every non-Claude tool and are
  regenerated from frontmatter — same drift risk), and CHANGELOG
  current-version presence.
- New `.github/workflows/validate.yml` — runs the validator on every push and
  PR. Green local run == green CI run.
- `CONTRIBUTING.md` documents the validator in a new section and adds it to
  the PR checklist.
- Catches exactly the class of bug that caused v1.49.3's stub truncation and
  the parallel AGENTS.md catalog drift noted on downstream installs. Not a
  replacement for behavioral testing (agent compliance) or installation
  integration tests — those are separate future tiers.
- AGENTS.md catalog rows regenerated from current sources as part of this
  release (had drifted from v1.49.3 description rewrites).

## v1.49.3 — 2026-04-23

### Fix: skill stubs truncated in downstream + task-completion over-triggers on discussion
- **Truncation fix:** collapsed 37 multi-line YAML `description:` fields in
  `core/skills/`, `roles/dev/skills/`, and `roles/dev/workflows/` to single lines.
  Multi-line folded scalars broke `.claude/skills/` stub generation and the
  `AGENTS.md` catalog regeneration — both read frontmatter line-by-line, so
  only the first line survived. Every downstream install had skills whose
  descriptions cut off mid-sentence, defeating Claude's skill discovery.
- **Prevention:** `pre-commit-check.sh` now blocks any staged skill or workflow
  file containing a multi-line description. `skill-authoring` Step 2 documents
  the constraint.
- **Over-trigger fix:** rewrote the task-completion mandate in
  `core/rules/core-behavior.md` + `core/claude-rules/core-behavior.md` with a
  precise file-based trigger ("files outside `.memory/`") and explicit
  non-triggers (pure discussion, memory-only maintenance, skeleton syncs).
  `task-completion` SKILL gains a Step 0 Applicability Gate that runs
  `git status` and stops when nothing relevant changed. `publish-adr` and
  `publish-postmortem` — which produce external Confluence effects invisible
  to the gate — now explicitly bypass it.
- **Sync-skeleton:** new Step 4c refreshes Claude stubs + enforcement hooks on
  every sync (previously sync never regenerated stubs or updated hook scripts,
  so downstream projects kept stale artifacts after any skeleton upgrade).
  Includes orphan-stub detection. Step gated on `claude` in Supported Tools.
- Gemini-only installs don't get the pre-commit lint (no `core/gemini-hooks/`
  exists today). The markdown rules still apply; deterministic enforcement
  would need a separate hook directory — out of scope for this PATCH.

## v1.49.2 — 2026-04-23

### Fix: pre-memory-push hook blocked first push during setup
- `pre-memory-push.sh` now checks if the remote `ai-memory` branch exists
  before attempting a rebase pull. During initial downstream setup the remote
  branch doesn't exist yet, so the pull failed with a non-fast-forward error
  and blocked the first push. The hook now skips the pull when the remote
  branch is absent (nothing to pull into).

## v1.49.1 — 2026-04-21

### Docs: surface Atlassian integration to new users
- README gains "Connect to the tools your team already uses" section after
  Getting started, pointing to setup-team / setup-jira / setup-confluence with
  links to ATLASSIAN-SETUP.md and TEAM-COORDINATION.md. Previously new users had
  no way to discover these features from the README.
- MASTER_PLAN gains design principle #14 (three-layer knowledge model).

## v1.49.0 — 2026-04-21

### Atlassian integration + team/workflow coordination
- Adds team roster, Jira workflow config, and Confluence doc routing so agents
  participate in the team's existing work processes (not just write code).
- New memory templates: `TEAM.md` (roster + ownership + escalation),
  `JIRA_WORKFLOW.md` (status transitions + handoff rules). CONFIG.md extended
  with Atlassian integration section (Jira site, project key, Confluence
  space, parent pages).
- New skills: `atlassian-integration` (correct MCP tool usage, blocks 4 known
  failure modes including Confluence 5KB truncation), `knowledge-routing`
  (decides whether knowledge belongs in `.memory/`, Confluence, or Jira).
- New team workflows: `setup-team`, `add-team-member`, `remove-team-member`,
  `update-team-member`, `sync-team-from-github`. Uses `gh` CLI when available
  to auto-populate; manual fallback otherwise.
- New Jira workflows: `setup-jira` (introspects project via MCP for statuses
  and required fields), `implement-from-ticket` (ticket → code → PR → status
  transition → QA handoff).
- New Confluence workflows: `setup-confluence`, `publish-adr` (MADR format),
  `publish-postmortem` (with optional Jira action items).
- Existing workflow integrations (all conditional on relevant setup):
  `develop-feature` Phase 0 routes ticket-driven work, Phase 4 transitions
  tickets on PR open/merge; `cut-release` transitions tickets to done and
  publishes release notes to Confluence; `cartographer` offers Jira tickets
  for high-severity tech debt; `brainstorm-feature` offers Confluence spec
  publish; `debug-issue` comments on originating tickets.
- `setup-skeleton` Step 10 now suggests optional Atlassian next steps.
- New docs: `docs/ATLASSIAN-SETUP.md` (per-tool MCP setup for Cloud and DC),
  `docs/TEAM-COORDINATION.md` (three-layer knowledge model + decision table).
- All templates generic — no company/project-specific content. GitHub and
  Atlassian MCP both optional; workflows degrade gracefully when either is
  unavailable.

## v1.48.1 — 2026-04-18

### README simplification + install modes doc
- Simplified README for first-time users: removed framework jargon
  (`.memory/`, `.agents/`, `AGENTS.md`, "worktree", "dispatcher") from
  early sections. Getting started now has 3 plain-language questions.
- New `docs/INSTALL-MODES.md` with ASCII diagrams showing the shape of each
  setup (single project, workspace, blueprint) — no filesystem details that
  confuse new users.
- Detailed install mode content moved out of README into the separate doc.

## v1.48.0 — 2026-04-18

### Workspace dispatcher install mode (Pattern 2)
- New install mode for workspaces with multiple independent projects under one
  parent folder (e.g. `workspace/backend/`, `workspace/flutter/`, each its own
  git repo). Workspace root gets a thin routing dispatcher; each subdir retains
  its own independent agentskel install.
- **New templates** in `core/workspace-templates/`: AGENTS.md, CLAUDE.md, GEMINI.md,
  cursor-rule.mdc, copilot-instructions.md, windsurf-rule.md, claude-rules/routing.md,
  workspace-config.yml (8 files).
- **New workflows:** `setup-workspace`, `add-workspace-platform`,
  `remove-workspace-platform`, `sync-workspace-dispatcher`.
- **Updated `setup-skeleton`** — new Step 0 asks install mode (single / workspace
  platform / workspace dispatcher). Step 9b registers with parent workspace config
  when install mode is "workspace platform".
- **Updated `hooks/session-start`** — detects `.agentskel-workspace.yml` at CWD
  or parent. 6 detection states now including workspace dispatcher and platform-in-workspace.
- **README** — new "Install modes" section documenting 4 supported patterns.
- **MASTER_PLAN** — new design principle #13 (workspace dispatcher install mode).
- **AGENTS.md catalog** — 4 new workflows listed.
- Enforcement hooks stay per-subdir. Workspace root has no `.memory/`, no `.agents/`,
  no hooks — only routing.
- Monorepo patterns (single git repo with multiple projects) explicitly NOT supported —
  workspace pattern covers the same use case with cleaner boundaries.

## v1.47.0 — 2026-04-17

### Semver three-part versioning
- Moved to X.Y.Z format: MAJOR for breaking changes, MINOR for new features,
  PATCH for fixes. Previously everything was a MINOR bump — v1.39, v1.43, v1.46
  should have been PATCH releases.
- Pre-commit hook regex updated to match both X.Y and X.Y.Z formats during
  transition.
- `skeleton-contribution-checklist.md` and `core-behavior.md` bump rules
  distinguish MAJOR/MINOR/PATCH with examples.
- Going forward: every change must be classified before bumping VERSION.

## v1.46 — 2026-04-17

### Fix: pre-commit hook false positives + wall-clock dependency
- Pre-commit hook now explicitly checks command is `git commit` (not `git log`,
  `git status`, etc.). Previously the settings.json `if` pattern was unreliable
  and the hook fired on any bash command.
- Removed `--since="8 hours ago"` wall-clock check. Replaced with last-commit
  check: if CHANGELOG/TIME_LOG were modified in the last ai-memory commit OR
  are currently dirty, the check passes. Works across day boundaries.
- Pre-memory-push hook: same explicit command check.
- Replaced GNU-only `grep -oP` with portable `grep -oE` (macOS default grep
  doesn't support `-P`).

## v1.45 — 2026-04-17

### Cross-tool enforcement hooks + GEMINI.md condensed rules
- Enforcement hooks (pre-commit, pre-memory-push, stop-verify) now have templates
  for all 5 tools: Claude Code, Cursor, Windsurf, Copilot, Codex. Hook scripts
  are tool-agnostic bash; only the config format differs per tool.
- New template directories: `core/cursor-hooks/`, `core/windsurf-hooks/`,
  `core/copilot-hooks/`, `core/codex-hooks/`.
- `setup-skeleton` Step 5b3 expanded to install hooks for all supported tools.
- GEMINI.md template upgraded from thin wrapper to condensed rules inline — same
  level as Cursor/Windsurf/Copilot. Previously only said "read AGENTS.md."
- Shared `stop-verify.sh` script for tools that use command-based stop hooks.

## v1.44 — 2026-04-17

### Blueprint: .claude/rules/ native auto-load
- `create-blueprint.md` Step 6b2: copies trimmed `.agents/rules/` to `.claude/rules/`
  for Claude Code native auto-load. Same rules, second location — no new templates.

## v1.43 — 2026-04-17

### Stop hook: exempt skeleton syncs and infrastructure chores
- Stop hook prompt now distinguishes application code changes (need CHANGELOG/TIME_LOG)
  from skeleton syncs, infrastructure chores, discussion, and .memory/-only changes
  (don't need them). Caught by Muslim-Pro-Android agent during v1.42 sync.

## v1.42 — 2026-04-17

### Subagent dispatch simplification
- Rewrote `subagent-dispatch` skill: parent passes plan steps to subagents instead
  of making subagents rediscover the project. Three dispatch patterns: implementation
  (pass plan steps), review (pass plan + SACRED/CONVENTIONS references), research
  (pass question). No templates needed.
- Deleted `prompts/` directory (implementer.md, reviewer.md, researcher.md) — verbose
  7-section templates that nobody used. Replaced with inline examples in the skill.
- Changed "consider subagent-dispatch" to "use subagent-dispatch" in implement-task
  and refactor-code workflows.
- Added mandatory review dispatch step to develop-feature Phase 4 (before PR).

## v1.41 — 2026-04-17

### Session-start context optimization
- VERSIONS.md removed from session-start Step 2. Loaded by workflows that need it
  (check-dependencies, develop-feature, fix-tech-debt). Session-start only checks
  CONFIG.md timestamp. Saves 44-194 lines at startup.
- RESUME.md partial read: session-start reads up to the `---` marker (Status, Last
  Completed Task, Context Notes, Timestamp). Cartography State and Previously
  Completed sections are below the marker — only loaded by cartographer.
  RESUME.md template restructured with clear marker.
- NEEDS_REVIEW.md: session-start checks line count only, surfaces "N items pending"
  without reading full content. Full content stays in NEEDS_REVIEW.md for triage.

## v1.40 — 2026-04-17

### Stop hook precision + NEEDS_REVIEW triage escalation
- Stop hook prompt sharpened: only triggers CHANGELOG/TIME_LOG for sessions that
  modified files. Pure discussion/analysis sessions no longer create fake entries.
- Cartographer Step 9: untriaged NEEDS_REVIEW items now create a single TECH_DEBT
  entry (NR-TRIAGE) so triage work surfaces when asking "what's pending?" without
  requiring a full cartographer re-run.
- Removed erroneous CHANGELOG entry for analysis work (no files were modified).

## v1.39 — 2026-04-16

### Hook hardening
- Pre-commit hook: added VERSION/README/MASTER_PLAN version consistency check
  for skeleton repos (Skeleton Path = .). Catches the version drift that was
  missed in v1.34, v1.37, v1.38. Also widened session window from 1 hour to
  8 hours to prevent false positives on long sessions.
- Pre-memory-push hook: removed `|| true` error suppression. Pull failures now
  block the push with a clear error message instead of silently proceeding.

## v1.38 — 2026-04-16

### Enforced auto-pull before ai-memory push
- New `pre-memory-push.sh` hook — PreToolUse hook that auto-runs
  `git -C .memory pull --rebase origin ai-memory` before any push to ai-memory.
  Prevents non-fast-forward errors when multiple agents work on the same project.
  The hook fires at the transport layer — agents cannot skip it.
- Updated `settings.json` hook template with the new PreToolUse entry.

## v1.37 — 2026-04-16

### Documentation updates
- Created `INSTALL.md` outlining manual installation instructions for Cursor, GitHub Copilot, Windsurf, and Codex CLI to address issue #30.

## v1.34 — 2026-04-15

### Native-first rule delivery + deterministic enforcement hooks
- **Architecture change:** Rules now live in each tool's native auto-load location
  instead of behind an advisory instruction chain. Compliance baseline measured at
  0% (CHANGELOG/TIME_LOG on Muslim-Pro-Android); this fixes the root cause.
- **Claude Code:** New `.claude/rules/` directory with `core-behavior.md`,
  `security.md`, `bootstrap.md` — auto-loaded natively, no instruction chain needed.
  New `.claude/hooks/pre-commit-check.sh` blocks commits if CHANGELOG/TIME_LOG
  not updated. Stop hook prompts task-completion verification. Templates in
  `core/claude-rules/` and `core/claude-hooks/`.
- **AGENTS.md:** Now self-contained — core-behavior and security rules inlined
  instead of referencing `.agents/rules/`. Codex CLI reads this directly (32KB limit).
- **Cursor/Windsurf/Copilot:** Condensed critical rules (~1.5KB) inlined in native
  configs. Previously thin wrappers saying "read AGENTS.md". New `core/condensed-rules.md`.
- **Skill wiring:** `codebase-navigator` added to 6 workflows (develop-feature,
  debug-issue, implement-task, fix-tech-debt, hotfix, refactor-code). `subagent-dispatch`
  added to 3 workflows. `systematic-debugger` added to debug-issue and hotfix.
  `git-flow` added to develop-feature. `task-planner` added to brainstorm-feature.
  core-behavior "Use your memory" now references codebase-navigator skill.
- **task-planner:** Subagent Strategy section expanded with clear dispatch criteria.
- Updated setup-skeleton (Steps 5b2, 5b3) and sync-skeleton (Step 4, migration 5h).

## v1.33 — 2026-04-12

### Fix: VERSION bump missing from skeleton-contribution-checklist
- Added `VERSION + Config` section to `skeleton-contribution-checklist.md` — the
  checklist executed during task-completion Step 5. VERSION bump and CONFIG.md
  Skeleton Version update were mandated in `core-behavior.md` but absent from
  the checklist, so they were silently skipped every session.

## v1.32 — 2026-04-12

### Fix: session-start mandate in all tool config files and templates
- Added `Session Start — MANDATORY` block directly to CLAUDE.md, GEMINI.md,
  Cursor, Copilot, and Windsurf config files and their `core/` templates.
  Previously only in AGENTS.md, which Claude Code and other tools never read
  eagerly at session start — mandate was invisible until a task triggered it.
  Mandate now appears in every tool's always-loaded context. Downstream projects
  receive the fix automatically via `sync-skeleton` → `core/` template propagation.

## v1.31 — 2026-04-12

### refactor-code workflow + CSO descriptions
- CSO descriptions sharpened: `code-reviewer`, `task-planner`, `developer`,
  `test-engineer`, `systematic-debugger` — all changed to triggering-condition
  format ("When...") to improve agent selection accuracy.
- `task-planner` wired into `develop-feature` Phase 1 (was unreferenced).
- New `refactor-code` workflow — 4-phase safe restructure: characterize & safety
  net, scope lock, atomic execution, verify. Enforces test baseline before any
  change and prohibits behavior changes during refactoring.
- `domain-expert` description updated from [TODO] to usable placeholder
  instructions for downstream projects.
- `README.md` rewritten for public launch and reframed as team infrastructure.

## v1.30 — 2026-04-11

### Brainstorm workflow + TDD + systematic debugging + git worktrees
- New `brainstorm-feature` workflow — Socratic pre-implementation spec. Forces
  the agent to ask 2–3 targeted questions about failure states, data shapes, and
  edge cases before any code is written. Output is a technical spec passed to
  `develop-feature`. Blocks code and plan writing until spec is agreed.
- New `debug-issue` workflow — 4-phase structured debugging: (1) reproduce &
  hypothesize, (2) write failing test, (3) isolate root cause, (4) fix & verify.
  Stops guess-and-check loops. Gates code changes on confirmed hypothesis + failing test.
- New `test-driven-development` skill — RED→GREEN→REFACTOR cycle. Gates production
  code on a prior failing test. Integrated into `develop-feature` Phase 2 as highly
  recommended for all logic changes.
- New `systematic-debugger` skill — prohibits console.log-without-hypothesis and
  "change and see" patterns. Requires root cause tracing, defense-in-depth, or
  bisect technique before any code change.
- New `using-git-worktrees` skill — sibling-directory worktree setup/teardown.
  Prevents IDE re-indexing loops and branch pollution during long feature runs.
- `git-flow` skill updated with worktree quick-reference section.
- `develop-feature` Phase 2 updated to recommend TDD with explicit exemption rule.

## v1.29 — 2026-04-02

### All named functions + module-based symbols + codebase-navigator
- Cartographer now indexes all named functions (public, internal, private,
  protected) — not just public. Skips anonymous lambdas and trivial
  getters/setters. Agents reported skipping SYMBOLS.md because bug fixes
  involve internal functions not in the index.
- **Module-based symbols split:** Projects with 5+ modules use split mode —
  SYMBOLS.md becomes a lightweight index (~30 lines), actual symbols live in
  `symbols/[module].md` files. Agents load only the module they need instead
  of the entire symbol table. Projects with < 5 modules keep single-file mode.
  Cartographer auto-converts from single to split when modules grow.
- SYMBOLS.md template rewritten as dual-purpose (explains both modes).
- New `codebase-navigator` skill — advisory skill for using MAP.md and
  SYMBOLS.md effectively. Covers both split and single-file modes, when to
  use the index vs grep, how to trace flows, and when to skip the index.
- core-behavior "Use your memory" rule simplified to one line — detailed
  guidance moved to the codebase-navigator skill.
- Migration step 5g (v1.28→v1.29): split existing SYMBOLS.md into per-module
  files, reset cartographer for full re-index with all named functions.

## v1.28 — 2026-04-02

### Platform trimming enforcement in sync-skeleton
- New mandatory Step 4b in `sync-skeleton.md` — platform trimming gate after
  file copy. Lists all files with `<!-- PLATFORM: X -->` markers, enforces
  removal of non-project platform sections, and requires verification before
  proceeding. Previously this was a parenthetical note that agents skipped.

## v1.27 — 2026-04-01

### Skill rename + task-completion extraction
- Renamed `senior-developer` skill to `developer` — agents are not senior/junior,
  the skill is about code quality and standards regardless of implied seniority.
  Breaking change: file paths changed from `.agents/skills/senior-developer/` to
  `.agents/skills/developer/`.
- Extracted skeleton-specific steps (README, migration, MASTER_PLAN, self-sync) from
  `task-completion` into `skeleton-contribution-checklist.md`. Downstream projects
  now skip these entirely — task-completion is 50 lines lighter.

## v1.26 — 2026-04-01

### Plugin-based install + README simplification
- New plugin infrastructure for one-command install: `.claude-plugin/` (Claude Code),
  `.cursor-plugin/` (Cursor), `gemini-extension.json` (Gemini CLI).
- Session-start hook (`hooks/session-start`) auto-detects project state:
  full setup (`.memory/` + `.agents/`), partial (`.agents/` only), or none.
  Injects bootstrap context into the agent's session — no manual AGENTS.md reading needed.
- Cross-platform hook launcher (`hooks/run-hook.cmd`) — polyglot bash+batch script
  for macOS, Linux, and Windows (Git Bash).
- New `setup-project` skill (plugin-level) — guides first-time setup, resolves
  skeleton path from `$CLAUDE_PLUGIN_ROOT` automatically.
- `$CLAUDE_PLUGIN_ROOT` added to skeleton path resolution chain in setup-skeleton,
  sync-skeleton, check-skeleton, and session-start. Plugin users no longer need to
  provide skeleton path manually.
- Migration step 5e (v1.25→v1.26) in sync-skeleton for downstream projects.
- README simplified from 247 lines to ~130 lines: leads with quick start (install
  command), grouped memory table, "say this" workflow table. Detailed architecture
  docs remain in MASTER_PLAN.md.

## v1.25 — 2026-03-31

### Rationalization resistance + subagent dispatch
- Rationalization resistance tables added to `session-start` (7 entries) and
  `task-completion` (7 entries) — structured excuse/rebuttal tables that block
  common agent shortcuts. Based on Cialdini's persuasion research.
- Inline rationalization counters added to `core-behavior.md` for plan-first,
  verify-before-done, no-changes-during-discussion, and discuss-agree-execute rules.
- New `subagent-dispatch` skill with 3 prompt templates (implementer, reviewer,
  researcher). Formalizes delegation to subagents with scope boundaries, context
  contracts, and result validation.
- Updated `task-planner` skill to reference `subagent-dispatch` instead of
  inline subagent guidance.

## v1.24 — 2026-03-31

### Skill authoring guide + CSO descriptions
- New `skill-authoring` skill — meta-skill for creating new skills with quality
  gates: CSO-optimized descriptions, rationalization resistance tables, token
  budget awareness, self-sync checklist, and skill testing methodology.
- CSO (Claude Search Optimization) applied to 11 workflow descriptions — rewritten
  from summary-style ("Maps the codebase...") to triggering-condition style
  ("When codebase structure has changed..."). Improves agent skill-matching accuracy.
- Added YAML frontmatter to 3 workflows that lacked it (check-dependencies,
  cut-release, sync-versions).
- Updated AGENTS.md catalog, `.claude/skills/` stubs, and `.agents/` copies to
  match all description changes.

## v1.23 — 2026-03-31

### Session reload triggers
- `session-start` skill now defines three reload triggers: post-sync (after
  `sync-skeleton`), post-setup (after `setup-skeleton`), and stale session
  (`RESUME.md` timestamp >24h old). Post-sync and post-setup also re-read
  `.agents/rules/` to internalize any changed rules.
- `core-behavior.md` Memory Protocol reinforces the reload triggers as a rule.
- `sync-skeleton.md` adds Step 8 (session reload after sync).
- `setup-skeleton.md` adds Step 11 (session reload after setup).

## v1.22 — 2026-03-30

### Native tool configs (opt-in) for Cursor, Copilot, and Windsurf
- New `Supported Tools` field in `.memory/CONFIG.md` — tracks which AI tools have
  native configs installed. Only `AGENTS.md` is always installed; all other configs
  (CLAUDE.md, GEMINI.md, Cursor, Copilot, Windsurf) are conditional on this field.
- New thin wrapper config templates: `core/cursor-rule.mdc.template` (Cursor),
  `core/copilot-instructions.md.template` (Copilot), `core/windsurf-rule.md.template`
  (Windsurf). Each tells the tool to read `AGENTS.md` via its native config format.
- Updated `setup-skeleton.md`: Step 1 now asks which tools the team uses. Steps 5b,
  5c, 5e, 5f, 6, 6b are conditional on Supported Tools — only creates configs for
  selected tools. Any developer can later add support for additional tools.
- Updated `sync-skeleton.md`: migration Step 5d (v1.21→v1.22) auto-detects existing
  tools and asks before adding new ones. Step 4 and Step 6 are conditional on
  Supported Tools.
- Updated `create-blueprint.md`: Step 1 asks which tools to support. Steps 6c and 9
  are conditional on Supported Tools.
- Updated MASTER_PLAN.md Section 6.3: Cursor, Copilot, Windsurf rows now show
  native config paths (thin wrapper → AGENTS.md). Section 6.4 file structure
  includes `.cursor/`, `.github/copilot-instructions.md`, `.windsurf/`.

## v1.21 — 2026-03-30

### AGENTS.md universal entry point + enforcement hardening
- New `AGENTS.md` entry point — the AGENTS.md open standard (Linux Foundation).
  Natively supported by Codex CLI, Cursor, Copilot, and Windsurf. Self-contained
  with hardened enforcement rules and skill/workflow catalogs.
- `CLAUDE.md` and `GEMINI.md` are now thin wrappers that reference `AGENTS.md`
  plus tool-specific discovery mechanisms (stubs, symlinks).
- New `core/AGENTS.md.template` with `[SKILLS_CATALOG]` and `[WORKFLOWS_CATALOG]`
  tokens — generated programmatically during setup from YAML frontmatter.
- Enforcement hardening in AGENTS.md: session-start marked MANDATORY with "Do NOT
  respond until complete", task-completion marked MANDATORY with "BEFORE responding",
  workflow routing ("every task follows a workflow"), memory usage ("use MAP/SYMBOLS,
  do not scan").
- Updated workflows: `setup-skeleton.md` (new Step 5d for AGENTS.md generation),
  `sync-skeleton.md` (v1.20→v1.21 migration step, AGENTS.md in sync path),
  `create-blueprint.md` (blueprint-specific AGENTS.md).
- Updated MASTER_PLAN.md Section 6: new design principle #9, expanded entry points
  table (Codex CLI, Cursor, Copilot, Windsurf), updated file structure and
  interaction diagram.

## v1.20 — 2026-03-27

### MASTER_PLAN section index in MAP.md
- Cartographer workflow now indexes ADR documents (e.g. `MASTER_PLAN.md`) into
  MAP.md with section name, line range, and 1-line summary. Allows agents to
  read specific sections via offset/limit instead of loading the entire document.
- New step 6b in `cartographer.md`: conditional — only runs when a
  `MASTER_PLAN.md` or similar ADR exists in the project.
- Self-dogfooded: agentskel's `.memory/MAP.md` now has a 13-section index of
  `MASTER_PLAN.md` (1,019 lines → ~50-line index).

## v1.19 — 2026-03-27

### UTC timestamps
- All operational timestamps now use ISO 8601 UTC format (`YYYY-MM-DDTHH:MMZ`)
  instead of date-only (`YYYY-MM-DD`). Affects: CONFIG.md check dates,
  VERSIONS.md `Last Updated` column, MAP.md/SYMBOLS.md headers, RESUME.md
  timestamp, DEPENDENCY_ALERTS detected dates. Calendar dates (CHANGELOG
  entries, Upgrade Log, standard revision headers) remain date-only.
- Updated templates: `core/memory/CONFIG.md`, `core/memory/MAP.md`,
  `core/memory/SYMBOLS.md`, `core/memory/RESUME.md`, `core/memory/VERSIONS.md`.
- Updated workflows: `check-dependencies.md`, `check-skeleton.md`,
  `sync-versions.md`, `cartographer.md`, `update-conventions.md`.
- Updated standards: `DEPENDENCY_MANAGEMENT.md`.
- Updated skills: `session-start/SKILL.md`.

## v1.18 — 2026-03-27

### Templates — RULES.md restructure and entry point cleanup
- `core/memory/RULES.md`: Restructured from duplicated behavioral rules to a clean
  two-section template: **Project Context** (vision, goals, domain knowledge) and
  **Project Rules** (ad-hoc project-specific overrides). Identity moved to `CONFIG.md`
  template (new `Description` field). Removed 7 sections that duplicated
  `.agents/rules/core-behavior.md`, plus Key References (redundant pointers to `.agents/`)
  and Cross-Platform Communication (handled by blueprint workflows).
- `core/memory/CONFIG.md`: Added `Description` field to Identity table for project
  identity that was previously in RULES.md.
- `CLAUDE.md.template` and `GEMINI.md.template`: Removed per-file `.memory/` references
  (CONFIG, MAP, SYMBOLS, LESSONS, SACRED, VERSIONS, DEPENDENCY_ALERTS). These are all
  read by the `session-start` skill already. Entry points now reference only:
  `.agents/rules/`, `.memory/RULES.md` (project context and rules), `.memory/RESUME.md`
  (session state), and the three procedural skills. Eliminates dual-inventory maintenance.

### Workflows — RULES.md reference updates
- `setup-skeleton.md`: RULES.md install step updated to reflect new template structure.
- `cartographer.md`: Updated RULES.md description from "operating guidelines" to
  "project-specific context and rules".
- `update-conventions.md`: Fixed stale reference — `Last Conventions Check` is in
  CONFIG.md, not RULES.md.

### Project rules — MASTER_PLAN maintenance enforcement (agentskel only)
- `.memory/RULES.md`: Added MASTER_PLAN Maintenance as a project rule requiring
  mechanical `MAINTAIN_MASTER_PLAN.md` trigger check before completing any skeleton
  change. Lives in project-specific rules (not core-behavior.md) because
  `MAINTAIN_MASTER_PLAN.md` only exists in the skeleton repo.

### Skills — NEEDS_REVIEW.md surfacing
- `session-start/SKILL.md`: Step 2 now reads `.memory/NEEDS_REVIEW.md` (ambiguous findings
  awaiting human classification). Step 3 surfaces non-empty NEEDS_REVIEW entries alongside
  DEPENDENCY_ALERTS. Previously, triage items could sit unnoticed between sessions.

## v1.17 — 2026-03-27

### Workflows — Blueprint entry point consistency
- `create-blueprint.md`: Blueprint `CLAUDE.md` template now includes `git-flow` skill
  trigger, `.agents/rules/` reference, and `CONFIG.md` reference. Previously only had
  `session-start` trigger and domain content references — missing framework rule discovery
  and git discipline after context compaction.
- `create-blueprint.md`: Blueprint `GEMINI.md` template replaced vague "simplified
  similarly" instruction with an explicit inline template. Now symmetric with `CLAUDE.md`
  — both reference `.agent/rules/`, skill discovery, `CONFIG.md`, `specs/`, `parity/`,
  and `bus/`.

## v1.16 — 2026-03-27

### Templates — Symmetric entry points for compaction resilience
- `GEMINI.md.template`: Added 8 `.memory/` file references matching CLAUDE.md.
  Previously, if session-start context was lost to compaction, the Gemini agent
  had no fallback to rediscover the memory system. Now both entry points
  reference all shared resources.
- `CLAUDE.md.template`: Added `.agents/rules/` reference. Previously, Claude Code
  never explicitly read `core-behavior.md` or `security-non-negotiables.md` —
  framework rules were only loaded via `.memory/RULES.md` (which covers similar
  but not identical ground). Now both entry points reference both rule sources.

## v1.15 — 2026-03-27

### Skills — Blueprint sync enforcement
- `task-completion/SKILL.md`: Step 4 now commits and pushes Knowledge Bus
  entries to the blueprint repo after creating them. Previously, bus entries
  were created locally but never pushed — other project agents couldn't see them.
- `session-start/SKILL.md`: Step 5 gains a blueprint staleness rule — warns if
  `Last Blueprint Sync` is >7 days ago or absent (when blueprint is configured).
- `session-start/SKILL.md`: Step 6c now reads each bus entry to check for
  unchecked action items targeting this platform, rather than just listing files.
  Surfaces unprocessed entries individually with their action items.

## v1.14 — 2026-03-27

### Skills — Auto-pull ai-memory on session start
- `session-start/SKILL.md`: Step 1 now pulls latest `ai-memory` from remote
  before reading memory files. Ensures dev B always gets dev A's latest
  cartography and memory updates. Gracefully falls back to local copy if
  network is unavailable or history has diverged.

### Scripts — install-agent.sh pulls latest on re-run
- `install-agent.sh`: When `.memory/` already exists, pulls latest from
  `origin/ai-memory` instead of exiting with "nothing to do." Re-running
  the script now refreshes memory.

## v1.13 — 2026-03-27

### Rules — Use cartographed memory
- `core-behavior.md`: Added "Use your memory" rule — when MAP.md and
  SYMBOLS.md exist, use them to locate files and modules instead of
  re-scanning the codebase. The cartographer indexed it; use the index.

### Skills — Code cleanup rules
- `developer/SKILL.md`: Added explicit code cleanup rules to Code
  Quality section — remove unused imports, organize imports per STYLE_GUIDE,
  remove unused variables/parameters/local functions, review own changes for
  leftover debug code and temporary comments.

### Skills & Workflows — Static analysis made optional
- `developer/SKILL.md`: Per-platform static analysis changed from
  mandatory ("New code must pass X") to conditional ("If the project uses X,
  run it and fix violations"). Applies to Detekt (Android), SwiftLint (iOS),
  ESLint/Prettier (Web), and project linter (Backend).
- `develop-feature.md`: Step 18 changed from "Run static analysis and fix all
  violations" to "If the repo has a static analysis tool configured, run it
  and fix violations."
- `fix-tech-debt.md`: Step 16 — same change.
- `hotfix.md`: Step 14 — same change.
- `implement-task.md`: Already conditional ("if available") — no change needed.

### Standards — CI lint gate made conditional
- `GIT_WORKFLOW.md`: PR merge requirement changed from "CI must pass (lint,
  tests, build)" to "CI must pass (tests, build, and lint if configured)."
- `code-reviewer/SKILL.md`: Lint check item 5 changed from "The author must
  fix violations" to "If CI runs static analysis, the author must fix
  violations."

## v1.12 — 2026-03-26

### Rules — Workflow enforcement, assumptions, and content preservation
- `core-behavior.md`: Added "Never assume" rule — verify before concluding
  that something is missing or broken. Read the actual mechanism first.
- `core-behavior.md`: Added "Every task follows a workflow" rule — all
  implementation requests must route through a matching workflow
  (`develop-feature`, `fix-tech-debt`, `hotfix`) or default to
  `implement-task`. No working without a workflow.
- `core-behavior.md`: Changed "Plan first" from non-trivial-only to all
  tasks. Trivial tasks get shorter plans, but still require explicit
  approval before coding.
- `core-behavior.md`: Added Content Preservation section — never replace
  detailed instructions with generic summaries without explicit reasoning
  and approval. Institutional knowledge lives in the detail.

### Workflows — implement-task hardening
- `implement-task.md`: Removed trivial task escape hatch (step 7 that
  allowed skipping plan approval for "1-2 files, clear scope"). All tasks
  now require plan → summarise → explicit approval.
- `implement-task.md`: Moved branch creation from Phase 4 (after
  implementation) to Phase 1b (after plan approval, before coding).
  Aligns with git-flow gate: "Do not write any application code until
  a branch has been created."
- `implement-task.md`: Added `test-engineer` skill reference in Phase 3
  (Verify) for consistency with `develop-feature`.

### Workflows — fix-tech-debt consistency
- `fix-tech-debt.md`: Added `test-engineer` skill reference in Phase 3
  (Test & Verify) for consistency with `develop-feature`.

## v1.11 — 2026-03-26

### Templates — CLAUDE.md parity with GEMINI.md
- `CLAUDE.md.template`: Added 3 procedural skill triggers (`session-start`,
  `task-completion`, `git-flow`) — matches GEMINI.md.template which already
  had them. Ensures these instructions survive context compaction in Claude
  Code, since CLAUDE.md is re-injected every turn.

### Rules — Compaction-safe effort tracking and dependency boundaries
- `core-behavior.md`: Added Effort Tracking section (estimate human hours,
  record in RESUME.md before starting) and Dependency Boundaries section
  (never upgrade without instruction, read release notes, major upgrades
  need full plan). Previously these only existed in RULES.md which gets
  compacted out of context.

### Skills — Judgment enforcement in task-completion
- `task-completion`: Step 5c now requires reading MAINTAIN_MASTER_PLAN.md
  trigger list and stating which triggers matched — replaces vague "if this
  task changed structure" with an explicit checklist.
- `task-completion`: Added Step 8 (completion summary) — agent must list
  steps executed and steps skipped with reasons before responding. Makes
  skip decisions visible to the user.

## v1.10 — 2026-03-25

### Rules — Self-sync enforcement for skeleton repos
- `core-behavior.md`: Added items 5-6 to Skeleton Contribution checklist —
  when `Skeleton Path` = `.` (i.e. this IS the skeleton), copy every changed
  `core/` or `roles/` file to its `.agents/` counterpart in the same commit,
  and update `.memory/CONFIG.md` Skeleton Version to match VERSION.

### Skills — Self-sync verification gate
- `task-completion`: Added Step 5d — verification gate that diffs all changed
  source files against their `.agents/` copies and checks `.memory/CONFIG.md`
  Skeleton Version matches VERSION. Blocks commit until both checks pass.
  Skeleton/agentskel repos only.

## v1.9 — 2026-03-25

### Workflows — Generic task wrapper
- Added `implement-task.md`: lightweight workflow for any ad-hoc implementation
  request (fix, change, add, remove, refactor) that doesn't match a named
  workflow (develop-feature, fix-tech-debt, hotfix). Ensures pre-flight,
  planning, and task-completion happen for every task — closes the enforcement
  gap where ad-hoc tasks could skip the post-task checklist.
- 15 workflows total (was 14).

## v1.7 — 2026-03-25

### Fixes — Spec drift cleanup
- `domain-expert/SKILL.md`: Removed stale reference to "blueprint's
  `skills/domain-expert/SKILL.md`" — blueprints do not include domain-expert
  (create-blueprint workflow explicitly excludes it)
- `README.md`: Fixed standards count in repo structure (was "5 standard
  documents", actually 7)

## v1.6 — 2026-03-25

### Rules — MASTER_PLAN version tracking
- `core-behavior.md`: Added item 4 to Skeleton Contribution checklist — when a change
  affects structure, architecture, or install/sync paths, update `MASTER_PLAN.md` and
  its `Corresponds to:` version marker
- `MASTER_PLAN.md`: Added `Corresponds to: agentskel vX.Y` marker after the title,
  making drift between the ADR and the skeleton version detectable

### Skills — MASTER_PLAN checklist item
- `task-completion`: Added Step 5c (MASTER_PLAN) — update MASTER_PLAN.md per
  MAINTAIN_MASTER_PLAN.md when structure/architecture changes, update the
  `Corresponds to:` version marker to match the new VERSION. Skeleton/agentskel
  repos only.

### Workflows — Blueprint migration steps
- `create-blueprint.md`: Updated sync-skeleton.md trimming notes to include Step 5x
  migration mechanism (adapted for blueprint — migrations go in the sync branch
  commit, not ai-memory). Ensures blueprints created from the template have a
  documented path for breaking-change migrations.

## v1.5 — 2026-03-24

### Workflows — Blueprint trimming rules
- `create-blueprint.md`: added blueprint-specific trimming instructions for all copied files
  — previously said "copy as-is" for files that contain `.memory/`, `ai-memory`, code-testing,
  and session lifecycle references that don't exist in blueprints
- **Rules:** `core-behavior.md` must be trimmed (remove Memory Protocol, Task Completion,
  Skeleton/Blueprint Contribution sections; add Blueprint Identity section)
- **Workflows:** `develop-feature.md` excluded (100% app workflow); `sync-skeleton.md` and
  `check-skeleton.md` must be trimmed (root `CONFIG.md` instead of `.memory/CONFIG.md`,
  no ai-memory commits, no task completion checklist)
- **Standards:** `GIT_WORKFLOW.md` must be simplified for blueprint context (branch naming,
  commits, PRs only — no release/hotfix flows, no AI session protocol)
- **Skills:** `developer` excluded (100% code-focused); `task-planner` must be trimmed
  (remove `.memory/` references, localize Blueprint Check to direct `specs/` paths);
  blueprint-specific `session-start` created (reads root CONFIG.md, checks skeleton version,
  checks git state — no memory mount, no dependency alerts, no freshness dates)
- **CLAUDE.md template:** updated to trigger `session-start` skill for automatic skeleton
  version checking at the start of every session

### Skills — Blueprint skeleton check from downstream projects
- `session-start` (project version): added Step 6b — when a project has a `Blueprint Path`,
  check the blueprint's `CONFIG.md` Skeleton Version against the current skeleton version.
  Surfaces drift as informational (does not block session — sync must be run from the
  blueprint repo directly)

## v1.4 — 2026-03-24

### Workflows — Blueprint skills removal
- `create-blueprint.md`: removed step 4d (blueprint `skills/` directory creation)
  — no agent integration loads skills from `[BLUEPRINT_PATH]/skills/`; all 4 integration
  points (session-start, task-planner, code-reviewer, task-completion) read only from
  `[BLUEPRINT_PATH]/specs/` and `[BLUEPRINT_PATH]/bus/`
- Removed `skills/` from commit, PR body, and post-setup report
- Added clarifying note: domain knowledge lives in `specs/`, not blueprint skills
- Updated v1.2 and v1.0 changelog entries to remove stale `skills/domain-expert/` references

## v1.3 — 2026-03-24

### Workflows — cut-release finalized
- `cut-release.md`: removed DRAFT status, broadened scope from mobile-only to all platforms
- Replaced `[TODO]` markers with `<!-- PLATFORM: X -->` blocks for Android, iOS, Web, Backend
- Pre-flight: platform-specific version file locations (build.gradle, xcconfig, package.json, etc.)
- Step 1: platform-specific CI trigger examples (GitHub Actions, Fastlane)
- Step 5: platform-specific build/deploy trigger examples

### Standards — API Contract completed
- `API_CONTRACT.md`: replaced stub with full standard covering 7 topics:
  URL-prefix versioning, JSON request/response envelope, error format with status code table,
  Bearer token auth, rate limiting headers, cursor-based pagination, breaking change policy
  with 90-day deprecation process
- Includes Agent Rules section for code review and implementation guidance

## v1.2 — 2026-03-24

### Workflows — Blueprint creation
- Added `create-blueprint` workflow: step-by-step setup for a new blueprint repo
  (shared domain knowledge for multi-project teams)
- Creates: `specs/` (domain spec stubs), `parity/PARITY_MATRIX.md`,
  `bus/` (knowledge bus with entry template)
- Lightweight design: no ai-memory branch — blueprint is a knowledge hub managed
  by project-specific agents via `Blueprint Path`
- Includes `.agents/` as safety net with root-level `CONFIG.md` for identity
- 14 workflows total (was 13)

### Workflows — Janitor clarification
- `janitor.md`: clarified that it runs from project context (not blueprint repo);
  project agent reaches into blueprint via `Blueprint Path`

### Skills — Blueprint awareness
- `session-start`: Added Step 6 with two sub-steps:
  - 6a: pull latest blueprint, detect new commits since `Last Blueprint Sync`,
    surface changed specs/parity files to user
  - 6b: check Knowledge Bus for entries targeting this platform
- `domain-expert`: Added `## Blueprint Integration` section — points to
  `[BLUEPRINT_PATH]/specs/` as source of truth for shared business logic
- `code-reviewer`: Added `## Cross-Platform Impact` checklist — verify changes
  match blueprint specs, flag shared logic changes needing bus entries
- `task-planner`: Added `## Blueprint Check` section — read specs and parity
  matrix before planning features that touch shared logic

### Memory — Blueprint sync tracking
- `CONFIG.md` template: Added `Last Blueprint Sync` field to Operational Config;
  updated by session-start after reviewing blueprint changes

## v1.1 — 2026-03-24

### Skills — Platform markers
- `developer`: Added `## Platform Standards` section with Android (Compose/UDF,
  Coroutines, Detekt), iOS (async/await, SwiftUI, SwiftLint), Web (TypeScript, ESLint),
  Backend (generic async/linting) platform markers
- `code-reviewer`: Added platform markers to checklist items 4 (architecture standards),
  5 (lint/static analysis tools), 10 (dependency file references)
- `test-engineer`: Replaced generic Test Structure with platform-marked sections —
  Android (MockK, Espresso, backtick naming), iOS (XCTest, XCUITest),
  Web (Jest/Vitest, Playwright), Backend (standard framework)
- `setup-skeleton` and `sync-skeleton` updated to trim skill platform markers
  (same mechanism as standards)

### Standards — Platform-specific architecture
- Added `ANDROID_ARCHITECTURE.md`: Compose/UDF, Hilt DI, Compose Navigation,
  module graph, data layer patterns (generic template — adapt to project domain)
- Added `IOS_ARCHITECTURE.md`: SwiftUI, NavigationStack, Swift Concurrency,
  SPM module structure, data layer patterns (generic template)
- `setup-skeleton` updated to copy platform-specific standards (Android-only or iOS-only)

## v1.0 — 2026-03-20

Initial release. 2-component architecture: skeleton (agentskel) + optional blueprint
(team domain knowledge).

### Core
- Memory system: ai-memory branch, worktree at `.memory/`, checkpoint protocol
- Procedural skills: session-start, task-completion, git-flow
- Rules: core-behavior, security-non-negotiables, repo-rules convention
- Entry point templates: CLAUDE.md, GEMINI.md
- CONFIG.md: Skeleton Version, Skeleton Path, Blueprint Path (optional),
  Last Skeleton Check, Last Dependency Check, Last Conventions Check

### Role — dev
- 13 workflows: cartographer, check-dependencies, check-skeleton, cut-release,
  develop-feature, fix-tech-debt, hotfix, janitor, parity-check,
  setup-skeleton, sync-skeleton, sync-versions, update-conventions
- 5 standards: architecture, git workflow, style guide, dependency management, API contracts
- Claude Code skill stubs (auto-generated from skills + workflows)
- 8 mission prompts
- Domain skills: developer, test-engineer, code-reviewer, task-planner, domain-expert

### Architecture
- Skeleton = agentskel framework (rules, workflows, skills, standards), installed per project
- Blueprint = optional team domain knowledge repo (specs, parity, bus)
- `[SKELETON_PATH]` for framework templates, `[BLUEPRINT_PATH]` for domain knowledge
- Symlink pattern for skeleton/blueprint repos, copies for downstream projects
- agentskel self-installs its own pattern (`.agents/rules/` symlinks to `core/rules/`)
