# Project Map: agentskel
> Last updated: 2026-06-07T20:00Z by Cartographer Agent (refresh — see RESUME Cartography State for indexed HEAD SHA)

## Architecture Pattern
- Pattern: Framework — skeleton templates + role-based workflows/skills/standards
- Two components: Skeleton (always required) + Blueprint (optional, multi-project teams)
- Install model: Templates in `core/` and `roles/` are copied to downstream projects during setup
- Memory model: Orphaned `ai-memory` git branch mounted as worktree at `.memory/`
- Tool entry points (each tool reads its own native files; all chain back to AGENTS.md):
  - `AGENTS.md` — universal entry point (Codex CLI reads natively; thin wrappers point at this)
  - `CLAUDE.md` + `.claude/rules/` + `.claude/skills/<name>/SKILL.md` + `.claude/hooks/` + `.claude/settings.json` (Claude Code, per `.claude-plugin/plugin.json`)
  - `GEMINI.md` + `.gemini/skills/<name>/SKILL.md` + `.gemini/hooks/` + `gemini-extension.json` (Gemini CLI / Antigravity)
  - `.cursor/rules/<name>.mdc` (per-skill agent-requested) + `.cursor/rules/agentskel.mdc` (always-on core) + `.cursor/hooks.json` (Cursor)
  - `.windsurf/rules/agentskel.md` + `.windsurf/workflows/<name>.md` (slash-invokable) + `.windsurf/hooks.json` (Windsurf)
  - `.github/copilot-instructions.md` + `.github/prompts/<name>.prompt.md` (GitHub Copilot — no hooks support)
  - `.codex/hooks.json` + `.agents/skills/` (upward auto-discovery) (Codex CLI)
  - `.agent` symlink → `.agents/` — **legacy compat path**; current Gemini docs only mention `.agents/` plural, but the singular symlink stays for any older installs that may still reference it.
- DI: N/A
- Navigation: N/A
- UI: N/A (markdown/shell)

## Module Registry

