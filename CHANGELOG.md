# Agent Changelog: agentskel

<!-- Log every change with description and reasoning.
     Format: ## [DATE] — [Short Description]
     Include: what changed, why, files affected, any risks. -->

## 2026-06-07 — v1.63.1 self-sync follow-up: backfill missing CONFIG.md fields

After v1.63.1 shipped, ran the new Step 5 field-diff check against agentskel
itself. Found 9 missing fields in `.memory/CONFIG.md`:
- v1.49.0 additions (Atlassian section): Jira Site, Jira Project Key,
  Confluence Space Key, Confluence Specs/ADRs/Runbooks/Postmortems Parent
- v1.57.0 additions: External Platform Skills, Last External Skills Check

agentskel had skipped these field additions across two releases — exactly
the gap the new Step 5 enumeration was designed to catch. Dogfooded our
own fix, found the bug it predicted, backfilled. Fields filled with
template defaults / empty (not applicable to the skeleton itself).

## 2026-06-07 — v1.63.1: sync-skeleton doc gaps (CONFIG field enumeration + restart hint)

Two minor doc gaps from the downstream-migration audit:

1. Step 5 used to say "Apply any memory file template updates" — vague.
   Downstream agents on old skeleton versions had no way to know which
   CONFIG.md fields were added when. Now Step 5 explicitly tells the
   agent to diff the project's CONFIG.md against the template, with a
   hint list of historical field additions (Supported Tools v1.22,
   Last Skeleton Check v1.23, Atlassian section v1.49.0, External
   Platform Skills v1.57.0).

2. Step 8 (session reload) only told the agent to re-execute
   session-start. That's enough for skill/rule/workflow changes
   (most tools watch those dirs) but not for hook config changes —
   .cursor/hooks.json, .windsurf/hooks.json, .gemini/settings.json,
   .claude/settings.json, .codex/hooks.json are loaded once at
   startup and don't reload live. Step 8 now explicitly says: if
   sync touched any hook config, tell the user to restart their AI
   tool. Per-tool restart behavior documented inline.

No logic changes. Memory-only-impact PATCH.

## 2026-06-07 — v1.63.0: Cartography refresh (MAP + SYMBOLS + RESUME state)

Memory-only refresh. No workflow/code changes. v1.60-v1.62.x cross-tool work
compounded into cartography drift; this PR aligns MAP.md, SYMBOLS.md, and
RESUME Cartography State with reality.

MAP.md: rewrote architecture pattern entry-points section with per-tool
explicit list (was single line); module registry updated for all 5 hook
dirs (cursor expanded, gemini new, windsurf expanded, codex same,
copilot deleted) + new tool-specific stub dirs (.gemini/skills/,
.cursor/rules/, .windsurf/workflows/, .github/prompts/); validate.py
grown to 10 checks. SYMBOLS.md: 5 new functions added, 1 removed
(check_stub_parity refactored). RESUME Cartography State: new HEAD,
coverage target ~430 (was 262).

