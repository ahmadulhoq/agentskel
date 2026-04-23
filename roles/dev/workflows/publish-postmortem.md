---
name: publish-postmortem
description: When a production incident has been resolved and needs a written post-mortem. Use after the `hotfix` workflow completes, to publish a structured post-mortem to Confluence, optionally create Jira tickets for action items, and cross-link findings from LESSONS.md.
---

# Publish Postmortem

Write a post-mortem for a production incident to Confluence. Optionally create Jira tickets for each action item, cross-reference related tickets, and record the lesson in `.memory/LESSONS.md`.

**Prerequisites:**
- `.memory/CONFIG.md` has `Confluence Space Key` and `Confluence Postmortems Parent` set. If not, run `setup-confluence` first.
- Atlassian MCP connected.
- `atlassian-integration` skill available for all Atlassian calls.

**Inputs:** Incident summary. Typically invoked after the `hotfix` workflow resolves a production issue.

## Pre-Flight

- [ ] Read `.memory/RULES.md`
- [ ] Read `.memory/MAP.md`
- [ ] Read `.memory/SYMBOLS.md`
- [ ] Read `.memory/RESUME.md`
- [ ] Read `.memory/LESSONS.md`
- [ ] Read `.memory/SACRED.md`
- [ ] Verify Atlassian MCP is connected — try `atlassianUserInfo`.
- [ ] Verify Confluence setup is complete — read `.memory/CONFIG.md` and confirm `Confluence Space Key` and `Confluence Postmortems Parent` are set. If either is missing, stop and suggest running `setup-confluence`.

## Step 1 — Gather incident details

Ask the user each of the following. Do not fabricate history.

- [ ] Title: "Title? (e.g. 'Prayer times off by 1 minute on DST boundary — 2026-04-20')"
- [ ] Date/time of incident: "When did it start? When was it resolved?"
- [ ] Summary: "One-paragraph summary of what happened"
- [ ] Timeline: "Key events in chronological order" (list with timestamps)
- [ ] Root cause: "What was the underlying cause?"
- [ ] What worked: "What parts of our response went well?"
- [ ] What didn't work: "What parts were slow, incorrect, or missing?"
- [ ] Action items: "What are we doing to prevent recurrence?" (list, each with an owner)
- [ ] Related tickets/commits: "Any related Jira tickets or PRs to cross-reference?"

## Step 2 — Generate postmortem markdown

Build the body using the standard postmortem format:

```
# Postmortem: [Title]

## Summary
[Summary]

## Timeline
[Events with timestamps]

## Root cause
[Root cause]

## What worked
[What worked]

## What didn't work
[What didn't]

## Action items
- [ ] [Item] — Owner: [name]
...

## Related
- Incident ticket: [key]
- Fix PR: [URL]
- Related: [other links]
```

- [ ] Preserve user wording; do not paraphrase sensitive details away.

## Step 3 — Publish to Confluence

- [ ] Use the `atlassian-integration` skill to call `createConfluencePage`:
  - Space: `.memory/CONFIG.md` `Confluence Space Key`
  - Parent: `.memory/CONFIG.md` `Confluence Postmortems Parent`
  - Title: `Postmortem: [Title]`
  - Body: the markdown from Step 2
- [ ] Capture the new page URL.

## Step 4 — Create Jira tickets for action items (optional)

- [ ] Ask the user: "Create Jira tickets for the action items? (y/n)"
- [ ] If yes, for each action item use the `atlassian-integration` skill to call `createJiraIssue`:
  - Project: `.memory/CONFIG.md` `Jira Project Key`
  - Summary: `[Postmortem action] — {item text}`
  - Assignee: owner from the action item (look up Jira account ID via `.memory/TEAM.md`)
  - Label: `postmortem-action`
  - Description: include a link back to the postmortem Confluence page
- [ ] Capture the created ticket keys.

## Step 5 — Cross-reference tickets

For any related Jira tickets the user provided in Step 1:

- [ ] Use the `atlassian-integration` skill to call `addCommentToJiraIssue` on each related ticket.
- [ ] Comment body: link to the postmortem Confluence page with a one-line context.

## Step 6 — Cross-link in LESSONS.md

- [ ] Read `.memory/LESSONS.md`.
- [ ] Append a one-line entry:
  `- Postmortem ([Title]): [root cause gist]. See: [Confluence URL]. Action items: [count]`
- [ ] Preserve existing LESSONS.md content.

## Step 7 — Confirm and commit

- [ ] Show the user the Confluence URL and the list of action item ticket keys (if created).
- [ ] Commit the LESSONS.md change to the `ai-memory` branch.

## Final Step — Task Completion Checklist

This workflow produces an external side effect (a Confluence postmortem page, and optionally Jira action-item tickets) that the task-completion applicability gate cannot detect from `git status`. Invoke `task-completion` explicitly — its Step 0 exception for workflow-invoked runs applies. Run every step (CHANGELOG, TIME_LOG, RESUME, memory commit) before responding to the user.