| Module | Responsibility | Key Entry Points |
|--------|---------------|-----------------|
| `core/memory/` | 18 memory file templates — project identity, codebase map, session state, conventions, tech debt, dependency tracking, team roster, Jira workflow, backlog | CONFIG.md, RULES.md, MAP.md, SYMBOLS.md, RESUME.md, TEAM.md, JIRA_WORKFLOW.md, BACKLOG.md |
| `core/rules/` | 2 always-on agent behavior rules | core-behavior.md, security-non-negotiables.md |
| `core/skills/` | 9 procedural skills — mandatory lifecycle and meta-capabilities | session-start, task-completion, git-flow, codebase-navigator, skill-authoring, subagent-dispatch, atlassian-integration, knowledge-routing, discussion-continuity |
| `core/claude-rules/` | 3 Claude-specific rule files (auto-loaded by Claude Code) | core-behavior.md, security.md, bootstrap.md |
| `core/claude-hooks/` | 5 enforcement scripts + Claude settings template | pre-commit-check.sh, pre-memory-push.sh, pre-edit-check.sh, stop-verify.sh, settings.json |
| `core/cursor-hooks/` | 4 Cursor-format hook scripts + hooks.json | pre-commit-check.sh, pre-memory-push.sh, pre-edit-check.sh, stop-verify.sh, hooks.json. Cursor's I/O contract is `command` at top of stdin JSON + `{permission,user_message,agent_message}` JSON on stdout (v1.62.0). |
| `core/gemini-hooks/` | 4 Gemini-format hook scripts + settings.json | pre-commit-check.sh, pre-memory-push.sh, pre-edit-check.sh, stop-verify.sh, settings.json. Gemini's I/O contract is `tool_input.command` stdin + JSON-only stdout (v1.61.0). |
| `core/windsurf-hooks/` | 4 Windsurf-format hook scripts + hooks.json | pre-commit-check.sh, pre-memory-push.sh, pre-edit-check.sh, stop-verify.sh, hooks.json. Windsurf's I/O contract is `tool_info.command_line` stdin + stderr-based blocking (v1.62.2). |
| `core/codex-hooks/` | Codex hook config (scripts sourced from core/claude-hooks/, verified compatible) | hooks.json. Codex's I/O contract matches Claude's (`tool_input.command` + exit-code blocking). |
| `core/copilot-hooks/` | **DELETED in v1.62.0** — GitHub Copilot has no hooks concept. | — |
| `core/workspace-templates/` | 7 workspace dispatcher templates (workspace install mode) | dispatcher AGENTS.md, CLAUDE.md, GEMINI.md, claude-rules/routing.md, cursor/windsurf rules |
| `core/` (root) | Entry point templates and shared registries | AGENTS.md.template, CLAUDE.md.template, GEMINI.md.template, cursor-rule.mdc.template, copilot-instructions.md.template, windsurf-rule.md.template, condensed-rules.md, external-skills.yml |
| `roles/dev/workflows/` | 33 dev workflows — multi-step missions triggered by user | setup-skeleton, cartographer, develop-feature, implement-task, sync-skeleton, brainstorm-feature, debug-issue, refactor-code, hotfix, fix-tech-debt, cut-release, janitor, check-dependencies, check-skeleton, sync-versions, update-conventions, parity-check, create-blueprint, publish-adr, publish-postmortem, setup-team, add/remove/update-team-member, sync-team-from-github, setup-jira, implement-from-ticket, setup-confluence, setup-workspace, add/remove-workspace-platform, sync-workspace-dispatcher, update-external-skills |
| `roles/dev/skills/` | 8 domain skills — specialist agent knowledge | developer, code-reviewer, test-engineer, task-planner, domain-expert, test-driven-development, systematic-debugger, using-git-worktrees |
| `roles/dev/standards/` | 7 standards — architecture, style, git, dependency, API, platform-specific architecture | ARCHITECTURE.md (multi-platform with markers), STYLE_GUIDE.md, GIT_WORKFLOW.md, DEPENDENCY_MANAGEMENT.md, API_CONTRACT.md, ANDROID_ARCHITECTURE.md, IOS_ARCHITECTURE.md |
| `roles/dev/prompts/` | 8 mission start prompts — context-setting for workflows | cartographer, develop-feature, setup-skeleton, sync-skeleton, code-review, check-skeleton, update-conventions, parity-check |
| `roles/devops/` | Placeholder for future DevOps role | README.md (planned: deployment, monitoring, incident response) |
| `.agents/` | Installed copy of rules, workflows, skills, standards (self-install for dogfooding) | Mirrors core/ and roles/dev/ — kept in sync via sync-skeleton. 17 skills, 33 workflows, 3 rules, 7 standards |
| `.claude/skills/` | 50 auto-generated Claude Code skill stubs in **directory layout** (`<name>/SKILL.md`) | One stub per `.agents/` skill (17) and workflow (33). Pre-v1.60.0 used flat `<name>.md` which Claude silently ignored. |
| `.claude/rules/` | Claude Code native-loaded rules (copies of core/claude-rules) | core-behavior.md, security.md, bootstrap.md |
| `.claude/hooks/` | Installed Claude hook scripts (copies of core/claude-hooks) | pre-commit-check.sh, pre-memory-push.sh, pre-edit-check.sh, stop-verify.sh |
| `.claude-plugin/` | Plugin manifest for Claude Code `/plugin install` | plugin.json (tracks agentskel version) |
| `.gemini/skills/` | 50 auto-generated Gemini stubs in directory layout | One stub per `.agents/` skill + workflow. Workflows aren't on Gemini's auto-discovery path otherwise (v1.61.0). |
| `.cursor/rules/` | 51 Cursor rules: 1 always-on core (`agentskel.mdc`) + 50 per-skill/workflow stubs with `alwaysApply: false` (agent-requested discovery) | agentskel.mdc + 50 `<name>.mdc` files (v1.62.0) |
| `.cursor/hooks.json` | Cursor hooks at workspace root (NOT `.cursor/hooks/`) | Wires beforeShellExecution / afterFileEdit / stop to scripts in `.cursor/hooks/` (v1.62.0). |
| `.windsurf/rules/` | Always-on Windsurf rule | agentskel.md |
| `.windsurf/workflows/` | 33 first-class Windsurf workflows — `/<name>` slash-invokable | One per `.agents/workflows/` file (v1.62.0) |
| `.windsurf/hooks.json` | Windsurf hooks (uses `pre_run_command` / `pre_write_code` / `post_cascade_response` — Windsurf has no `stop` event) | v1.62.0 + v1.62.2 |
| `.github/copilot-instructions.md` | Always-loaded Copilot instructions | Inline rules: Session Start, Workflow routing, Plan First, Task Completion. |
| `.github/prompts/` | 33 Copilot slash-invokable prompt files — `/<name>.prompt.md` | One per `.agents/workflows/` file. Copilot has no hooks concept (v1.62.0). |
| `docs/` | Setup and coordination docs for users | ATLASSIAN-SETUP.md, INSTALL-MODES.md, PLATFORM-SKILLS.md, TEAM-COORDINATION.md |
| `scripts/` | Developer onboarding + validation | install-agent.sh (mount memory worktree + link external skills); validate.py (10 deterministic checks: frontmatter, descriptions, version consistency across 5 files, parity for 4 tool stub dirs, AGENTS.md catalog parity, CHANGELOG presence) |
| `gemini-extension.json` | Gemini CLI extension manifest at repo root (tracks agentskel version) | Lets users run `gemini extensions install <repo-url>` |
| `root` | Project identity, versioning, ADR, maintenance docs | VERSION, CHANGELOG.md, README.md, MASTER_PLAN.md (ADR), MAINTAIN_MASTER_PLAN.md (gitignored), AGENTS.md, CLAUDE.md, GEMINI.md, CONTRIBUTING.md, INSTALL.md, LICENSE |

