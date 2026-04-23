---
name: setup-confluence
description: When the user needs to configure Confluence integration for this project. Use when wiring up the Atlassian MCP to .memory/CONFIG.md so ADRs, runbooks, postmortems, and specs can be auto-published to the right space and parent pages.
---

# Setup Confluence

Populate the Confluence section of `.memory/CONFIG.md` by introspecting the team's Confluence space via the Atlassian MCP. This workflow discovers the target space, auto-suggests parent pages for each doc type (Specs, ADRs, Runbooks, Postmortems), and records per-doc-type auto-publish preferences.

**Prerequisites:**
- Atlassian MCP connected. See `docs/ATLASSIAN-SETUP.md`.
- `atlassian-integration` skill available for all Atlassian calls.

## Pre-Flight

- [ ] Read `.memory/RULES.md`
- [ ] Read `.memory/MAP.md`
- [ ] Read `.memory/SYMBOLS.md`
- [ ] Read `.memory/RESUME.md`
- [ ] Read `.memory/LESSONS.md`
- [ ] Read `.memory/SACRED.md`
- [ ] Verify Atlassian MCP is connected — try `atlassianUserInfo`. If it fails, stop and refer the user to `docs/ATLASSIAN-SETUP.md`.
- [ ] Read `.memory/CONFIG.md` and note the current state of the Atlassian Integration section.

## Step 1 — Auto-detect space

- [ ] Call `getConfluenceSpaces` to list available spaces.
- [ ] Present the list to the user: "Which Confluence space should this project use?"
- [ ] Record the chosen space key for use downstream (will be written to CONFIG.md `Confluence Space Key` in Step 5).

## Step 2 — Find parent pages (auto-suggest)

Use `searchConfluenceUsingCql` within the chosen space to find likely parent pages for each doc type:

- [ ] Specs parent — CQL: `space = {key} AND title ~ "specs"`
- [ ] ADRs parent — CQL: `space = {key} AND title ~ "architecture decision"` OR `space = {key} AND title ~ "ADR"`
- [ ] Runbooks parent — CQL: `space = {key} AND title ~ "runbook"`
- [ ] Postmortems parent — CQL: `space = {key} AND title ~ "postmortem"` OR `space = {key} AND title ~ "post-mortem"`
- [ ] Present findings to the user: "Found these candidates for each. Use them or specify different?"

## Step 3 — Confirm each parent

For each of the 4 doc types (Specs, ADRs, Runbooks, Postmortems):

- [ ] Show the suggested candidate page (title + page ID).
- [ ] Ask the user: "Use [title]? Or provide a different page title / ID? Or skip this doc type?"
- [ ] If skipped, record that this doc type will not be auto-published. The user will publish manually to Confluence instead.

## Step 4 — Publish preferences

Ask the user which doc types the agent should auto-publish when documents are generated:

- [ ] ADRs: y/n
- [ ] Runbooks: y/n
- [ ] Postmortems: y/n
- [ ] Release notes: y/n
- [ ] Feature specs (from `brainstorm-feature`): y/n

The user can answer no to all and still publish manually via `publish-adr`, `publish-postmortem`, etc.

## Step 5 — Update CONFIG.md

- [ ] Write the chosen space key to the Atlassian Integration section of `.memory/CONFIG.md` under `Confluence Space Key`.
- [ ] Write each confirmed parent page (ID + title) under the corresponding key: `Confluence Specs Parent`, `Confluence ADRs Parent`, `Confluence Runbooks Parent`, `Confluence Postmortems Parent`.
- [ ] Leave skipped parents blank. Workflows must skip publication when a parent is blank.
- [ ] Record the auto-publish preferences from Step 4 under a clearly-named subsection (e.g. `Confluence Auto-Publish`).

## Step 6 — Confirm and commit

- [ ] Show the updated Atlassian section of `.memory/CONFIG.md` to the user for confirmation.
- [ ] Commit memory changes to the `ai-memory` branch.
- [ ] Suggest next steps: "Run `setup-team` or `setup-jira` if you haven't yet."

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.
