# Workflow: sync-versions

**Trigger:** Run manually after any PR that modifies dependency version files.
**Purpose:** Keep `.memory/VERSIONS.md` in sync with the actual version files in the project.
**Source of truth:** The actual version files (e.g. `libs.versions.toml`, platform-specific files) -> `VERSIONS.md` reflects reality.

---

## Pre-Flight

1. Read `.memory/VERSIONS.md` — current state.
2. Identify which version files exist for this platform (see platform-specific adaptation notes).

---

## Step 1 — Read Actual Version Files

Read all version-controlling files for this platform. For each tracked dependency, note:
- Its current version string
- Which file it lives in

---

## Step 2 — Diff Against VERSIONS.md

Compare what the version files contain against what VERSIONS.md records. Identify:

| Change type | Example |
|---|---|
| **Version bumped** | `retrofit: 2.9.0` in file, `2.8.0` in VERSIONS.md |
| **New dependency added** | In version file but no row in VERSIONS.md |
| **Dependency removed** | Row in VERSIONS.md but not in any version file |

---

## Step 3 — Update VERSIONS.md

For each change:

- **Version bumped**: update `Current` column, set `Last Updated = today`
- **New dependency**: add a new row with `Current`, `Last Updated = today`, `Latest Known = same as Current`, release notes URL (search if unknown), source file, and appropriate notes
- **Dependency removed**: remove the row entirely

Do not change `Latest Known` for unchanged dependencies — that is managed by `check-dependencies`.

---

## Step 4 — Verify

Read back VERSIONS.md and confirm every version in the actual files has a matching row with the correct `Current` value.

---

## Step 5 — Commit

Commit the updated `VERSIONS.md` to the `ai-memory` branch with message:
`agent: sync VERSIONS.md — [brief description of what changed]`

---

## Future Automation

Set up a GitHub Actions workflow (`.github/workflows/sync-versions.yml`) triggered on push to `development` when `libs.versions.toml` or equivalent version files are modified. The action runs this workflow automatically, keeping `VERSIONS.md` perpetually in sync without manual intervention. This is a future improvement — implement when the team is ready to invest in CI tooling.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
