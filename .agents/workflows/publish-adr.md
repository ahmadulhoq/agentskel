---
name: publish-adr
description: When the user has made an architectural decision that needs to be recorded. Use when ending a brainstorm session or finishing `develop-feature` Phase 1 with a significant architectural choice that should be written up as an ADR, published to Confluence, and cross-linked from LESSONS.md.
---

# Publish ADR

Write an Architectural Decision Record (ADR) to Confluence in MADR format and cross-link it from `.memory/LESSONS.md`. Optionally comment on related Jira tickets.

**Prerequisites:**
- `.memory/CONFIG.md` has `Confluence Space Key` and `Confluence ADRs Parent` set. If not, run `setup-confluence` first.
- Atlassian MCP connected.
- `atlassian-integration` skill available for all Atlassian calls.

**Inputs:** Decision title + context. Typically invoked at the end of a brainstorm or `develop-feature` Phase 1 after a significant architectural choice.

## Pre-Flight

- [ ] Read `.memory/RULES.md`
- [ ] Read `.memory/MAP.md`
- [ ] Read `.memory/SYMBOLS.md`
- [ ] Read `.memory/RESUME.md`
- [ ] Read `.memory/LESSONS.md`
- [ ] Read `.memory/SACRED.md`
- [ ] Verify Atlassian MCP is connected — try `atlassianUserInfo`.
- [ ] Verify Confluence setup is complete — read `.memory/CONFIG.md` and confirm `Confluence Space Key` and `Confluence ADRs Parent` are set. If either is missing, stop and suggest running `setup-confluence`.

## Step 1 — Gather ADR content

Ask the user each of the following. Do not assume.

- [ ] Title: "What's the ADR title? (e.g. 'Use X for Y because Z')"
- [ ] Context: "What's the context / problem being solved?"
- [ ] Decision: "What decision did you make?"
- [ ] Consequences: "What are the consequences? (positive, negative, neutral)"
- [ ] Alternatives considered: "What alternatives did you consider and why did you reject them?"
- [ ] Related tickets (optional): "Any related Jira tickets?"

## Step 2 — Generate MADR-format markdown

Build the ADR body using the standard MADR template:

```
# ADR-NNN: [Title]

## Status
Accepted — YYYY-MM-DD

## Context
[Context as entered]

## Decision
[Decision as entered]

## Consequences
[Consequences as entered]

## Alternatives considered
[Alternatives as entered]

## Related
- Jira: [ticket keys if any]
```

- [ ] Use today's date for the Status line.
- [ ] Leave the Related section minimal if no tickets were provided.

## Step 3 — Publish to Confluence

- [ ] Determine the next ADR number (NNN). Call `getConfluencePageDescendants` on the `Confluence ADRs Parent` page and find the maximum existing `ADR-NNN` prefix. New NNN = max + 1, zero-padded to 3 digits.
- [ ] Use the `atlassian-integration` skill to call `createConfluencePage`:
  - Space: `.memory/CONFIG.md` `Confluence Space Key`
  - Parent: `.memory/CONFIG.md` `Confluence ADRs Parent`
  - Title: `ADR-NNN: [Title]`
  - Body: the MADR markdown from Step 2
- [ ] Capture the new page URL.

## Step 4 — Cross-link in LESSONS.md

- [ ] Read `.memory/LESSONS.md`.
- [ ] Append a one-line entry:
  `- ADR-NNN ([Title]): [one-line gist]. See: [Confluence URL]`
- [ ] Preserve all existing content in LESSONS.md.

## Step 5 — Optional: comment on related tickets

If the user provided related Jira tickets in Step 1:

- [ ] For each ticket, use the `atlassian-integration` skill to call `addCommentToJiraIssue`.
- [ ] Comment body: `ADR-NNN documented in Confluence: [URL]`

## Step 6 — Confirm and commit

- [ ] Show the Confluence URL to the user.
- [ ] Commit the LESSONS.md change to the `ai-memory` branch.

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.
