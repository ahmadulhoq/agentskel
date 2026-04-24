# Contributing to agentskel

Skills and workflows are plain Markdown. If you can write a checklist, you can contribute.

---

## What we're looking for

| Type | Examples | Difficulty |
|------|---------|------------|
| **New skill** | `api-designer`, `performance-profiler`, `accessibility-reviewer` | Easy — just Markdown |
| **New workflow** | `migrate-database`, `incident-postmortem`, `onboard-feature` | Medium — multi-step flow |
| **New standard** | Architecture guide for a framework/platform not yet covered | Medium |
| **Bug fix** | Wrong step order, missing gate, broken self-sync | Easy |
| **Role** | A new agent role (e.g. `roles/devops/`, `roles/data/`) | Hard — new territory |

Not sure if your idea fits? Open an issue first. One conversation saves a wasted PR.

---

## Anatomy of a skill

Every skill is a single file: `roles/dev/skills/<name>/SKILL.md`

```markdown
---
name: your-skill-name
description: When [triggering condition]. Use when [scenario in user's words].
---

# Your Skill Name

## Step 1 — Do something
- [ ] Concrete action

## Step 2 — Do something else
- [ ] Concrete action

---

**Gate:** Do not proceed until all steps above are checked off.
```

That's it. The `description` field is what the agent reads to decide whether to load the skill — write it as a triggering condition, not a summary. See [`skill-authoring/SKILL.md`](.agents/skills/skill-authoring/SKILL.md) for the full quality guide.

---

## Self-sync requirement (mandatory)

Every skill or workflow added to `roles/dev/` must be synced to 4 locations. Missing any causes drift in downstream projects.

| # | Location | What to do |
|---|----------|-----------|
| 1 | `roles/dev/skills/<name>/SKILL.md` | Source of truth — your new file |
| 2 | `.agents/skills/<name>/SKILL.md` | Installed copy — identical content |
| 3 | `.claude/skills/<name>.md` | Stub — frontmatter + one-liner pointing to `.agents/` |
| 4 | `AGENTS.md` Skills or Workflows table | One-line catalog entry |

Stub format (`.claude/skills/<name>.md`):
```markdown
---
description: [same description as SKILL.md frontmatter]
---

Read and follow the full skill at `.agents/skills/<name>/SKILL.md`.
```

---

## Version and changelog rules

Every change to a template, workflow, standard, or skill must:

1. Bump `VERSION` — minor bump for additions, major for breaking changes
2. Add an entry to `CHANGELOG.md`
3. If breaking: add a migration step to `sync-skeleton.md` (Step 5x pattern)

No exceptions. This is how downstream projects detect they're out of sync.

---

## What belongs here vs. a blueprint

**Here (agentskel — the skeleton):**
Skills, workflows, and standards that apply to *any* project on *any* tech stack.

**Your blueprint (your team's domain repo):**
Domain-specific skills, API contracts, business logic, cross-platform specs. Don't put Muslim Pro prayer times or Acme Corp payment flows here.

---

## Validation

Run `python3 scripts/validate.py` before opening a PR. It runs six deterministic checks:

- **frontmatter shape** — every SKILL.md and workflow has valid YAML with `description:` (and `name:` on skills)
- **single-line descriptions** — descriptions don't fold across YAML lines (required for stub and catalog generation)
- **version consistency** — VERSION matches README, MASTER_PLAN, and `.memory/CONFIG.md`
- **stub parity** (Claude-specific) — `.claude/skills/*.md` stubs reflect current `.agents/` sources (no orphans, no missing, no description drift)
- **AGENTS.md catalog parity** (universal) — the Skills/Workflows tables in `AGENTS.md` reflect current `.agents/` sources. Feeds every non-Claude tool (Cursor, Copilot, Windsurf, Codex, Gemini).
- **changelog entry** — `CHANGELOG.md` has a section for the current VERSION

CI runs the same validator on every push and PR. A green local run should mean a green CI run.

## Opening a PR

1. Fork → branch (`feat/skill-name` or `fix/what-you-fixed`)
2. Check the self-sync table above — all 4 locations updated?
3. Run through the [`skill-authoring`](.agents/skills/skill-authoring/SKILL.md) quality gates
4. Run `python3 scripts/validate.py` — fix any failures
5. Open PR with: what it does, when it triggers, what problem it solves

---

## Code of conduct

Be direct. Be constructive. We're all here to make AI agents less annoying and more useful.
