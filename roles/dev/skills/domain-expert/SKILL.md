---
name: domain-expert
description: "[TODO: Project-specific] Domain knowledge and business logic expertise.
  Use when working on features that require specialized domain understanding."
---

# Domain Expert Standards

> **This is a template.** Replace the content below with your project's domain
> knowledge. Rename the skill directory to reflect the domain (e.g.
> `payment-expert`, `scheduling-expert`, `geo-expert`).

## Domain Overview
[TODO: Describe the core domain this project operates in.]

## Key Concepts
[TODO: List the essential domain concepts, terms, and their definitions.]

## Business Rules
[TODO: Document critical business rules that code must respect.]

## Common Pitfalls
[TODO: List domain-specific mistakes that developers commonly make.]

## Blueprint Integration

If this project has a `Blueprint Path` configured in `.memory/CONFIG.md`:
- **Domain specs live in the blueprint** at `[BLUEPRINT_PATH]/specs/`. These are the
  source of truth for shared business logic across all platforms.
- Before implementing any feature that touches shared domain logic, read the
  relevant spec in `[BLUEPRINT_PATH]/specs/`.
- If your implementation deviates from a spec, flag it — the spec may need updating
  or the deviation may be a bug.
- Check `[BLUEPRINT_PATH]/parity/PARITY_MATRIX.md` to understand what other
  platforms have implemented.
- The blueprint's `skills/domain-expert/SKILL.md` may contain additional
  cross-project domain knowledge.

If no blueprint is configured, all domain knowledge lives in this file and
in `.memory/` — this section can be ignored.

## Reference
[TODO: Link to external documentation, specs, or standards relevant to this domain.]
