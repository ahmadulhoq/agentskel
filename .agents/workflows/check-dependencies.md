# Workflow: check-dependencies

**Trigger:** At session start if `Last Dependency Check` in `CONFIG.md` is more than 14 days ago (or absent).
**Purpose:** Detect stale dependencies, surface major version availability, and create tech debt entries.
**Version discovery:** WebFetch only — to the release notes URLs already recorded in VERSIONS.md. Never use web search. Only target stable versions (skip alpha, beta, RC, canary, snapshot, nightly).

---

## Pre-Flight

1. Read `.memory/CONFIG.md` — note `Last Dependency Check` timestamp.
2. Read `.memory/VERSIONS.md` — all tracked dependencies.
3. Read the project's dependency management standard — confirm staleness rules and stable-only policy.
4. If `Last Dependency Check` is within 14 days, **stop** — no action needed. Inform the user the check is current.

---

## Step 1 — Check Key Dependencies

For each dependency in the **Key Dependencies** table of `VERSIONS.md`:

1. WebFetch the release notes URL recorded in the `Release Notes` column.
2. Parse the page for the latest **stable** version. Skip any version containing: `-alpha`, `-beta`, `-rc`, `-canary`, `-snapshot`, `-nightly`, `-dev`, `-eap`.
3. Record:
   - `latest_stable` — the parsed stable version
   - `current` — from `VERSIONS.md`
   - `bump_type` — `patch`, `minor`, `major`, or `none`
   - `is_security` — flag if release notes mention a security fix in this version
4. Update `Latest Known` column in `VERSIONS.md` with `latest_stable`.

---

## Step 2 — Check Toolchain

Repeat Step 1 for all entries in the **Toolchain** table of `VERSIONS.md`.

> Note: For toolchain components (Gradle, AGP, Kotlin), always verify the compatibility matrix at
> `https://developer.android.com/build/releases/gradle-plugin#updating-gradle` before flagging an upgrade.
> A toolchain bump may require other toolchain bumps. Note this in the tech debt entry.

---

## Step 3 — Apply Staleness Rules

For each dependency where `bump_type != none`, calculate months since `Last Updated` and apply:

| Condition | Action |
|---|---|
| `is_security = true`, any age | Create `DU-` (critical) + add to `DEPENDENCY_ALERTS.md` |
| `bump_type = major`, any age | Add to `DEPENDENCY_ALERTS.md` (do not auto-create tech debt unless > 6 months) |
| `bump_type = major`, > 6 months | Create `DU-` (high) |
| `bump_type = minor`, > 3 months | Create `DU-` (medium) |
| `bump_type = patch`, > 2 months | Create `DU-` (low) |

---

## Step 4 — Write Tech Debt Entries

For each entry that triggers a tech debt rule, append to `TECH_DEBT.md`:

```
### DU-XXX — [Dependency Name] [current] -> [latest_stable]
- **Tier:** [1/2/3/4]
- **Type:** [patch/minor/major]
- **Last Updated:** YYYY-MM-DDTHH:MMZ ([N] months ago)
- **Latest Stable:** [version]
- **Release Notes:** [URL]
- **Security:** [Yes / No]
- **Priority:** [critical/high/medium/low]
- **Notes:** [Any compatibility concerns, e.g. toolchain matrix constraints]
- **Status:** OPEN
```

---

## Step 5 — Write Alerts

For major version bumps and security fixes, append to `.memory/DEPENDENCY_ALERTS.md`:

```
### ALERT-XXX — [Dependency Name] major update available: [current] -> [latest_stable]
- **Detected:** YYYY-MM-DDTHH:MMZ
- **Release Notes:** [URL]
- **Action Required:** Review for upgrade planning. [Security: YES if applicable]
- **Status:** OPEN
```

---

## Step 6 — Update CONFIG.md

Update `Last Dependency Check` in `.memory/CONFIG.md`:
```
| Last Dependency Check | YYYY-MM-DDTHH:MMZ |
```

---

## Step 7 — Report to User

Present a summary:
- N dependencies checked
- N up to date
- N alerts added to DEPENDENCY_ALERTS.md (list them)
- N tech debt entries created (list IDs)
- Any dependencies where the release notes URL could not be fetched (flag for manual check)

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
