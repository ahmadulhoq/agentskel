# Skeleton Contribution Checklist

**Applies only when `Skeleton Path` in `.memory/CONFIG.md` is `.` (this IS the skeleton repo).**
Skip this entire file for downstream projects.

---

## README

- [ ] If this task changed something **already mentioned** in `README.md`
      (workflow count, role description, architecture overview) → update README.
- Only update for user-facing structural changes. Not for internal fixes or rewording.

## Migration Step

- [ ] If this task bumped `VERSION` with a **breaking change** (MAJOR version) →
      ensure a corresponding migration step exists in `sync-skeleton.md`.
- [ ] The migration step must include exact commands and file changes for downstream adoption.
- **Mandatory for breaking changes. Without it, downstream syncs will fail.**

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
