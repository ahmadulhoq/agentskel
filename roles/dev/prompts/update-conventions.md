---
name: update-conventions
description: Mission prompt to trigger the update-conventions workflow. Refreshes CONVENTIONS.md against current best practices and files gaps/deviations as NEEDS_REVIEW.
---

# Update Conventions

Run the `update-conventions` workflow: `.agents/workflows/update-conventions.md`.

**Pre-flight reads (before starting the workflow):**
- `.memory/VERSIONS.md` — platform, tech stack, default branch, Last Conventions Check date
- `.memory/CONVENTIONS.md` — current documented patterns
- `.memory/NEEDS_REVIEW.md` — open items (avoid duplicates)
- `.memory/LESSONS.md` — mistakes to avoid
- The matching architecture standard (from `.agents/` or skeleton)

When complete, present the full Step 7 report.
