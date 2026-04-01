# Session Resume

## Status: IDLE | IN_PROGRESS
IDLE

## Last Completed Task
- v1.27: Renamed senior-developer→developer (agents aren't senior/junior). Extracted skeleton-specific steps from task-completion into skeleton-contribution-checklist.md (50 lines lighter for downstream). Migration step 5f added. PR #27 merged.

## Next Task
- (none)

## Context Notes (Persistent)
- agentskel is the skeleton repo itself — Skeleton Path = `.` in CONFIG.md
- `.agents/` contains copies (not symlinks) of core/ and roles/dev/ files, synced via sync-skeleton
- MASTER_PLAN.md tracked in git since v1.6; MAINTAIN_MASTER_PLAN.md is gitignored (private maintenance checklist)
- roles/devops/ is a placeholder (not implemented)
- CONFIG.md Skeleton Version updated to 1.27
- RULES.md now holds project context + project rules only (behavioral rules in .agents/rules/)
- CONFIG.md has Description field for project identity (moved from RULES.md in v1.18)
- v1.19: All operational timestamps use ISO 8601 UTC format (YYYY-MM-DDTHH:MMZ)
- v1.20: Cartographer indexes ADR sections into MAP.md (step 6b)
- v1.21: AGENTS.md is the universal entry point (AGENTS.md open standard, Linux Foundation). CLAUDE.md/GEMINI.md are thin wrappers. One canonical source (.agents/ + .memory/), many entry points.
- v1.22: Tool configs are opt-in via Supported Tools field. Native thin wrappers for Cursor/Copilot/Windsurf. Only AGENTS.md is unconditional.
- v1.23: Session reload triggers — session-start re-executes after sync, setup, or 24h staleness.
- v1.24: Skill authoring guide (meta-skill) + CSO descriptions for 11 workflows.
- v1.25: Rationalization resistance tables + subagent-dispatch skill with prompt templates.
- v1.26: Plugin-based install (Claude Code, Cursor, Gemini CLI) + session-start hook + README simplification.
- v1.27: Renamed senior-developer→developer. Extracted skeleton checklist from task-completion.

## Cartography State
- Last indexed commit: d417c5cb56c24fc5e997fef5512a41bd9e2aea81
- Coverage target: 122 source files
- [x] core/memory (15 files)
- [x] core/rules (2 files)
- [x] core/skills (3 files)
- [x] core/ root (6 files — AGENTS.md.template, CLAUDE.md.template, GEMINI.md.template, cursor-rule.mdc.template, copilot-instructions.md.template, windsurf-rule.md.template)
- [x] roles/dev/workflows (15 files)
- [x] roles/dev/skills (5 files)
- [x] roles/dev/standards (7 files)
- [x] roles/dev/prompts (8 files)
- [x] roles/devops (1 file)
- [x] .agents/ (30 files — installed copies)
- [x] .claude/skills/ (23 files — auto-generated stubs)
- [x] scripts/ (1 file)
- [x] Root files (12 files — VERSION, CHANGELOG.md, README.md, MASTER_PLAN.md, MAINTAIN_MASTER_PLAN.md, CLAUDE.md, GEMINI.md, AGENTS.md, CONTRIBUTING.md, .gitignore, .claudeignore, LICENSE) + native tool configs (.cursor/rules/agentskel.mdc, .github/copilot-instructions.md, .windsurf/rules/agentskel.md)
- Coverage gate passed — 13 modules complete, 0 remaining.

## Timestamp (UTC)
- 2026-03-30T12:00Z
