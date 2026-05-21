# Platform-specific skills (external)

agentskel covers cross-platform agent behavior (memory, workflows, conventions,
tooling). For deep platform-specific guidance, we point at canonical external
skill packs maintained by the platform owner — same `SKILL.md` open standard,
same `.agents/skills/` install location.

External skills drop into the same `.agents/skills/` directory as agentskel's
own skills and are picked up by every supported tool. agentskel's validator
(see `scripts/validate.py`) skips them — they're third-party, not under our
parity contract.

---

## Currently supported

### Android — [android/skills](https://github.com/android/skills)

Maintained by Google. Apache-2.0. Covers areas where LLMs underperform:
- R8 / Proguard keep rule analysis (`r8-analyzer`)
- Camera1 → CameraX migration
- Jetpack Compose adaptive layouts, theming, migration
- Android Gradle Plugin (AGP) build
- Testing setup
- Navigation, identity, performance, system, play, profilers, XR

**Install:**

Preferred — Android CLI (auto-detects which AI tool directories exist):

```bash
android skills add --all --project=.
```

Manual fallback — clone directly:

```bash
git clone https://github.com/android/skills .agents/skills/_android-tmp
cp -r .agents/skills/_android-tmp/*/SKILL.md .agents/skills/
# or symlink individual skill dirs
```

After install, agentskel's `sync-skeleton` Step 4c automatically regenerates
`.claude/skills/` stubs and AGENTS.md catalog rows to include the new skills.

**Updating:**

Re-run `android skills add --all` (or `git pull` on the manual clone).
Google ships updates frequently — `sync-skeleton` reminds you when
`Last External Skills Check` in `.memory/CONFIG.md` is older than 30 days.

**Tracking:**

`.memory/CONFIG.md` records:
- `External Platform Skills`: `(empty)` / `installed` / `declined`
- `Last External Skills Check`: timestamp of last install or refresh

Set `declined` if you don't want sync-skeleton to keep suggesting these.

---

## Coming later

iOS, web (frontend/backend), Kotlin Multiplatform — no canonical
publisher-maintained skill packs exist today that we'd point at. When they
do, they'll be added here. PRs welcome with a clear maintenance story.

---

## Scope

agentskel does not vendor external skills — we link, suggest, and integrate.
Reasons:
- Open standard format means no translation work
- Platform owners ship updates faster than our release cadence
- Avoids forking maintained content
- Apache-2.0 / similar licenses still require attribution if we did vendor

If an external skill conflicts with agentskel's own (same name), the
externally-installed file wins on disk because it lands in the same
directory. Avoid name collisions by reviewing what's installed.
