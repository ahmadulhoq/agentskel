# Project Map: agentskel
> Last updated: 2026-03-27T15:20Z by Cartographer Agent

## Architecture Pattern
- Pattern: Framework — skeleton templates + role-based workflows/skills/standards
- Two components: Skeleton (always required) + Blueprint (optional, multi-project teams)
- Install model: Templates in `core/` and `roles/` are copied to downstream projects during setup
- Memory model: Orphaned `ai-memory` git branch mounted as worktree at `.memory/`
- Entry points: `CLAUDE.md` (Claude Code), `GEMINI.md` (Antigravity), `.agent` symlink to `.agents/`
- DI: N/A
- Navigation: N/A
- UI: N/A (markdown/shell)

## Module Registry

| Module | Responsibility | Key Entry Points |
|--------|---------------|-----------------|
| `core/memory/` | 15 memory file templates — project identity, codebase map, session state, conventions, tech debt, dependency tracking | CONFIG.md (identity + description), RULES.md (project context + rules), MAP.md (architecture), SYMBOLS.md (symbol index), RESUME.md (session state) |
| `core/rules/` | Always-on agent behavior rules | core-behavior.md (planning, communication, memory protocol, skeleton contribution), security-non-negotiables.md (credentials, validation, least privilege) |
| `core/skills/` | 3 procedural skills — mandatory lifecycle procedures | session-start/SKILL.md (8-step init), task-completion/SKILL.md (7-step post-task with Steps 5b/5c for skeleton repos), git-flow/SKILL.md (branch/commit/PR) |
| `core/` (root) | Entry point templates and secret exclusions | CLAUDE.md.template, GEMINI.md.template, .claudeignore |
| `roles/dev/workflows/` | 15 dev workflows — multi-step missions triggered by user | setup-skeleton.md (install), cartographer.md (map codebase), develop-feature.md (build), implement-task.md (ad-hoc tasks), sync-skeleton.md (update), create-blueprint.md (blueprint setup), check-dependencies.md (staleness), update-conventions.md (best practices) |
| `roles/dev/skills/` | 5 domain skills — specialist agent knowledge | senior-developer, code-reviewer, test-engineer, task-planner, domain-expert |
| `roles/dev/standards/` | 7 standards — architecture, style, git, dependency, API, platform-specific architecture | ARCHITECTURE.md (multi-platform with markers), STYLE_GUIDE.md, GIT_WORKFLOW.md, DEPENDENCY_MANAGEMENT.md, API_CONTRACT.md, ANDROID_ARCHITECTURE.md, IOS_ARCHITECTURE.md |
| `roles/dev/prompts/` | 8 mission start prompts — context-setting for workflows | cartographer.md, develop-feature.md, setup-skeleton.md, sync-skeleton.md, code-review.md, check-skeleton.md, update-conventions.md, parity-check.md |
| `roles/devops/` | Placeholder for future DevOps role | README.md (planned: deployment, monitoring, incident response) |
| `.agents/` | Installed copy of rules, workflows, skills, standards (self-install for dogfooding) | Mirrors core/ and roles/dev/ — kept in sync via sync-skeleton |
| `.claude/skills/` | 23 auto-generated Claude Code stubs for skill/workflow discovery | One stub per skill (8) and workflow (15) |
| `root` | Project identity, versioning, ADR, maintenance docs | VERSION (skeleton version), CHANGELOG.md, README.md, MASTER_PLAN.md (ADR), MAINTAIN_MASTER_PLAN.md (gitignored checklist), CLAUDE.md, GEMINI.md, CONTRIBUTING.md, LICENSE |
| `scripts/` | Developer onboarding | install-agent.sh (mount ai-memory worktree) |

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
<!-- Allows targeted reads via offset/limit instead of reading all 1,019 lines.
     Line ranges updated during cartography. -->

| Section | Lines | Summary |
|---------|-------|---------|
| 1. Vision | 7–19 | Framework purpose — addon for existing projects, scales solo to org |
| 2. Problems We're Solving | 21–32 | 6 problems: session amnesia, scale, staleness, no institutional knowledge, cross-platform drift, standards |
| 3. Architecture Overview | 34–80 | Two components (skeleton + blueprint), three-tool model (Claude Code, Antigravity, future) |
| 4. Project Memory | 82–341 | ai-memory branch, 15 memory files, checkpoint/triage protocols, time logging, freshness/drift detection |
| 5. The Blueprint | 343–515 | Optional team knowledge repo — specs, parity matrix, Knowledge Bus, repo identity |
| 6. Multi-Tool Instruction System | 517–642 | Entry points per tool, context compaction survival, stub pattern, rules/skills/memory interaction |
| 7. Agent Behavior System | 644–806 | Rules (always-on), domain skills (contextual), procedural skills (triggered), workflows (explicit), token budget |
| 8. Git Workflow | 808–829 | Branch naming, commit format, PR conventions |
| 9. Dependency Management | 831–873 | VERSIONS.md, staleness policy, platform-specific architecture standards, CODEOWNERS |
| 10. Orchestration | 875–936 | GitHub Actions (memory maintenance, Knowledge Bus), Slack channels, reviewer agent |
| 11. Adoption Path | 938–993 | 5 phases: Foundation → Cartographer → Working Agent → Multi-Project → Scale |
| 12. Extension Points | 995–1006 | Custom skills, blueprint, devops role, GitHub Actions, MCP servers |
| 13. Risk Register | 1008–1019 | 7 risks with likelihood, impact, and mitigation strategies |

## Technical Debt & Notes
- `roles/devops/` — placeholder only, not implemented
- `roles/dev/workflows/cut-release.md` — uses platform markers; during setup, trim to project's platform
- `.agents/` contains copies (not symlinks) of source files from `core/` and `roles/dev/` — synced via sync-skeleton workflow pointing to self (Skeleton Path = `.`)
- `MASTER_PLAN.md` is the core ADR; tracked in git since v1.6; `MAINTAIN_MASTER_PLAN.md` is gitignored (private maintenance checklist)
