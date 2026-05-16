# Skeleton Contribution Checklist

**Applies only when `Skeleton Path` in `.memory/CONFIG.md` is `.` (this IS the skeleton repo).**
Skip this entire file for downstream projects.

---

## VERSION + Config

Use semver (MAJOR.MINOR.PATCH):
- **MAJOR** — breaking changes that require downstream migration (renamed skills,
  restructured directories, changed workflow contracts). Example: 1.x → 2.0.0.
- **MINOR** — new features, new workflows/skills, architectural improvements that
  don't break existing use. Example: 1.46 → 1.47.0.
- **PATCH** — bug fixes, hook corrections, doc fixes, tweaks that don't change
  behavior. Example: 1.47.0 → 1.47.1.

- [ ] Classify the change as MAJOR / MINOR / PATCH.
- [ ] Bump `VERSION` accordingly (three-part format: X.Y.Z).
- [ ] Update `Skeleton Version` in `.memory/CONFIG.md` to match.
- **Every skeleton file change requires a version bump — no exceptions.**

## CHANGELOG `affected:` line

- [ ] If this change touches any workflow or skill file, append an `affected:` line
      at the end of the CHANGELOG entry (both `CHANGELOG.md` and `.memory/CHANGELOG.md`):
      ```
      affected: workflow-name, skill-name, ...
      ```
      List only the workflow/skill **names** (kebab-case, no paths). Omit the line
      entirely if no workflow or skill files were changed.
- This field is machine-read by `sync-skeleton` to notify downstream projects which
  workflows/skills were updated.

## README

- [ ] If this task changed something **already mentioned** in `README.md`
      (workflow count, role description, architecture overview) → update README.
- Only update for user-facing structural changes. Not for internal fixes or rewording.

## Migration Step

- [ ] If this was a **MAJOR** bump (breaking change) → add a migration step in
      `sync-skeleton.md` with exact commands and file changes for downstream adoption.
- [ ] If this was a **MINOR** bump that adds new files/directories → add a migration
      step if downstream projects need to create those files.
- [ ] **PATCH** bumps don't require migration steps — they fix existing behavior.
- **MAJOR bumps: mandatory migration step.** Without it, downstream syncs will fail.

## MASTER_PLAN

- [ ] Read `MAINTAIN_MASTER_PLAN.md` and check triggers:
      added/removed/renamed workflow/skill/prompt/standard, changed install/setup path,
      added/removed role, changed core/ vs roles/ boundaries, changed .memory/ schema,
      modified blueprint integration, changed architecture decisions.
- [ ] State which triggers matched and which did not.
- [ ] If any matched → update `MASTER_PLAN.md` per `MAINTAIN_MASTER_PLAN.md`.
- [ ] Update `Corresponds to:` version marker to match new VERSION.

## Self-Sync Verification

- [ ] For every file changed under `core/` or `roles/`, confirm the `.agents/` copy
      is identical. If any diff is non-empty, copy source to `.agents/` in the same commit.
- [ ] Confirm `.memory/CONFIG.md` `Skeleton Version` matches `VERSION` file.
- **Gate.** Do not commit until both checks pass.
