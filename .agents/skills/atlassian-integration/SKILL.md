---
name: atlassian-integration
license: MIT
description: When reading or writing to Jira tickets or Confluence pages via MCP tools. Use before any Jira transition, ticket creation, or Confluence page update to avoid common failure modes.
---

# Atlassian Integration

**Purpose:** Use Atlassian MCP tools correctly. Four known failure modes — this skill blocks all four.

## When to use

Any workflow that reads or writes Jira or Confluence via MCP. This includes:
- Reading a ticket to understand requirements
- Transitioning ticket status
- Creating new tickets (tech debt, follow-ups)
- Publishing ADRs, postmortems, specs to Confluence
- Commenting on tickets with PR links or status

## Prerequisites

- Atlassian MCP connected in your AI tool. Two options:
  - **Rovo Cloud** (official, OAuth) — tool names start with `getJiraIssue`, `createJiraIssue`, etc.
  - **sooperset self-hosted** (for Data Center / DC) — tool names start with `jira_get_issue`, `jira_create_issue`, etc.
- This skill references actions abstractly ("the get-issue tool"). Agent uses whichever is available.
- See `docs/ATLASSIAN-SETUP.md` for per-tool MCP setup.

## Step 1 — Before transitioning a ticket

- [ ] Call the **list-transitions tool** for the specific ticket (`getTransitionsForJiraIssue` on Rovo, equivalent on sooperset).
- [ ] Match the desired event to the actual transition name in the response. Team workflows differ — "In Progress" on one project is "Started" on another.
- [ ] Only then call the **transition tool** with the valid transition ID.

**Why:** hardcoded status names fail on custom workflows. Transitions are workflow-specific, not global.

## Step 2 — Before creating a ticket

- [ ] Call the **issue type metadata tool** (`getJiraIssueTypeMetaWithFields` on Rovo) for the project + issue type.
- [ ] Note which fields are required (often includes custom fields: epic link, components, fix version, etc.).
- [ ] Populate all required fields per `.memory/JIRA_WORKFLOW.md` conventions.
- [ ] Then call the **create-issue tool**.

**Why:** required custom fields vary per project. Skipping this step gives cryptic `"customfield_12345 is required"` errors.

## Step 3 — When reading Confluence content

- [ ] Expect body format to vary: Rovo returns Markdown; sooperset may return wiki markup or ADF.
- [ ] If the content looks structured (tables, code blocks), validate the format before piping into agent context.
- [ ] For large pages (>50KB), consider using search tools (`searchConfluenceUsingCql`, `search`) to find the specific section rather than loading the whole page.

## Step 4 — When updating Confluence pages

- [ ] **`updateConfluencePage` silently truncates content >5KB.** Verified in production use.
- [ ] For large additions, do one of:
  - Use `createConfluencePage` for a new child page instead
  - Use the comment tools (`createConfluenceFooterComment`, `createConfluenceInlineComment`) for substantial additions
  - Split content across multiple smaller pages
- [ ] Always verify after update by fetching the page and checking size.

## Step 5 — Rate limits

- [ ] Honor `Retry-After` response headers.
- [ ] Exponential backoff with jitter: 2s → 4s → 8s → 16s, multiplier 0.7-1.3.
- [ ] Cap retries at 4.
- [ ] Only retry idempotent operations. Never immediately retry per-issue-write 429s (Atlassian's per-issue bucket unblocks slowly).
- [ ] Cache metadata (issue types, transitions, account ID lookups) — they change rarely.

## Common Rationalizations

| Rationalization | Why it's wrong | Do this instead |
|---|---|---|
| "Transitions are the same across projects, I'll just use 'In Progress'" | Custom workflows rename statuses. 'In Progress' may not exist. | Always call the list-transitions tool first. |
| "I know the required fields, I'll skip the metadata call" | Projects add required custom fields without notice. | Always call metadata before create-issue. |
| "Confluence page should fit in 5KB" | Agent-generated content easily exceeds 5KB with tables or logs. Silent truncation loses content. | Use comments or child pages for large content. |
| "I'll just retry the 429" | Per-issue write 429s unblock slowly; immediate retry makes it worse. | Honor Retry-After, long backoff. |
| "The tool names differ — I'll hardcode Rovo names" | Teams on Data Center use sooperset with different names. | Reference actions abstractly; adapt to available tools. |

**Gate:** Before any Jira write or Confluence update, verify the relevant pre-action check in Steps 1–4 has been performed.
