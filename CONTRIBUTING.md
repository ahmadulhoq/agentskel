# Contributing to agentskel

## How to contribute

1. Fork this repo
2. Create a branch (`feature/my-change` or `fix/my-fix`)
3. Make your changes
4. Open a PR with a clear description

## Rules

Every change to a skeleton file (template, workflow, standard, prompt, skill) **must**:

1. Bump `agent-hq/VERSION` (MINOR for additions, MAJOR for breaking changes)
2. Add an entry to `agent-hq/CHANGELOG.md`
3. Update `README.md` "Current version" if the version changed

No exceptions. This is how downstream repos detect they're out of sync.

## What belongs here vs. in a blueprint

**agentskel (this repo — the skeleton):**
- Generic capabilities that apply to any project, any tech stack, any organization
- Universal standards (architecture principles, git workflow, style conventions)
- Core memory system, rules, skills, workflows

**Your blueprint (optional — team domain knowledge repo):**
- Domain specs, API contracts, business logic documentation
- Cross-platform parity tracking
- Knowledge Bus for cross-project coordination
- Domain-specific skills unique to your team

## Adding a new role

1. Create `roles/[role-name]/` with subdirectories: `workflows/`, `skills/`, `claude-skills/`, `standards/`, `prompts/`
2. Add a `README.md` describing the role
3. Update the Roles table in the main `README.md`
4. Follow the version bump rules above

## Code of conduct

Be respectful and constructive. We're all here to make AI agents better at their job.
