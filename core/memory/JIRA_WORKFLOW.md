# Jira workflow

<!-- Managed by setup-jira workflow. Records team's status transitions, handoff rules,
     and required fields for creating new tickets. Agent reads this before any Jira
     write operation. -->

## Project

- **Site:** [JIRA_SITE]
- **Project key:** [PROJECT_KEY]
- **Branch pattern:** [BRANCH_PATTERN]

<!-- Branch pattern placeholders:
     {key}   — ticket key (e.g. PROJ-1234)
     {slug}  — kebab-case slug from ticket title -->

## Status transitions

<!-- Populated by setup-jira via getTransitionsForJiraIssue. Events marked
     "Auto-apply" happen automatically at the named trigger. Others are manual. -->

| Event | From status | To status | Auto-apply? |
|-------|-------------|-----------|-------------|
| Branch created | [STATUS] | [STATUS] | yes/no |
| PR opened | [STATUS] | [STATUS] | yes/no |
| PR merged | [STATUS] | [STATUS] | yes/no |
| QA approves | [STATUS] | [STATUS] | no (always manual) |
| Blocked | any | [STATUS] | no (requires reason) |

## Handoff rules

<!-- How to reassign tickets and notify people at lifecycle events.
     References TEAM.md for owner/role lookups. -->

- **After PR merge:** reassign to module's QA owner (lookup via TEAM.md Ownership table)
- **On blocker:** add comment with reason, transition to blocked status, tag escalation contact from TEAM.md
- **On scope change mid-implementation:** add comment describing the change, tag product lead, do NOT implement without approval

## Required fields (creating new tickets)

<!-- Populated by setup-jira via getJiraIssueTypeMetaWithFields. When agent creates
     tickets (e.g. from cartographer tech-debt findings), these fields must be set. -->

- [field name]: [how to populate — e.g. "always backend", "match module label from TEAM.md", "default P2"]
