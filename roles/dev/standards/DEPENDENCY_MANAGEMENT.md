# Dependency & Toolchain Management
> Last updated: 2026-03-12
> Applies to: all repositories (Android, iOS, Backend)

This document defines how dependencies and toolchain versions are managed, updated, and approved. The goal is controlled modernisation — staying current without surprising the team.

---

## Principles

- **One thing at a time.** Never upgrade Gradle + AGP + Kotlin in a single PR. Each upgrade is its own PR so failures are isolated.
- **CI is the gate.** No upgrade merges unless CI passes completely — lint, tests, and build.
- **Structural enforcement over process.** Lead engineer approval is enforced by GitHub CODEOWNERS on version-controlling files, not by asking nicely.
- **Agents propose, humans approve.** An agent may prepare and open an upgrade PR. It must never merge it.
- **Track before upgrading.** Each repo maintains a `VERSIONS.md` in `.memory/` with current and latest known versions.

---

## Upgrade Tiers

### Tier 1 — Patch (any dev, merge anytime after CI)

Library bugfix releases. No new APIs, no behaviour changes, no compatibility risk.

Examples:
- `retrofit 2.9.0 → 2.9.1`
- `coil 2.5.0 → 2.5.1`
- Kotlin `2.0.20 → 2.0.21`

Process: normal PR, any reviewer, merge after CI passes.

---

### Tier 2 — Minor (tech lead review, scheduled)

Minor version bumps. New APIs available but no breaking changes. Low risk but deserves a second set of eyes.

Examples:
- `gradle 8.5 → 8.6`
- `AGP 8.2 → 8.3`
- Kotlin `2.0 → 2.1`
- `compileSdk 34 → 35`
- Swift package minor bumps

Process: PR opened by agent or dev, tech lead reviews and approves, merge after CI passes. Batched into a monthly "dependency sprint".

---

### Tier 3 — Major / Breaking — Technical (lead engineer required)

Major version bumps or upgrades that change build behaviour, require code migration, or carry compatibility risk between interdependent tools.

Examples:
- Kotlin `1.x → 2.x`
- AGP `7.x → 8.x`
- Gradle `7.x → 8.x`
- `targetSdk` bump (new runtime behaviour — background limits, permission dialogs)
- Swift major version
- Xcode major version

**Approval required: lead engineer sign-off before merge.**

Enforcement: CODEOWNERS on the files that control these versions (see below). GitHub will not allow merge without the designated lead engineer's approval.

Process:
1. Agent or dev opens a dedicated upgrade PR.
2. PR description must include: what is changing, the compatibility matrix checked, migration steps taken, CI results.
3. Lead engineer reviews and approves.
4. Merge during a low-traffic window (not Friday, not before a release cut).
5. All devs must be notified in the team channel before merge: "Toolchain upgrade merging in 24h — sync your branches."

---

### Tier 4 — Business Impact (lead engineer + PM required)

Changes that alter which devices the app supports or affect production behaviour at a platform policy level.

Examples:
- `minSdk` bump (drops older Android versions — reduces addressable install base)
- iOS deployment target bump (drops older iOS versions)
- Google Play `targetSdk` deadline compliance

These require PM acknowledgement because they affect reach/installs. Lead engineer prepares the analysis (% of users affected); PM signs off.

---

## Compatibility Matrix (Android)

Gradle, AGP, and Kotlin are tightly coupled. Always check the official matrix before upgrading any of the three:

**https://developer.android.com/build/releases/gradle-plugin#updating-gradle**

| AGP | Min Gradle | Min Kotlin |
|-----|-----------|-----------|
| 8.4 | 8.6 | 1.9 |
| 8.5 | 8.7 | 1.9 |
| 8.6 | 8.7 | 2.0 |

*(Always verify against the official table — this snapshot may be outdated.)*

Upgrade order when multiple need bumping: **Gradle wrapper → AGP → Kotlin**.

---

## Enforcement: CODEOWNERS

Each repository must have a `.github/CODEOWNERS` file. Ownership is split into two tiers:

