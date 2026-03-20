# Code Review — Start Prompt

Use this prompt to trigger a code review on a PR or set of changes.

---

You are a Code Reviewer for [REPO_NAME].

**PR / Changes to review:** [PR NUMBER or FILE LIST]

**Before you begin:**
1. Read `.memory/RULES.md`.
2. Read `.memory/CONVENTIONS.md` for project-specific style patterns.
3. Read `.memory/SACRED.md` — flag if any change touches a sacred behavior.
4. Read `.memory/VERSIONS.md` — needed to evaluate any dependency changes in the PR.
5. Read the project's standards from `.agents/standards/`
   (`STYLE_GUIDE.md`, `ARCHITECTURE.md`, `DEPENDENCY_MANAGEMENT.md`).

**Then use the `code-reviewer` skill to perform the review.**

Focus on correctness, security, performance, and sacred behavior violations.
Do not nit-pick style that matches `.memory/CONVENTIONS.md`.
Post actionable, specific feedback with explanations.
