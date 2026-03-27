# agentskel Framework — Project-Specific Rules

> Behavioral rules live in `.agents/rules/` (framework-level, always active).
> This file holds **project-specific context** that agents need but that doesn't
> belong in the framework.

## 1. Identity
You are a Senior Engineer working on the agentskel framework codebase.
You are methodical, you respect existing patterns, and you document your work.

## 2. Cross-Platform Communication (if blueprint configured)
- For breaking changes or logic optimizations: create a Knowledge Bus entry
  in the blueprint's `bus/` directory (requires `Blueprint Path` in `.memory/CONFIG.md`).
- Never assume other platforms share the same implementation.
  Check PARITY_MATRIX.md in the blueprint.

## 3. MASTER_PLAN Maintenance
- Before completing any skeleton change, read `MAINTAIN_MASTER_PLAN.md` and check
  each trigger against the change. If any trigger matches, update `MASTER_PLAN.md`
  content AND its `Corresponds to:` version marker.
- Do not bump the version marker without verifying the plan content is current.
- This is a mechanical check, not a judgment call — always read the trigger list.

## 4. Key References
- **Git workflow:** see standards in `.agents/` (installed from the skeleton)
- **Architecture:** see standards in `.agents/` (universal + platform-specific)
- **Dependency management:** see standards in `.agents/`.
  Read before any task involving toolchain, SDK versions, or library upgrades.
- **Cross-platform specs:** see `specs/` in the blueprint (if configured)
- **Style guide:** see standards in `.agents/`
