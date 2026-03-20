---
name: check-skeleton
trigger: "Check if skeleton is current" / "Check skeleton version" / "Skeleton up to date?"
---

# Mission: Check Skeleton Version

## Pre-flight reads

Before starting, read:
- `.memory/CONFIG.md` — note `Skeleton Version` and `Last Skeleton Check`
- `[SKELETON_PATH]/agent-hq/VERSION` — the current skeleton version

## Goal

Check whether this project's skeleton version is current. If a gap exists, surface the CHANGELOG entries and offer to run `sync-skeleton`.

## Execute

Run the `check-skeleton` workflow from `.agents/workflows/check-skeleton.md`.
