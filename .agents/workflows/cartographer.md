---
name: cartographer
description: When codebase structure has changed, MAP.md/SYMBOLS.md are missing or stale,
  or after major refactors and initial setup. Also run when a new module is added or
  files are moved between modules.
---

# Cartographer Mission

## Context
This is a discovery mission. You are mapping the codebase and recording
findings. You do NOT modify application code.

For large codebases this workflow spans multiple sessions. Use RESUME.md
to track which modules are complete and which are pending. At the start
of each session, read RESUME.md to find where to resume — do not re-map
modules already marked complete. Record the current HEAD commit SHA in
`Cartography State` at the start of each session.

## Steps
1. Read `.memory/RULES.md` for project-specific context and rules.
   Read `.memory/VERSIONS.md` — note the current version snapshot.
2. Read `.memory/RESUME.md` — you may be resuming a previous session.
   If resuming, check `Cartography State` to find the last indexed
   commit. Run `git log <sha>..HEAD --name-only --format=""` to detect
   any new commits in already-mapped modules — re-process those first.
3. Record the current HEAD SHA in RESUME.md under `Cartography State`.
4. Build the COMPLETE pending module list — this step is the coverage contract:
   a. Run a filesystem enumeration to find every directory that contains source files.
      Do not infer from project config — the filesystem is the source of truth.
      Example command (adapt file extensions for the platform):
      ```
      find . -type f \( -name "*.kt" -o -name "*.java" -o -name "*.swift" \) \
        | grep -v "/build/" | grep -v "/.gradle/" | grep -v "/.git/" \
        | sed 's|/[^/]*$||' | sort -u
      ```
   b. Group the resulting paths into logical modules (one Gradle/SPM module = one entry).
   c. Write the complete list to RESUME.md under `Cartography State > Modules pending`.
      Format each entry as `[ ] module-name (N files)` so progress is trackable.
   d. The total file count from the find command is the coverage target.
      Record it in RESUME.md as `Coverage target: N source files`.
      Do not proceed until every module directory appears in the pending list.
4.5 Tech-stack research — run after the module list is built, before processing any module:
   a. Identify the platform and primary tech stack from build configuration files
      (e.g., `build.gradle.kts` / `build.gradle` for Android, `Package.swift` for iOS,
      `pubspec.yaml` for Flutter, `package.json` for React Native).
   b. Read the project's architecture standard (`.agents/standards/ARCHITECTURE.md`).
      If no architecture standard exists: proceed to step c, then create one afterward.
   c. Web-search for current best practices, architecture patterns, and common anti-patterns
      for the detected stack. Cover: layered architecture, DI, async/concurrency,
      state management, navigation, and testing. Use only sources less than 2 years old.
   d. Cross-check and update `.memory/CONVENTIONS.md`:
      - Does not exist: create it using the architecture standard as the foundation,
        adding project-specific naming patterns observed from the module structure.
      - Exists: verify every section still reflects current best practice.
        Fill gaps. Flag deviations from the architecture standard as NEEDS_REVIEW items
        so the user can decide whether each deviation is intentional (SACRED) or
        accidental (TECH_DEBT).
   e. If the research reveals that the architecture standard is missing important
      guidance or contains outdated advice, update the standard directly.
