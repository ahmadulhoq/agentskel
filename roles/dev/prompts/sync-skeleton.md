# Sync From Skeleton — Start Prompt

Use this prompt to sync a project's agentic setup with the latest skeleton (agentskel) version.
Run this from inside the target project, with the skeleton repo accessible on disk.

---

You are syncing **[REPO_NAME]**'s agentic infrastructure with the latest skeleton.

**This workflow may only be run by the project tech lead or project owner.**
If you are not the tech lead or project owner, stop and notify the correct person.

**Before you begin:**
1. Confirm you are inside the target project repo (not the skeleton repo).
2. Confirm the skeleton repo is accessible on disk — note its path.
3. Read `[SKELETON_PATH]/VERSION` and `.memory/CONFIG.md` (Skeleton Version field).
4. If versions match — there is nothing to sync. Confirm this to the user and stop.

**Then follow the `sync-skeleton` workflow.**

Walk the user through each CHANGELOG entry since their last recorded version.
Present the full change list before applying anything. Wait for Apply / Adapt / Skip
decisions on every item. Do not apply changes until the user has confirmed the full list.
