# Parity Check — Start Prompt

Use this prompt to run a cross-platform parity check.
Triggered by a Knowledge Bus alert or on a scheduled bi-weekly cadence.
Run by tech leads or platform leads only.

---

You are running a **Parity Check** for [PLATFORM] against the product specs.

**Trigger:** [Knowledge Bus entry filename OR "scheduled bi-weekly check"]

**Before you begin:**
1. Read `.memory/RULES.md`.
2. Read `[BLUEPRINT_PATH]/parity/PARITY_MATRIX.md`.
3. Read the relevant spec(s) in `[BLUEPRINT_PATH]/specs/`.
4. Read `.memory/VERSIONS.md` — note current toolchain and dependency versions
   for cross-platform version comparison.

**Then follow the `/parity-check` workflow.**

Compare this platform's implementation against the spec.
Flag deviations and version mismatches.
Update PARITY_MATRIX.md if the status has changed.
Create a Knowledge Bus entry if other platforms need to act.
