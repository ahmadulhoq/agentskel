# Workflow: cut-release

**Applies to:** All platforms with a release cycle.
During setup, trim platform-specific sections to match the project's stack.

**Trigger:** When the team is ready to cut a release from `development`.

**Usage:** `cut-release [variant]` — if the repo ships multiple app variants, pass the variant name. Default to the primary app if nothing is specified.

**Purpose:** Pre-flight checks, snapshot dependency versions for legal compliance, trigger existing CI release workflows, and complete post-merge cleanup. CI handles the actual version bump, branch creation, and build — the agent does not duplicate that work.

---

## Pre-Flight

1. Confirm current branch is `development` and working tree is clean.
2. Confirm CI is green — do not cut a release on a red build.
3. _(Optional)_ Run static analysis — no new violations before cutting.
4. Show the current version from the repo's version file:

<!-- PLATFORM: Android -->
   - Android: Read `versionName` and `versionCode` from `version.properties`, `build.gradle(.kts)`, or `libs.versions.toml` — whichever the project uses as the version source of truth.
<!-- END PLATFORM: Android -->
<!-- PLATFORM: iOS -->
   - iOS: Read `CFBundleShortVersionString` (marketing version) and `CFBundleVersion` (build number) from the project's `.xcconfig`, `Info.plist`, or Xcode project settings.
<!-- END PLATFORM: iOS -->
<!-- PLATFORM: Web -->
   - Web: Read the `version` field from `package.json`.
<!-- END PLATFORM: Web -->
<!-- PLATFORM: Backend -->
   - Backend: Read the version from the project's version file (`package.json`, `pyproject.toml`, `build.gradle`, `version.go`, or equivalent).
<!-- END PLATFORM: Backend -->

5. Confirm the new version with the team. Validate the encoding is correct per platform convention.
6. Read `.memory/VERSIONS.md` — all current dependency versions will be snapshotted in Step 3.

---

## Step 1 — Trigger Release CI

Trigger the release CI workflow with the confirmed version. The CI workflow should handle:
- Creating `release/vX.Y.Z` branch from `development`
- Bumping the version file
- Any platform-specific release prep (translations, config files, etc.)
- Opening the automated release PR

<!-- PLATFORM: Android -->
### Android
Typical trigger: GitHub Actions `workflow_dispatch` or Bitrise manual build. Example:
```bash
gh workflow run release.yml -f version=X.Y.Z -f versionCode=NNNNN
```
If using Fastlane: `fastlane release version:X.Y.Z`.
<!-- END PLATFORM: Android -->
<!-- PLATFORM: iOS -->
### iOS
Typical trigger: Fastlane lane or GitHub Actions `workflow_dispatch`. Example:
```bash
gh workflow run release-ios.yml -f version=X.Y.Z
# or
fastlane release version:X.Y.Z build:NNN
```
<!-- END PLATFORM: iOS -->
<!-- PLATFORM: Web -->
### Web
Typical trigger: GitHub Actions `workflow_dispatch`. Example:
```bash
gh workflow run release.yml -f version=X.Y.Z
```
Some projects use `npm version X.Y.Z` to bump and tag in one step.
<!-- END PLATFORM: Web -->
<!-- PLATFORM: Backend -->
### Backend
Typical trigger: GitHub Actions `workflow_dispatch` or GitLab CI manual job. Example:
```bash
gh workflow run release.yml -f version=X.Y.Z
```
<!-- END PLATFORM: Backend -->

**Do NOT manually edit the version file** — let CI own it.

Wait for CI to complete and confirm the release PR was opened.

---

## Step 2 — Generate Release Notes

Collect all changes since the last release tag:

1. Run: `git log $(git describe --tags --abbrev=0)..HEAD --oneline --no-merges`
2. Filter out internal agent/chore commits.
3. Group by type: **Features**, **Bug Fixes**, **Tech Debt**, **Dependencies**.
4. Write a concise, human-readable summary (3-10 bullet points per group).
5. Edit the release PR body to include the release notes.

**Release notes go in the PR body only — do not commit them to any file.**

---

## Step 3 — Snapshot Dependencies (Legal Compliance)

Read all rows from `.memory/VERSIONS.md` (all sections: Key Dependencies + Toolchain).
Append to `.memory/DEPENDENCY_HISTORY.md`:

```markdown
## vX.Y.Z (Build: XXXXXXXX | YYYY-MM-DD)
| Dependency | Version |
|---|---|
| [name] | [Current from VERSIONS.md] |
| ... | ... |
```

Rules:
- Include **every row** from VERSIONS.md — no omissions.
- **Append-only** — never edit or delete past entries.
- This is the legal record of SDK versions shipped. Keep it separate from release notes.

Commit to the `ai-memory` branch:
```
git add .memory/DEPENDENCY_HISTORY.md
git commit -m "agent: snapshot dependencies for vX.Y.Z release"
git push origin ai-memory
```

---

## Step 4 — Wait for Human Approval

The release PR requires review and approval from the lead engineer (see CODEOWNERS).

**Do NOT merge the PR yourself.** Notify the team that the release PR is ready for review.

---

## Step 5 — Trigger Build (after PR is merged)

The build workflow typically requires **manual dispatch** — it does not trigger automatically after the release PR is merged. Trigger it explicitly, targeting `release/vX.Y.Z`.

<!-- PLATFORM: Android -->
### Android
Trigger the build workflow targeting the release branch. Example:
```bash
gh workflow run build-release.yml -r release/vX.Y.Z
```
Output: AAB/APK uploaded to Google Play Console (internal track).
<!-- END PLATFORM: Android -->
<!-- PLATFORM: iOS -->
### iOS
Trigger the build workflow targeting the release branch. Example:
```bash
gh workflow run build-ios.yml -r release/vX.Y.Z
# or
fastlane beta
```
Output: IPA uploaded to App Store Connect (TestFlight).
<!-- END PLATFORM: iOS -->
<!-- PLATFORM: Web -->
### Web
Trigger the deploy pipeline targeting the release branch. Example:
```bash
gh workflow run deploy.yml -r release/vX.Y.Z
```
<!-- END PLATFORM: Web -->
<!-- PLATFORM: Backend -->
### Backend
Trigger the deploy pipeline targeting the release branch. Example:
```bash
gh workflow run deploy.yml -r release/vX.Y.Z
```
<!-- END PLATFORM: Backend -->

---

## Step 6 — Post-Merge Cleanup

Once the release branch is merged back to `development` (per the repo's git flow):

1. Tag the merge commit: `git tag vX.Y.Z && git push origin vX.Y.Z`
2. Confirm the tag appears on the remote.

---

## Notes

- **Never merge the release PR yourself.** Open it and stop at Step 4.
- **One release at a time.** Do not cut a new release while another is open.
- **Dependency history is legal compliance data.** Step 3 must complete before Step 4.
- **Hotfix:** Cut from `release/vX.Y.Z` while the branch is open. After shipping, cut a new release from the tagged commit.
- **Multiple variants:** Run this workflow once per variant. Each variant has its own CI workflow pair.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