- **Toolchain files** — lead engineer only. These control the build system itself (Gradle, AGP, Kotlin, SDK levels). Changes here are Tier 2–3 by definition.
- **Project dependency files** — lead engineer + leads team. Any approved lead may review library version bumps.

Approval is **either/or**: one approval from any listed owner satisfies the requirement (enforced by branch protection "require 1 CODEOWNERS approval").

### Android

```
# Toolchain — lead engineer only
/gradle/wrapper/gradle-wrapper.properties    @[lead-engineer]
/buildSrc/src/main/java/BuildInfo.kt         @[lead-engineer]
/build.gradle                                @[lead-engineer]

# Project dependencies — lead engineer or any team lead
/gradle/libs.versions.toml                   @[lead-engineer] @[org]/[android-leads-team]
/buildSrc/src/main/java/Dependencies.kt      @[lead-engineer] @[org]/[android-leads-team]

# CODEOWNERS itself — leads team
/.github/CODEOWNERS                          @[org]/[android-leads-team]
```

### iOS

```
# Toolchain — lead engineer only
/.xcode-version                              @[lead-engineer]

# Project dependencies — lead engineer or any team lead
/Package.swift                               @[lead-engineer] @[org]/[ios-leads-team]
/Podfile                                     @[lead-engineer] @[org]/[ios-leads-team]  # if using CocoaPods

# CODEOWNERS itself — leads team
/.github/CODEOWNERS                          @[org]/[ios-leads-team]
```

Branch protection must be configured to require CODEOWNERS approval before merge. This is set in GitHub repo Settings → Branches → Branch protection rules → "Require review from Code Owners".

---

## Release Notes Policy

Every tracked dependency must have its official release notes URL recorded in `.memory/VERSIONS.md`. The same URL should be added as a comment in the version source file (`libs.versions.toml` or `Dependencies.kt`) so developers see it inline.

**Before any upgrade decision — Tier 1 through Tier 4 — the agent must read the release notes for the target version.** Do not rely on version numbers alone. Release notes reveal behaviour changes, deprecations, migration requirements, and security fixes that are not visible from the version bump itself.

For **Tier 3 and Tier 4 upgrades**, the agent must:
1. Read the release notes for every version between current and target (not just the latest).
2. Identify all breaking changes, migration steps, and compatibility requirements.
3. Write a structured upgrade plan before making any file changes.
4. Present the plan to the developer for review and explicit approval.
5. Execute only after human sign-off.

The agent never decides a major upgrade is "safe" on its own. The plan is the deliverable; the human decides whether to proceed.

---

## Stable Versions Only

**Never upgrade to a pre-release version.** Only target versions that are fully stable. Skip any version whose string contains:

`-alpha`, `-beta`, `-rc`, `-canary`, `-snapshot`, `-nightly`, `-dev`, `-eap`, `-milestone`

This applies equally to toolchain versions (Gradle, AGP, Kotlin) and library versions. If only a pre-release is available for a given library, stay on the current stable version and note it in `VERSIONS.md`.

---

## Dependency Staleness Policy

### Tech Debt Prefix: `DU-` (Dependency Update)

Staleness entries use the `DU-` prefix in `TECH_DEBT.md`, separate from `AP-`, `BUG-`, etc.

### Staleness Rules

| Condition | Priority | Action |
|---|---|---|
| Security fix available, any age | Critical | `DU-` tech debt (critical) + `DEPENDENCY_ALERTS.md` entry immediately |
| Major version available, any age | — | `DEPENDENCY_ALERTS.md` entry (inform product owner) |
| Major version available, > 6 months since last update | High | `DU-` tech debt (high) |
| Minor version available, > 3 months since last update | Medium | `DU-` tech debt (medium) |
| Patch version available, > 2 months since last update | Low | `DU-` tech debt (low) |

"Last updated" is the date the project last bumped that dependency, recorded in `VERSIONS.md`.

### Check Frequency

Run the `check-dependencies` workflow at the first session each **fortnight** (14 days). The last run date is stored in the `Last Checked` header of `VERSIONS.md`. Check order: Key Dependencies first, Toolchain second.

### Version Discovery

