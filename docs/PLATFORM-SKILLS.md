# Platform-specific skills (external)

agentskel covers cross-platform agent behavior (memory, workflows, conventions,
tooling). For deep platform-specific guidance, we point at canonical external
skill packs maintained by the platform owner — same `SKILL.md` open standard,
installed into a machine-level shared store and linked into each project.

## How it works

External skills live in `~/.agentskel/skills/` — one copy per machine, shared
across all your projects. Each project gets gitignored symlinks in `.agents/skills/`
pointing at the shared store. Every supported tool (Claude, Cursor, Windsurf, etc.)
sees the skills as local because the symlinks resolve transparently.

```
~/.agentskel/skills/          ← shared store (one copy per machine)
    r8-analyzer/SKILL.md
    camera-migration/SKILL.md
    ...

your-project/.agents/skills/
    developer/SKILL.md        ← first-party, committed
    r8-analyzer               ← symlink → ~/.agentskel/skills/r8-analyzer
    camera-migration          ← symlink → ~/.agentskel/skills/camera-migration
    .gitignore                ← lists external dir names (committed)
```

**After cloning:** `scripts/install-agent.sh` reads `.agents/skills/.gitignore`,
checks the shared store, and recreates any missing symlinks. If the shared store
is missing entirely, it prints instructions to run `update-external-skills`.

**Updating:** Run the `update-external-skills` workflow (or have your agent do it).
One update refreshes all projects on this machine. `sync-skeleton` reminds you
when `Last External Skills Check` in `.memory/CONFIG.md` is older than 30 days.

agentskel's validator skips external skills — they're third-party, not under our
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

**Install (agent-guided):**

Ask your agent: `run update-external-skills` — it will install to the shared store,
create symlinks, and update the AGENTS.md catalog automatically.

**Install (manual):**

Preferred — Android CLI (auto-detects which AI tool directories exist):

```bash
# Install to shared store
mkdir -p ~/.agentskel/skills
android skills add --all --output=~/.agentskel/skills/

# Symlink into this project
for dir in ~/.agentskel/skills/*/; do
  skill=$(basename "$dir")
  ln -sfn "$dir" ".agents/skills/$skill"
  echo "$skill" >> .agents/skills/.gitignore
done
```

Manual fallback — clone directly:

```bash
mkdir -p ~/.agentskel/skills/android-tmp
git clone https://github.com/android/skills ~/.agentskel/skills/android-tmp
# Move individual skill dirs into the shared store root
for dir in ~/.agentskel/skills/android-tmp/*/; do
  skill=$(basename "$dir")
  cp -r "$dir" "~/.agentskel/skills/$skill"
done
rm -rf ~/.agentskel/skills/android-tmp
# Then symlink (same as above)
```

**Updating:**

```bash
# Re-run CLI against shared store, or pull if you used a git clone
android skills add --all --output=~/.agentskel/skills/
# Symlinks don't need to change — they already point at the shared store
```

**Tracking:**

`.memory/CONFIG.md` records:
- `External Platform Skills`: `(empty)` / `installed` / `declined`
- `Last External Skills Check`: timestamp of last install or refresh

Set `declined` if you don't want sync-skeleton to keep suggesting these.

---

## Adding a new pack

To add a new external pack to agentskel's registry:

1. Add an entry to `core/external-skills.yml` with `id`, `name`, `author_tag`,
   `platform_match`, `install_cmd`, `clone_url`, `description`, and `license`.
2. Add a section to this file with install and update instructions.
3. The `setup-skeleton`, `sync-skeleton`, and `update-external-skills` workflows
   read the manifest automatically — no other changes needed.

PRs welcome. Requirements: publisher-maintained, open-standard `SKILL.md` format,
permissive license (Apache-2.0, MIT, or equivalent).

---

## Coming later

iOS, web (frontend/backend), Kotlin Multiplatform — no canonical
publisher-maintained skill packs exist today that we'd point at. When they
do, they'll be added here.

---

## Scope

agentskel does not vendor external skills — we link, suggest, and integrate.
Reasons:
- Open standard format means no translation work
- Platform owners ship updates faster than our release cadence
- Avoids forking maintained content
- Apache-2.0 / similar licenses still require attribution if we did vendor

If an external skill conflicts with agentskel's own (same name), the
symlinked file wins on disk because it resolves to the shared store entry.
Avoid name collisions by reviewing what's installed before linking.
