---
activation: always
description: Project-specific rules unique to the agentskel repository.
---

# Repo-Specific Rules — agentskel

## This Repo IS the Skeleton
- agentskel is the source skeleton. Changes here propagate to all downstream projects.
- Every file change must consider downstream impact.
- Every structural change (added/removed workflow, skill, standard, memory template)
  must bump VERSION and update CHANGELOG.md.

## No Project-Specific Content
- All templates must use placeholder tokens (`[APP_NAME]`, `[PLATFORM]`, etc.).
- Never hardcode project names, domains, or platform-specific content outside
  of `<!-- PLATFORM: X -->` markers.
- Examples in templates should be generic (e.g., "UserRepository", not "PrayerTimeRepository").

## Platform Markers
- Multi-platform content uses `<!-- PLATFORM: X -->` / `<!-- END PLATFORM: X -->` HTML comments.
- The setup-skeleton workflow trims these during installation on downstream projects.
- Keep universal content outside platform markers.