## Internal Frameworks / Shared Libraries
| Framework | Responsibility | Used By |
|-----------|---------------|---------|
| Memory system (ai-memory branch) | Persistent agent knowledge across sessions | All workflows and skills |
| Platform markers (`<!-- PLATFORM: X -->`) | Multi-platform content trimming during setup | ARCHITECTURE.md, STYLE_GUIDE.md, DEPENDENCY_MANAGEMENT.md, cut-release.md, senior-developer, code-reviewer, test-engineer |
| Token replacement (`[APP_NAME]`, `[PLATFORM]`, etc.) | Template customization during setup | All core/memory/ templates, CLAUDE.md.template, GEMINI.md.template |

## Critical Business Logic Flows

### Setup Flow (setup-skeleton)
- Entry: `roles/dev/workflows/setup-skeleton.md`
- Flow: Gather inputs → pre-flight checks → create ai-memory branch + worktree → populate memory templates → copy rules/workflows/skills/standards to `.agents/` → generate `.claude/skills/` stubs → create CLAUDE.md + GEMINI.md + .claudeignore + CODEOWNERS + install-agent.sh → commit + open PR

### Sync Flow (sync-skeleton)
- Entry: `roles/dev/workflows/sync-skeleton.md`
- Flow: Check authorization → self-update workflow → read CHANGELOG entries since last sync → classify each (Apply/Adapt/Skip) → create branch → apply changes → update CONFIG.md version → commit + open PR