`.agent` symlink documented as legacy compat — decided to keep (harmless,
no signal it's truly unused).

## 2026-06-07 — v1.62.2: Windsurf hook scripts (wrong I/O contract — silent allow bug)

Continuing v1.62.1's self-audit. Verified Windsurf + Codex hook I/O contracts
against current docs.

**Windsurf silent bug:** Claude scripts read `tool_input.command` from stdin,
but Windsurf nests command as `tool_info.command_line`. The COMMAND var was
always empty on every Windsurf install. Pre-commit and pre-memory-push
hooks silently allowed everything. Bug since Windsurf hooks first shipped.

Wrote 4 Windsurf-format scripts in core/windsurf-hooks/ that read the right
key. Added pre_write_code event (plan-gate, matches other tools).
stop-verify can't block on post_cascade_response per docs (post-hooks
can't exit 2) — surfaces warnings via stderr instead. setup-skeleton +
sync-skeleton updated; v1.62.2 migration block force-overwrites the four
scripts in downstream `.windsurf/hooks/`.

**Codex verified, no changes:** tool_input.command matches Claude. Sourcing
from core/claude-hooks/ confirmed intentional.

472 ok, 0 fail on validator.

## 2026-06-07 — v1.62.1: Plugin manifest drift + setup-skeleton clarity

Self-audit caught three gaps in the v1.60/v1.61/v1.62 series:
- gemini-extension.json + .claude-plugin/plugin.json stuck at 1.61.0 (v1.62.0
  forgot to bump them). Bumped to 1.62.1. Users would have seen the wrong
  version in `gemini extensions list` / `/plugin list`.
- Validator's check_version_consistency missed plugin manifests entirely.
  Extended to cover both. Regression-tested: validator correctly flagged the
  drift before the fix.
- setup-skeleton hook-install text "Copy the same 3 hook scripts to
  .windsurf/hooks/" was ambiguous (same as what?). Replaced with explicit
  source paths. Added honest disclaimer that Windsurf and Codex I/O
  contracts haven't been formally verified to match Claude's — if either
  differs like Cursor did, those scripts may not block correctly.

472 ok, 0 fail on validator. Other gaps (Windsurf/Codex contract verify,
MAP.md refresh, .agent symlink cleanup) deferred to v1.62.x / v1.63.

## 2026-06-07 — v1.62.0: Cross-tool discoverability bundle (Cursor, Windsurf, Copilot)

Completes the cross-tool parity series. Audited all four remaining tools
against current 2026 docs:

- **Cursor**: hooks were silently inactive (wrong path + invented matcher
  syntax + broken sessionStart). Fixed path (.cursor/hooks.json), matcher
  (regex per spec), event names (beforeShellExecution). Wrote 4 Cursor-
  format hook scripts (Cursor's I/O contract: command at top of stdin,
  JSON {permission,user_message,agent_message} on stdout). Generated 50
  per-file .cursor/rules/<name>.mdc with alwaysApply:false for
  agent-requested discoverability.
- **Windsurf**: stop hook was silent no-op (no `stop` event in Windsurf).
  Replaced with post_cascade_response. Generated 33 first-class
  .windsurf/workflows/<name>.md so each workflow is slash-invokable as
  /<name>.
- **Copilot**: removed core/copilot-hooks/ entirely — Copilot has no hooks
  concept; the install was dead code. Generated 33 .github/prompts/<name>.
  prompt.md slash-invokable prompt files.
- **Codex**: verified hooks.json events (PreToolUse, Stop) match spec.
  No changes needed.

Validator: +3 checks (cursor rule, windsurf workflow, copilot prompt
parity), factored common logic into _flat_stub_parity. 470 ok, 0 fail
(was 354).

Downstream migration baked into sync-skeleton Step 4c: git mv Cursor
hooks file, re-copy scripts from core/cursor-hooks/ (was sourcing from
core/claude-hooks/), fix Windsurf stop event, git rm -rf .github/hooks/.

## 2026-06-07 — v1.61.0: Gemini CLI / Antigravity parity bundle

Three-item bundle closing the Gemini-side parity gaps to match v1.60.0's
Claude fix:

1. Workflow discoverability: generated 50 stubs in `.gemini/skills/<name>/SKILL.md`
   so workflows in `.agents/workflows/` (which Gemini doesn't auto-scan) become
   discoverable as skills. setup-skeleton Step 5b1 (new) + sync-skeleton Step 4c
   refresh these on every install/sync. Validator gains `gemini stub parity`
   check mirroring `claude stub parity`.

2. Extension manifest: `gemini-extension.json` (already at repo root) bumped
   v1.26.0 → v1.61.0; description clarified to set expectations.
   `.claude-plugin/plugin.json` also bumped for consistency.

3. Gemini-format hooks: new `core/gemini-hooks/` with 4 scripts following
   Gemini's strict JSON I/O contract (stdin JSON, stdout JSON-only, stderr for
   rejection reasons). Events: `BeforeTool` (pre-commit, pre-memory-push,
   pre-edit), `AfterAgent` (stop-verify). Plus `settings.json` template.
   setup-skeleton Step 5b3 extended with Gemini install block.

All three required reading the actual Gemini CLI docs (not guessing). Validator
green: 354 ok, 0 fail (added gemini stub parity check, 50 items).

## 2026-06-06 — v1.60.0: Fix Claude Code skill discovery — migrate stubs to directory layout

Root cause of "Claude misses all workflows": project-level `.claude/skills/<name>.md`
flat files were silently ignored by Claude Code's loader since v1.26. Spec requires
`.claude/skills/<name>/SKILL.md` (directory). Migrated all 50 stubs in this repo,
updated setup-skeleton Step 5b and sync-skeleton Step 4c, added migration step for
downstream projects (auto-converts pre-v1.60.0 flat layouts on next sync via git mv).
validator updated to check directory layout and flag legacy flat files. Verified
empirically: created test stub in correct format → appeared in available-skills
immediately; bulk-migrated 50 → all visible after file-watcher caught up.

Diagnosis surfaced by HelpDesk transcript audit (12,639 lines): 0 session-start
runs, 1 task-completion run, 0 workflow invocations vs ~1,011 Edit/Write calls.
Format mismatch silently broke every Claude session since March 2026.

Side benefit: skills now auto-bind to slash commands (`/debug-issue` etc.) and CSO
description matching works. Future PATCHes will address session-start auto-fire
(SessionStart hook) and task-completion enforcement (strengthened Stop hook).

## 2026-06-03 — v1.59.2: Suppress misleading `fatal:` git stderr

When `git pull` fails (no network, no remote, stale worktree), git prints
`fatal: …` to the user's screen — alarming, because two of our call sites
handle the failure cleanly and follow up with a friendly warning. Surfaced
by v1.59.1 dogfood test in a sandbox without origin. Fixed:
`scripts/install-agent.sh` (memory pull) and `sync-skeleton` Step 0
(self-update skeleton pull). Both now redirect stderr to `/dev/null`,
matching the pattern already used in session-start and pre-memory-push.sh.
The `||` fallback continues to print the agentskel-friendly warning.
`setup-skeleton` instruction text updated to match.

## 2026-06-03 — v1.59.1: Auto-link external skills on session-start (no manual install-agent.sh)

After v1.58.0+ syncs introduced external-skill manifest entries, teammates
pulling the merged sync had to remember to run `scripts/install-agent.sh`
manually before their first agent session — otherwise the agent would
silently miss those skills. New `session-start` Step 1b detects missing
symlinks (manifest entries in `.agents/skills/.gitignore` with no matching
symlink) and runs `install-agent.sh` once; idempotent and safe. Surfaces
any "shared store missing pack" warnings and offers to run the
`update-external-skills` workflow. `sync-skeleton` Step 7 PR body template
now includes accurate post-merge teammate instructions, replacing the
ad-hoc misleading "symlinks point at non-existent dir" wording.

## 2026-05-21 — v1.57.2: Fix setup-skeleton step ordering + ai-memory default branch

Fix 1: Step 9c (platform skills) moved before the git commit in Step 9 — was running
after git checkout [DEFAULT_BRANCH], causing agent to switch back to setup branch to
commit regenerated stubs, leaving worktree stuck and blocking branch deletion.
Fix 2: gh repo edit --default-branch added after git push origin ai-memory in Step 3
to explicitly pin GitHub default branch (brand-new repos take first-pushed branch as
default). Verification gates added after both git checkout [DEFAULT_BRANCH] calls.
affected: setup-skeleton

## 2026-05-31 — v1.58.0: Shared external skills store (~/.agentskel/)

External skills now live in ~/.agentskel/skills/ (shared per machine). Projects
get gitignored symlinks. New core/external-skills.yml manifest — adding packs
requires only a YAML entry. New update-external-skills workflow. sync-skeleton
Step 4d migrates old-style installs automatically. install-agent.sh recreates
symlinks on clone via .gitignore manifest.

## 2026-05-31 — v1.57.3: setup-skeleton Step 9c install verification gate

Dogfood E2E test against Muslim-Pro-Android surfaced a downstream state
where the `External Platform Skills` flag was `installed` but no SKILL.md
files with `metadata.author: Google LLC` were present — only orphan
`references/` subdirectories from a partial install. My Step 9c wording
("If found, set flag to `installed`") left "not found" implicit, allowing
agents to set the flag eagerly. New wording explicitly requires a
scan-confirm gate: on scan miss, do NOT set flag, report scan output,
stop. sync-skeleton Step 4d's reconcile logic already handles in-the-wild
bogus `installed` flags on next sync.

## 2026-05-21 — v1.57.0: External platform skills (Android) + validator third-party awareness

Reference-don't-vendor approach to platform-specific skills. Google's
android/skills follows the same agentskills.io standard and installs to
the same `.agents/skills/` path we use — files drop in and work. agentskel
gains:
- `docs/PLATFORM-SKILLS.md` with Android section + install/update guidance
- `setup-skeleton` Step 9c suggests install on Android projects (3-option
  prompt: install / ask later / decline; outcome stored in CONFIG)
- `sync-skeleton` Step 4d re-checks on every sync, reminds to refresh at
  30-day cadence, respects `declined` flag
- `core/memory/CONFIG.md` gains `External Platform Skills` + `Last External
  Skills Check` rows
- `developer/SKILL.md` Android section points to PLATFORM-SKILLS.md
- `scripts/validate.py` distinguishes first-party (in core/ or roles/) from
  third-party skills — parity checks skip the latter so downstream installs
  with android/skills don't fail validation

Also fixed pre-existing version drift in README (was v1.55.4) and
.memory/CONFIG.md Skeleton Version (was v1.50.0).

## 2026-05-17 — v1.56.1: Fix stop-verify.sh RESUME.md false positive

stop-verify.sh excluded RESUME.md from .memory/ dirty check. RESUME.md is
local-only (never committed) — was blocking every session end when modified.

## 2026-05-17 — v1.56.0: Option D — plan-first enforcement (behavioral + advisory hook)

"Plan first" moved to position 1 in core-behavior.md (all 4 copies). New "Never
modify files without explicit approval" rule added at position 2 — explicitly names
Edit/Write as the gate point and clarifies that prior approval does not carry forward.
condensed-rules.md updated for tight-character-limit tools. pre-edit-check.sh (new):
advisory hook that fires before Edit/Write, prints plan-gate reminder, exits 0.
settings.json (core + installed) updated with Edit/Write PreToolUse matchers.
LESSONS.md Lesson 006 extended: Edit/Write is the specific trigger to check.
MASTER_PLAN.md point 11 updated to describe the advisory hook mechanism.

## 2026-05-17 — v1.55.0: Post-sync workflow/skill triage via affected: field

CHANGELOG entries now include `affected: name, name, ...` for changes touching
workflows/skills. sync-skeleton Step 4d collects these from applied entries,
writes SYNC PENDING TRIAGE to RESUME Session Notes. Final Step triages: re-reads
active workflows/skills, surfaces non-active to user, clears entry.
skeleton-contribution-checklist + task-completion SKILL Step 1 document the rule.
Backfilled affected: into v1.54.2 entry.
affected: sync-skeleton, task-completion

## 2026-05-17 — v1.55.4: Replace broken Stop hook with deterministic script

stop-verify.sh: checks uncommitted project/.memory/ changes, exits 0 or 2.
settings.json: Stop hook changed from type:prompt (loop) to type:command.
LESSONS.md 006: plan-first applies even to urgent-seeming bugs.

## 2026-05-17 — v1.55.3: Remove broken Stop hook + fix v1.55.2 affected: gap

Stop hook type:prompt caused infinite loop (response triggers Stop again).
Pre-commit hook already enforces CHANGELOG/TIME_LOG — Stop hook redundant.
Removed from core/claude-hooks/settings.json + .claude/settings.json.
Also added missing affected: task-completion to v1.55.2 CHANGELOG entries.

## 2026-05-17 — v1.55.2: Precision rule for affected: field

Add precision rule to skeleton-contribution-checklist: only include a
name if its file was directly modified, not merely mentioned in prose.
Caught by dogfooding the triage feature.
affected: task-completion

## 2026-05-17 — v1.55.1: Fix skill-authoring false positive in v1.55.0 affected: line

Removed skill-authoring from v1.55.0 affected: — no skill-authoring files changed.

## 2026-05-17 — v1.54.2: Workflow plan gate strengthening

Closes "concerns ≠ plan" rationalization loophole. Agents were listing
concerns then proceeding without explicit approval. develop-feature,
implement-task, fix-tech-debt, refactor-code: plan step strengthened with
explicit definition (approach + files + decisions). debug-issue: added
missing approval gate (step 10b) before Phase 4 — previously had none.
10 files changed.
affected: develop-feature, implement-task, fix-tech-debt, refactor-code, debug-issue

## 2026-05-16 — v1.54.1: agentskills.io Gaps 1, 2, 4 — license, compatibility, references/

license: MIT added to all 34 SKILL.md files. compatibility added to skill-authoring
(only skill referencing .claude/ in body). task-completion/skeleton-contribution-
checklist.md moved to references/ subdirectory. skill-authoring Step 1 documents
optional standard fields. Gap 5 (skills-ref CI) closed as N/A.
40 files changed.

## 2026-05-16 — v1.54.0: agentskills.io Gap 3 — multi-line YAML description support

validate.py: _extract_description() handles folded/block YAML scalars;
check_single_line_descriptions → check_description_length (≤1024 chars per spec).
Pre-commit hooks updated to match. skill-authoring Step 2 Rule 5 + stub format note
updated. sync-skeleton Step 4c updated to YAML-aware extraction. Also fixed
pre-existing: discussion-continuity missing from AGENTS.md; README/MASTER_PLAN at v1.50.0.
12 files changed.

## 2026-05-09 — v1.53.1: Fix session-start post-setup + post-merge branch cleanup

setup-skeleton: Step 11 folded into Final Step (was skippable). git-flow:
Post-Merge Cleanup section added (branch -d, remote prune, RESUME update).

## 2026-05-09 — v1.53.0: discussion-continuity skill + task-completion Step 6c

New skill: PAUSE saves topic/agreed/open/gate to Session Notes before switching.
RESUME retrieves on return or "where were we." task-completion Step 6c
hard-enforces resume after every workflow. Gate field prevents treating return
phrase as implementation approval.

## 2026-05-09 — v1.52.0: Session Notes, task capture routing, backlog grooming

RESUME.md Session Notes section (within-session todos). core-behavior.md
Task Capture section (routes "add to todo/backlog" to correct file). janitor
Step 3 backlog grooming (P0/P1/P2 staleness, non-blocking). janitor cd fix.
7 files changed.

## 2026-05-09 — v1.51.1: BACKLOG.md Jira ticket linking column

Added Jira Ticket column to BACKLOG.md template. Blank = local-only intention.
Populated = planned in Jira. Agent prompts for key when Jira configured.
task-completion 6b updated with Jira column guidance.

## 2026-05-09 — v1.51.0: Shared BACKLOG.md — persistent task queue

New core/memory/BACKLOG.md (P0/P1/P2 table + Done). session-start line-count
check. task-completion Step 6 split (6a RESUME + 6b BACKLOG sync). setup-skeleton
creates on install + fixes cd .memory pattern. sync-skeleton Step 5i migration.
11 files changed.

## 2026-05-09 — v1.50.2: Fix setup-skeleton Step 9: checkout default branch after PR push

Main worktree stayed on chore/setup-skeleton after workflow ended — caused
fatal errors on branch deletion and ai-memory worktree checkout downstream.
Added git checkout [DEFAULT_BRANCH] after gh pr create in Step 9.
Files: roles/dev/workflows/setup-skeleton.md, .agents/workflows/setup-skeleton.md.

## 2026-05-09 — v1.50.1: Fix pre-memory-push hook rebase-pull on already-integrated remote

Hook ran pull --rebase unconditionally. After a merge commit, the rebase
conflicted on old commits already resolved by the merge. Fix: skip pull when
merge-base --is-ancestor confirms remote is already in HEAD.
Files: .claude/hooks/pre-memory-push.sh, core/claude-hooks/pre-memory-push.sh.
Also: updated CONFIG.md Last Dependency Check to 2026-05-09 (check-dependencies
ran on empty dep list — agentskel has no code dependencies).
## 2026-04-24 — v1.50.0: Static validator + CI

Added `scripts/validate.py` with five deterministic checks (frontmatter shape,
single-line descriptions, version consistency, stub parity, changelog
presence) and `.github/workflows/validate.yml` to run them on every push and
PR. Validates 244 items on the clean v1.50.0 repo. CONTRIBUTING.md gains a
Validation section and the validator step in the PR checklist. Exactly
catches v1.49.3's stub-truncation class of bug before landing. Not a
replacement for installation integration tests or behavioral compliance —
those are future tiers.

## 2026-04-23 — v1.49.3: Fix skill stub truncation + task-completion over-trigger

Two root-cause bugs: (1) multi-line YAML descriptions in 37 source files were
getting truncated by stub/catalog regeneration, so downstream `.claude/skills/`
stubs had cut-off descriptions and Claude couldn't discover skills like
codebase-navigator. (2) task-completion mandate said "any development task",
firing on pure discussion. Fixed both at source — collapsed descriptions,
added pre-commit lint to prevent recurrence, rewrote mandate with precise
file-based trigger, added Step 0 Applicability Gate to the skill, made
publish-adr/publish-postmortem explicitly bypass the gate for their external
Confluence effects. Sync-skeleton gained Step 4c to refresh Claude stubs and
enforcement hooks (previously never regenerated after setup).

## 2026-04-23 — v1.49.2: Fix pre-memory-push hook blocking first downstream push

Downstream setup failed because `pre-memory-push.sh` tried to rebase pull from
`origin/ai-memory` before the remote branch existed. Added a `ls-remote` check
to skip the pull when the remote branch is absent. Self-synced to
`.claude/hooks/pre-memory-push.sh`.

## 2026-04-21 — v1.49.1: README + MASTER_PLAN updates for v1.49.0

Added "Connect to the tools your team already uses" section to README so new
users discover the Atlassian integration. Added design principle #14
(three-layer knowledge model) to MASTER_PLAN. No code/workflow changes —
documentation catch-up for v1.49.0.

## 2026-04-21 — v1.49.0: Atlassian integration + team coordination

Added 3-layer knowledge model (.memory/, Jira, Confluence) with MCP-based
integration. 2 new memory templates (TEAM.md, JIRA_WORKFLOW.md), 2 new skills
(atlassian-integration, knowledge-routing), 10 new workflows (5 team +
2 Jira + 3 Confluence), integration hooks into 6 existing workflows. All
additions opt-in per integration; GitHub and Atlassian MCP both optional.
New docs: ATLASSIAN-SETUP.md, TEAM-COORDINATION.md. Templates generic (no
company-specific content).

## 2026-04-18 — v1.48.1: README simplification + INSTALL-MODES doc

Simplified README for first-time users: removed framework jargon from
early sections, kept Getting started to 3 plain-language questions.
New docs/INSTALL-MODES.md with ASCII diagrams showing shape (not
filesystem) of each setup. Detailed content moved out of README.

## 2026-04-18 — v1.48.0: workspace dispatcher install mode

New install mode for workspaces with multiple independent projects. Workspace
root becomes a thin routing dispatcher; each subdir retains its own independent
install. 8 new templates in core/workspace-templates/, 4 new workflows
(setup-workspace, add/remove/sync-workspace-*), setup-skeleton Step 0 + 9b,
session-start hook workspace detection, README Install modes section,
MASTER_PLAN principle #13. Monorepo explicitly not supported.

## 2026-04-17 — v1.47.0: semver three-part versioning

Moved VERSION to X.Y.Z format. Updated skeleton-contribution-checklist and
core-behavior to classify MAJOR/MINOR/PATCH. Pre-commit hook regex handles both
X.Y and X.Y.Z during transition. Going forward every change is classified.
Files: core/skills/task-completion/skeleton-contribution-checklist.md,
core/rules/core-behavior.md, core/claude-hooks/pre-commit-check.sh,
.agents/ copies, VERSION, README, MASTER_PLAN.

## 2026-04-17 — v1.46: pre-commit hook fixes (false positives + wall-clock)

Hook now explicitly checks command is `git commit` (not `git log`, `git status`).
Removed `--since="8 hours ago"` wall-clock dependency — replaced with last-commit
or dirty-files check (works across day boundaries). Replaced GNU-only grep -oP
with portable grep -oE for macOS compatibility.
Files: core/claude-hooks/pre-commit-check.sh, core/claude-hooks/pre-memory-push.sh,
.claude/hooks/ copies. Reported by downstream Muslim-Pro-Android agent.

## 2026-04-17 — v1.45: cross-tool enforcement hooks + GEMINI.md condensed rules

Enforcement hooks (pre-commit, pre-push, stop) now have templates for all 5 tools.
GEMINI.md upgraded from thin wrapper to condensed rules inline. setup-skeleton
Step 5b3 installs hooks for all supported tools.
Files: 4 new core/*-hooks/ directories, GEMINI.md template + self-install,
setup-skeleton updated.

## 2026-04-17 — v1.42: subagent dispatch simplification

Rewrote subagent-dispatch skill: parent passes plan steps instead of templates.
Deleted prompts/ directory. Changed "consider" to "use" in workflows. Added
mandatory review dispatch to develop-feature Phase 4.
Files: core/skills/subagent-dispatch/SKILL.md, prompts/ deleted, 3 workflows updated.

## 2026-04-17 — v1.41: session-start context optimization

VERSIONS.md removed from session-start (loaded by workflows instead). RESUME.md
partial read up to --- marker. NEEDS_REVIEW.md line-count check instead of full read.
RESUME.md template restructured with deferrable sections below marker.
Files: core/skills/session-start/SKILL.md, core/memory/RESUME.md, .agents/ copies.

## 2026-04-17 — v1.40: stop hook precision + NEEDS_REVIEW triage escalation

Stop hook no longer triggers for pure analysis/discussion sessions. Cartographer
Step 9 now creates a TECH_DEBT entry for untriaged NEEDS_REVIEW items so triage
surfaces when asking "what's pending?" Removed erroneous analysis CHANGELOG entry.
Files: core/claude-hooks/settings.json, roles/dev/workflows/cartographer.md,
.claude/settings.json, .agents/workflows/cartographer.md.

## 2026-04-16 — Session summary: v1.34→v1.39 (5 releases in one session)

Complete session scope: native-first rule delivery architecture, enforcement hooks,
operational audit, and iterative hook hardening.

- **v1.34**: Architecture change — rules moved to native auto-load locations
  (.claude/rules/, AGENTS.md inline, condensed in Cursor/Windsurf/Copilot).
  Pre-commit hook blocks commits without CHANGELOG/TIME_LOG. Stop hook verifies
  task-completion. 10 skill-wiring gaps fixed across 7 workflows. 45 files changed.
- **v1.37**: INSTALL.md for issue #30 (manual install for Cursor/Copilot/Windsurf/Codex).
- **v1.38**: Pre-memory-push hook (auto-pull before ai-memory push). Operational
  audit found 30+ gaps: pre-commit 1h window, task type mismatch, error suppression,
  race conditions, missing recovery paths.
- **v1.39**: Hook hardening — VERSION/README/MASTER_PLAN consistency check, 8h session
  window, pull error reporting, dirty worktree detection.
- **Context load analysis**: measured startup cost (~1,400 tokens small project,
  ~1,800 large). Identified 17-41% savings via deferred loading of RESUME, VERSIONS,
  LESSONS, NEEDS_REVIEW, and partial MAP reads. Queued for implementation.

Compliance baseline measured on Muslim-Pro-Android: 0/6 bug fixes had CHANGELOG
or TIME_LOG entries. After hooks: deterministically enforced (100%).

## 2026-04-16 — v1.39: hook hardening

Pre-commit hook now checks VERSION/README/MASTER_PLAN version consistency for
skeleton repos. Catches the version drift that was missed every release since v1.34.
Session window widened from 1 hour to 8 hours. Pre-memory-push hook no longer
suppresses pull errors with || true.

## 2026-04-16 — v1.38: enforced auto-pull before ai-memory push + operational audit

New PreToolUse hook (pre-memory-push.sh) auto-runs git pull --rebase before any
push to ai-memory. Comprehensive operational audit identified 30+ gaps across
git operations, race conditions, hook logic, and error handling. Critical findings:
pre-commit hook 1-hour window causes false positives on long sessions, hook doesn't
distinguish development vs analysis tasks, pre-memory-push suppresses errors with
|| true. These are queued for immediate fix.

## 2026-04-16 — v1.38: enforced auto-pull before ai-memory push

New PreToolUse hook (pre-memory-push.sh) auto-runs git pull --rebase before any
push to ai-memory. Prevents the non-fast-forward conflicts that happened when
this session tried to push after another agent had pushed v1.35/v1.36. Hook fires
at the transport layer — agents cannot skip it.

## 2026-04-16 — v1.37: INSTALL.md for issue #30

Created INSTALL.md with manual installation instructions for Cursor, Copilot,
Windsurf, and Codex CLI. Resolves issue #30 (INSTALL.md referenced in README
but missing). VERSION bumped to 1.37, CHANGELOG entry added.

## 2026-04-15 — v1.34: native-first rule delivery + enforcement hooks

Architecture change: rules moved from `.agents/rules/` (not auto-loaded) to each
tool's native auto-load location. Measured baseline: 0/6 bug fixes on Muslim-Pro-Android
had CHANGELOG or TIME_LOG entries. Root cause: 3-hop instruction chain with ~34% compliance.
Changes: `.claude/rules/` (3 files auto-loaded), AGENTS.md self-contained with rules
inline, condensed rules in Cursor/Windsurf/Copilot configs, pre-commit hook blocks
commits without CHANGELOG/TIME_LOG, Stop hook verifies task-completion, 10 skill-wiring
gaps fixed across 7 workflows. 45 files changed.

## 2026-04-16 — v1.36: fix sync-skeleton cd .memory directory bleed

Step 5 used `cd .memory && git ... && cd ..`. Bash tool persists CWD between
calls — if cd + push are in one call, the next call starts inside .memory/ on
the ai-memory branch, causing `gh pr create` to open PRs from ai-memory instead
of the project branch. Fixed by replacing all `cd .memory` / `cd ..` with
`git -C .memory` throughout Step 5. Added explicit warning callout block.
Files: roles/dev/workflows/sync-skeleton.md, .agents/workflows/sync-skeleton.md.
Note: Bug 2 (pre-commit hook worktree detection) was already fixed in v1.35.
Downstream projects need sync-skeleton run to receive both fixes.

## 2026-04-16 — v1.35: fix pre-commit hook worktree detection

Bug: pre-commit-check.sh used `git branch --show-current` at project root, which always
returns `main` — so `.memory/` commits (ai-memory branch) were never skipped by the guard.
Fix: three-pronged detection — check project root branch, check `.memory` worktree branch
via `git -C .memory branch --show-current`, and grep commit command string for `.memory`.
Files: .claude/hooks/pre-commit-check.sh, core/claude-hooks/pre-commit-check.sh.
Also corrected CONFIG.md Skeleton Version 1.33 → 1.34 (was stale from previous session).

## 2026-04-12 — v1.31: refactor-code + CSO fixes + session-start mandate

Added refactor-code workflow (4-phase safe restructure with test safety net gate).
Sharpened CSO descriptions for systematic-debugger (techniques vs process) and
domain-expert (removed [TODO] placeholder). Wired task-planner into develop-feature
Phase 1. Fixed session-start mandate missing from tool config files — Claude Code,
Cursor, Copilot, and Windsurf all load their config eagerly but read AGENTS.md
lazily, so the mandate was never seen. Added "Session Start — MANDATORY" block
directly to all 5 tool config files and their core/ templates. sync-skeleton
propagates this to downstream projects automatically.
Files: core/CLAUDE.md.template, core/GEMINI.md.template, core/cursor-rule.mdc.template,
core/copilot-instructions.md.template, core/windsurf-rule.md.template + installed copies.

## 2026-04-11 — v1.30: brainstorm, TDD, systematic-debugger, git-worktrees

Added 2 workflows (brainstorm-feature, debug-issue), 3 skills (test-driven-development,
systematic-debugger, using-git-worktrees). Patched develop-feature Phase 2 with TDD
recommendation. git-flow gained worktree quick-reference. Bumped VERSION to 1.30,
CONFIG.md Skeleton Version to 1.30. All self-sync locations updated including
roles/dev/workflows/ and roles/dev/skills/ sources.

## 2026-03-19 — Initial agentic setup via setup-skeleton workflow

Installed agentskel on itself (dogfooding). Created memory files, .agents/ structure
with rules, all 13 workflows, 5 standards, 8 skills, CLAUDE.md, GEMINI.md,
.claudeignore, CODEOWNERS, and install-agent.sh.
