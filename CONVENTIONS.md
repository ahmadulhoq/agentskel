# Coding Conventions: agentskel

<!-- Observed project-specific patterns and conventions.
     Populated by the cartographer agent during codebase mapping.
     Agent must follow these patterns when editing existing code. -->

## Naming Patterns
- Workflows: kebab-case filenames (e.g. `setup-skeleton.md`, `check-dependencies.md`)
- Skills: kebab-case directory names with `SKILL.md` inside (e.g. `senior-developer/SKILL.md`)
- Standards: SCREAMING_SNAKE filenames (e.g. `ARCHITECTURE.md`, `GIT_WORKFLOW.md`)
- Memory files: SCREAMING_SNAKE filenames (e.g. `CONFIG.md`, `TECH_DEBT.md`)
- Prompts: kebab-case filenames matching the workflow/skill they trigger
- Rules: kebab-case filenames (e.g. `core-behavior.md`, `security-non-negotiables.md`)
- Claude Code stubs: kebab-case filenames matching the skill/workflow name

## Architecture Patterns
- **Two-component architecture**: Skeleton (always required) + Blueprint (optional)
- **Core vs Roles**: `core/` is always installed; `roles/<name>/` is opt-in per role
- **Template + Token replacement**: Memory templates use `[PLACEHOLDER]` tokens filled during setup
- **Platform markers**: Multi-platform content wrapped in `<!-- PLATFORM: X -->` / `<!-- END PLATFORM: X -->` HTML comments, trimmed during setup
- **Installed copies**: Downstream projects get copies in `.agents/`; agentskel itself uses copies synced via sync-skeleton (Skeleton Path = `.`)
- **Stub generation**: `.claude/skills/` stubs are auto-generated from frontmatter, not manually maintained

## File Structure Patterns
- Every workflow has YAML frontmatter with `name` and `description`
- Every skill has YAML frontmatter with `name` and `description`
- Standards use `>` blockquote headers for metadata (no YAML frontmatter)
- Prompts are inconsistent — some have frontmatter, some don't
- Every workflow ends with "Final Step — Task Completion Checklist" reference
- Memory templates use HTML comments for format documentation

## Common Patterns
- **Pre-flight reads**: Most workflows start by reading RULES.md, CONFIG.md, MAP.md, SYMBOLS.md, RESUME.md
- **Never merge**: Agent opens PRs but never merges — human approval required
- **Checkpoint pattern**: RESUME.md updated after each sub-task, committed to ai-memory (RESUME.md excluded)
- **Triage protocol**: Findings classified as TECH_DEBT (confident), SACRED (confirmed), or NEEDS_REVIEW (ambiguous)
- **WebFetch only**: Version discovery uses WebFetch to known URLs, never web search or package manager commands
- **Stable only**: Never target pre-release versions (alpha, beta, rc, canary, snapshot, nightly, dev, eap)

## Third-Party Library Usage
- No code dependencies — agentskel is pure markdown and shell
- `gh` CLI used for GitHub API calls (PRs, branch management)
- `git` worktree used for `.memory/` mount pattern