### Session Lifecycle
- Entry: `core/skills/session-start/SKILL.md`
- Flow: Check .memory/ mount → pull latest ai-memory → read 10 memory files (incl. NEEDS_REVIEW.md) → surface alerts + triage items → check skeleton version → check freshness timestamps → check blueprint (pull latest, detect changes, check Knowledge Bus) → check git state → confirm ready
- Exit: `core/skills/task-completion/SKILL.md`
- Flow: CHANGELOG → SYMBOLS/MAP → TIME_LOG → Knowledge Bus (if blueprint) → README (if agentskel) → Migration Step (if breaking, agentskel) → MASTER_PLAN (if structural, agentskel) → RESUME → memory commit

### Cartography Flow
- Entry: `roles/dev/workflows/cartographer.md`
- Flow: Read memory → record HEAD SHA → enumerate all source files → build module list → tech-stack research → process each module (read files → extract symbols → triage findings → pause for NEEDS_REVIEW) → completion gate → write MAP.md → index ADR sections (step 6b) → map critical flows → populate VERSIONS.md → final commit

### Blueprint Creation Flow
- Entry: `roles/dev/workflows/create-blueprint.md`
- Flow: Gather inputs → pre-flight → create branch → build domain structure (specs/, parity/, bus/) → create CONFIG.md → copy trimmed .agents/ (rules, workflows, skills, standards) → generate .claude/skills/ stubs → create VERSION + CHANGELOG → commit + open PR

### Dependency Management Flow
- Entry: `roles/dev/workflows/check-dependencies.md`
- Flow: Read VERSIONS.md → WebFetch release notes for each dependency → compare versions → apply staleness rules → write TECH_DEBT entries → write DEPENDENCY_ALERTS → update Last Dependency Check

## MASTER_PLAN.md Section Index
<!-- Allows targeted reads via offset/limit instead of reading all 1,037 lines.
     Line ranges updated during cartography. -->

| Section | Lines | Summary |
|---------|-------|---------|
| 1. Vision | 7–19 | Framework purpose — addon for existing projects, scales solo to org |
| 2. Problems We're Solving | 21–32 | 6 problems: session amnesia, scale, staleness, no institutional knowledge, cross-platform drift, standards |
| 3. Architecture Overview | 34–80 | Two components (skeleton + blueprint), three-tool model (Claude Code, Antigravity, future) |
| 4. Project Memory | 82–341 | ai-memory branch, 15 memory files, checkpoint/triage protocols, time logging, freshness/drift detection |
| 5. The Blueprint | 343–515 | Optional team knowledge repo — specs, parity matrix, Knowledge Bus, repo identity |
| 6. Multi-Tool Instruction System | 517–658 | AGENTS.md universal entry point, native tool configs (Cursor/Copilot/Windsurf), context compaction survival, stub pattern, rules/skills/memory interaction |
| 7. Agent Behavior System | 660–824 | Rules (always-on), domain skills (contextual), procedural skills (triggered), workflows (explicit), token budget |
| 8. Git Workflow | 826–847 | Branch naming, commit format, PR conventions |
| 9. Dependency Management | 849–891 | VERSIONS.md, staleness policy, platform-specific architecture standards, CODEOWNERS |
| 10. Orchestration | 893–954 | GitHub Actions (memory maintenance, Knowledge Bus), Slack channels, reviewer agent |
| 11. Adoption Path | 956–1011 | 5 phases: Foundation → Cartographer → Working Agent → Multi-Project → Scale |
| 12. Extension Points | 1013–1024 | Custom skills, blueprint, devops role, GitHub Actions, MCP servers |
| 13. Risk Register | 1026–1037 | 7 risks with likelihood, impact, and mitigation strategies |

## Technical Debt & Notes
- `roles/devops/` — placeholder only, not implemented
- `roles/dev/workflows/cut-release.md` — uses platform markers; during setup, trim to project's platform
- `.agents/` contains copies (not symlinks) of source files from `core/` and `roles/dev/` — synced via sync-skeleton workflow pointing to self (Skeleton Path = `.`)
- `MASTER_PLAN.md` is the core ADR; tracked in git since v1.6; `MAINTAIN_MASTER_PLAN.md` is gitignored (private maintenance checklist)