5. Process each module one at a time. Complete all sub-steps before
   moving to the next module:
   a. List the primary classes by scanning the module's directory
      structure.
   b. For each primary class, **open and read the source file**.
      Extract:
      - The class responsibility (one sentence)
      - Every named function/method (public, internal, private, protected)
        and the file it lives in. Skip anonymous lambdas and trivial
        getters/setters.
      Write both class-level and function-level rows to SYMBOLS.md
      using the format defined in the SYMBOLS.md template header. Do not
      skip any named function — the goal is a complete index.
   c. While reading each file, actively look for triage triggers:
      - FIXME, TODO, HACK, or XXX comments
      - Patterns that contradict `.memory/CONVENTIONS.md`
      - Unusual logic with no explanatory comment (magic numbers,
        retry counts, hardcoded offsets, double-calls, timing
        constants, unusual error handling)
      - Deprecated or unused classes/functions
      - Missing tests for critical or complex logic
      - Inconsistencies between modules doing the same thing
        differently
   d. Classify each finding per the Triage Protocol:
      - High-confidence tech debt → TECH_DEBT.md
      - High-confidence sacred behaviour → SACRED.md
      - Ambiguous / low-confidence → NEEDS_REVIEW.md (user will classify)
   e. Update `.memory/RESUME.md`: mark this module complete, update
      the pending module list, and note the count of findings.
   f. **Pause. State how many NEEDS_REVIEW items were found for this
      module and present each one to the user for classification.
      Do not proceed to the next module until all items are resolved.**
      Move resolved items to SACRED.md or TECH_DEBT.md.
   g. Commit and push all `.memory/` changes to the ai-memory branch.
      RESUME.md is local-only — exclude it from every commit.
      ```
      cd .memory
      git add -A && git reset HEAD RESUME.md
      git commit -m "cartographer: mapped [module name]"
      git push origin ai-memory
      ```
      This step is MANDATORY after every module. Do not proceed to the
      next module until the push succeeds.
5.5 **Completion gate — run before Step 6.** Re-run the find command from Step 4a.
    Cross-check every output directory against RESUME.md's module list.
    Any directory in the find output that is NOT marked `[x]` in RESUME.md is an
    unprocessed module — process it now before continuing.
    Only proceed to Step 6 when the find output contains zero unprocessed directories.
    State explicitly: "Coverage gate passed — N modules complete, 0 remaining."
6. Document overall architecture in `.memory/MAP.md`, including:
   - Architecture pattern (MVVM, Clean, etc.)
   - Module registry with responsibilities and Key Entry Points
     (use `ClassName.functionName()` format)
   - Internal frameworks and which modules depend on them
   - Critical business logic flows with function-level entry points
6b. If the project has a `MASTER_PLAN.md` or similar ADR document, add a
   **section index** to MAP.md. For each top-level section, record the section
   name, line range, and a 1-line summary. This lets agents read only the
   relevant section via offset/limit instead of loading the entire document.
7. Map critical flows in detail (e.g. auth, key features). For each
   flow, trace the call chain from entry point to output using the function names
   recorded in SYMBOLS.md.
8. Populate `.memory/VERSIONS.md` from the actual version files discovered during
   cartography. Follow the agent workflow at `.agents/workflows/sync-versions.md`
   (this is an agent-executed instruction file — NOT a GitHub Actions pipeline;
   no CI trigger exists or is needed). It reads the platform's version files and
   creates/updates every row in VERSIONS.md with `Current`, `Last Updated = now (UTC)`,
   `Latest Known = —`, and a Release Notes URL.
   Verify all rows have a Release Notes URL — add any that are missing.
   Then follow the agent workflow at `.agents/workflows/check-dependencies.md` to
   fetch the `Latest Known` stable version for each entry and surface any immediate
   staleness alerts. This gives a complete dependency picture at the end of every
   cartography run.
9. Verify NEEDS_REVIEW.md is empty. Flag any remaining items in RESUME.md.
10. Write a final RESUME.md update: Status IDLE, full Cartography State with HEAD
    SHA, and summary of all findings.
11. Commit and push all `.memory/` changes:
    `cd .memory && git add -A && git commit -m "cartographer: complete" && git push origin ai-memory`

## Scope
- Do NOT refactor or modify any application code.
- Do NOT fix any issues you find — only record them.
- Do NOT upgrade any dependency or toolchain version — only record what is found.
- Do NOT create Knowledge Bus entries (no cross-platform changes).
- DO read actual source files — do not infer from directory names alone.
- DO record everything: the goal is a complete, honest map of
  the codebase including its problems.
- DO use the Triage Protocol — never decide something is sacred on
  your own without evidence or user confirmation.

---

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.

At minimum:
- Update **RESUME.md** with task outcome
- Write **TIME_LOG.md** entry (if this was an implementation task)
- Write **CHANGELOG entry** (if any files changed)
- Update **SYMBOLS.md / MAP.md** (if structure changed)
