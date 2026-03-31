---
name: parity-check
description: When checking feature parity across platforms after shipping a feature,
  receiving a Knowledge Bus alert, or on a scheduled cadence. Requires a blueprint
  with a parity matrix.
---

# Parity Check Mission

**Trigger:** After a Knowledge Bus alert, or on a scheduled cadence (recommended: bi-weekly).
**Authorization:** Tech lead or platform lead only.
**Prerequisite:** A blueprint must be configured (`Blueprint Path` in `.memory/CONFIG.md`).
If no blueprint is configured, skip this workflow — it is not applicable to single-project teams.

---

## Pre-Flight

1. Read `.memory/CONFIG.md` — confirm `Blueprint Path` is set and the path exists on disk.
   If not set → inform the user this workflow requires a blueprint and stop.
2. Read `.memory/RULES.md`, `.memory/VERSIONS.md`.
3. Read `[BLUEPRINT_PATH]/parity/PARITY_MATRIX.md`.
4. Read the relevant spec(s) from `[BLUEPRINT_PATH]/specs/` or `[BLUEPRINT_PATH]/domain/`.

---

## Step 1 — Compare Implementation Against Spec

For each row in the parity matrix relevant to this platform:

1. Read the spec for the business logic area.
2. Locate the implementation in this repo using `.memory/SYMBOLS.md` and `.memory/MAP.md`.
3. Compare the implementation against the spec.
4. Record:
   - **Deviations** — implementation differs from spec
   - **Missing features** — spec defines behavior not implemented on this platform
   - **Version mismatches** — different library or algorithm versions across platforms

---

## Step 2 — Update Parity Matrix

If any status has changed (new deviation, feature implemented, version aligned):

1. Update `[BLUEPRINT_PATH]/parity/PARITY_MATRIX.md` with current status.
2. Note the date and platform in the update.

---

## Step 3 — Create Knowledge Bus Entries

If action is needed on other platforms:

1. Create a Knowledge Bus entry in `[BLUEPRINT_PATH]/bus/` following the bus entry template.
2. Include: what changed, which platforms are affected, what action is needed.

---

## Step 4 — Report

Present to the user:
- Rows checked in parity matrix
- Deviations found (list each)
- Features missing on this platform (list each)
- Version mismatches (list each)
- Knowledge Bus entries created (if any)
- Parity matrix updated: yes/no

---

## In Phase 4+
This workflow can be automated as a scheduled GitHub Action that runs
weekly and posts results to a dedicated Slack channel.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