Use **WebFetch** to the release notes URL already recorded in `VERSIONS.md` for each dependency. Do not use web search. Parse the latest stable version from the page (exclude all pre-release strings listed above).

---

## Dependency Tracking in VERSIONS.md

`VERSIONS.md` is the source of truth for all tracked dependencies. It must stay in sync with the actual version files (`libs.versions.toml`, `Dependencies.kt`, etc.).

### Schema

Each dependency row includes:

| Dependency | Current | Latest Known | Last Updated | Release Notes | Source | Notes |
|---|---|---|---|---|---|---|

- **Current** — version active in the project right now
- **Latest Known** — latest stable version found in the most recent `check-dependencies` run
- **Last Updated** — date this project last bumped this dependency

The file header records when the last check ran:
```
> Last Checked: YYYY-MM-DD
```

### Keeping VERSIONS.md in Sync

Run the `sync-versions` workflow after any PR that modifies version files:
- New dependency added → new row, `Last Updated = today`, `Latest Known = same as Current`
- Dependency removed → remove the row
- Version bumped → update `Current` and `Last Updated`

**Future automation:** A GitHub Actions workflow triggered on changes to `libs.versions.toml` / `Dependencies.kt` can run `sync-versions` automatically in CI, eliminating the manual step.

---

## Dependency Version History (Legal Compliance)

Each project must maintain a `DEPENDENCY_HISTORY.md` in `.memory/`. This is an append-only legal record of which SDK versions were active at each app release.

**Populated by:** the `cut-release` workflow — one entry per release, immediately before opening the release PR.

**Format:**
```markdown
## vX.Y.Z (Build: XXXXXXXX | YYYY-MM-DD)
| Dependency | Version |
|---|---|
| Kotlin | 2.0.20 |
| Firebase BOM | 34.0.0 |
```

**Rules:**
- Append-only. Never edit or delete past entries.
- Covers all dependencies tracked in `VERSIONS.md` at release time.
- Separate file from release notes — no cross-contamination.

---

## Agent Rules

- **Read release notes first.** Before proposing or executing any upgrade, read the official release notes for the target version. Record the URL in `VERSIONS.md`.
- **Stable only.** Never target alpha, beta, RC, canary, snapshot, or nightly versions.
- **Discover** available upgrades via `check-dependencies` workflow (WebFetch to known URLs) — do not blindly run `dependencyUpdates`.
- **Plan before acting (Tier 3/4).** For major upgrades, write a full upgrade plan (breaking changes, migration steps, compatibility matrix, risk assessment) and get human approval before touching any file.
- **Prepare** upgrade PRs on a dedicated branch (`dep-update-[package]-[version]`).
- **Run** the full build and test suite before opening the PR.
- **Verify** that the app builds, tests pass, and no runtime regressions are introduced. Do not open the PR until this is confirmed.
- **Document** in the PR body: current version, new version, release notes link, compatibility matrix check, migration steps applied, test results.
- **Tag** the PR with the appropriate tier label: `dep-patch`, `dep-minor`, `dep-major-technical`, `dep-major-business`.
- **Never merge** — not even Tier 1 patches. Always wait for human approval.
- **Update** `VERSIONS.md` in `.memory/` after each successful upgrade.

---

## Cadence

| Tier | Frequency |
|------|-----------|
| Security patches (any tier) | As discovered — create PR immediately |
| Tier 1 (patch) | Monthly batch |
| Tier 2 (minor) | Quarterly — aligned with release planning |
| Tier 3 (major technical) | Per release cycle — one major upgrade per release |
| Tier 4 (business impact) | Only when necessary or Google/Apple-mandated |

---

## Version Catalog (Android)

All Android dependency versions **must** live in `libs.versions.toml`. No version strings hardcoded in individual `build.gradle.kts` files.

```toml
[versions]
kotlin = "2.0.21"
agp = "8.5.2"
gradle = "8.7"
compose-bom = "2024.10.00"
hilt = "2.52"
room = "2.6.1"

[libraries]
# reference versions above, never hardcode here

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
```

A single-line diff in `libs.versions.toml` is all that's needed for a dependency upgrade — this makes PRs minimal and reviewable.
