---
name: skill-authoring
description: When creating a new skill or workflow, or improving an existing skill's
  effectiveness. Use when the user asks to add a capability, write a new workflow,
  or when a skill isn't triggering or being followed reliably.
---

# Skill Authoring Guide

**Purpose:** Create skills that agents actually discover, trigger, and follow.

---

## Step 1 — Skill Anatomy

Every skill is a `SKILL.md` file with this structure:

```yaml
---
name: kebab-case-name
description: CSO-optimized triggering description (see Step 2)
---
```

Body conventions:
- **Numbered steps** with checkboxes (`- [ ]`) for trackable progress
- **Gates** at the end: "Do not [proceed/respond] until all steps above are checked off."
- **Tables over prose** — faster to parse, lower token cost
- One skill = one responsibility. If it does two things, split it.

---

## Step 2 — CSO: Write Discoverable Descriptions

The `description` field determines whether agents find your skill. Agents match
skills to situations by scanning descriptions.

**Rules:**
1. Describe **triggering conditions**, not workflow summaries
2. Use the language a user would use in their request
3. Start with "When..." or include "Use when..."
4. Include the scenario, not the mechanism

| Bad (summary) | Good (triggering condition) |
|---|---|
| "Maps the codebase into MAP.md and SYMBOLS.md" | "When codebase structure has changed, MAP.md/SYMBOLS.md are missing or stale, or after major refactors and initial setup." |
| "Full feature development workflow" | "When the user asks to implement a new feature end-to-end requiring planning, branch creation, implementation, testing, and PR." |
| "Monthly maintenance tasks" | "When Knowledge Bus entries are older than 30 days, or memory files have stale content. Run monthly or when bus/ is cluttered." |

**Test:** Read the description out of context. Can you tell *when* to use this skill
without reading the body? If not, rewrite it.

---

## Step 3 — Rationalization Resistance

Enforcement-critical skills (gates, mandatory procedures) need a rationalization
table. Agents will try to skip steps. Anticipate and block the excuses.

**Format:**

```markdown
## Common Rationalizations

| Rationalization | Why it's wrong | Do this instead |
|---|---|---|
| "I already know this" | You don't. Context was reset. | Follow the procedure. |
```

**How to write entries:**
1. Run the skill mentally. At each step, ask: "What excuse would an agent make to skip this?"
2. Write the excuse in the agent's voice ("I already...", "This is too...", "The user said...")
3. Write a short, direct rebuttal — address the specific excuse, not a generic "follow the rules"
4. Write the correct action in imperative form

**When to include:** Any skill with a Gate statement, mandatory steps, or "do not skip"
language. Not needed for advisory skills (developer, domain-expert).

Target 6-12 entries per enforcement skill. Cover the most tempting shortcuts.

---

## Step 4 — Token Budget

Every skill loads into the agent's context window. Respect the budget.

- **Target:** Under 200 lines for skill body (excluding frontmatter)
- **Tables over prose** — a 5-column table conveys more than 5 paragraphs
- **No filler** — cut "it is important to note that." Just state the rule.
- **No redundancy** — if core-behavior already says it, don't repeat it
- **Measure:** Count lines before finalizing. If over 200, compress or split.

---

## Step 5 — Quality Gates

Before finalizing a new or modified skill, verify all items:

- [ ] **CSO description** — uses triggering conditions, not summary
- [ ] **Numbered steps** — body uses numbered steps with checkboxes
- [ ] **Gate statement** — present at the end (if enforcement-critical)
- [ ] **Rationalization table** — present (if enforcement-critical)
- [ ] **Token budget** — under 200 lines
- [ ] **No duplication** — doesn't repeat what core-behavior or another skill already covers
- [ ] **Self-sync complete** — all 5 locations updated (see Step 7)

---

## Step 6 — Testing a Skill

1. **Baseline test:** Imagine (or run) the agent doing the task *without* the skill.
   Note the failures — what does the agent skip, get wrong, or rationalize away?
2. **Write the skill** to close those specific gaps.
3. **Verify:** Does each baseline failure have a corresponding step, rule, or
   rationalization counter in the skill?
4. **Iterate:** If the agent still skips a step, strengthen the gate or add a
   rationalization entry. Don't add more content — sharpen what exists.

---

## Step 7 — Self-Sync Checklist

Every skill change must update all 5 locations. Missing any causes drift.

| # | Location | Purpose |
|---|---|---|
| 1 | `core/skills/X/SKILL.md` (or `roles/dev/skills/X/`) | Source of truth (template) |
| 2 | `.agents/skills/X/SKILL.md` | Installed copy (project agents read this) |
| 3 | `.claude/skills/X.md` | Claude Code stub (discovery pointer) |
| 4 | `AGENTS.md` Skills/Workflows catalog table | Universal catalog entry |
| 5 | `core/AGENTS.md.template` | Template for downstream projects |

For **workflows**, location 1 is `roles/dev/workflows/X.md` and location 2 is
`.agents/workflows/X.md`. Same sync requirement.

**Stub format** (`.claude/skills/X.md`):
```yaml
---
description: [same CSO description as source SKILL.md]
---

Read and follow the full skill at `.agents/skills/X/SKILL.md`.
```

---

**Gate:** Do not finalize a skill until all quality gates (Step 5) pass and
all 5 self-sync locations (Step 7) are updated.
