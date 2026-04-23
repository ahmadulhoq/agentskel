---
name: setup-jira
description: When the team needs to configure Jira integration for agentskel. Use when populating `.memory/JIRA_WORKFLOW.md` and the Jira section of `.memory/CONFIG.md` by introspecting the Jira project through Atlassian MCP.
---

# Setup Jira

Populate `.memory/JIRA_WORKFLOW.md` and the Jira section of `.memory/CONFIG.md` by
introspecting the team's Jira project via Atlassian MCP. This workflow auto-detects
the site, maps status transitions to lifecycle events, discovers required fields for
ticket creation, and (if `.memory/TEAM.md` exists) resolves Jira account IDs for team
members so downstream automations can reassign tickets correctly.

**Prerequisites:**
- Atlassian MCP connected in the user's AI tool. See `docs/ATLASSIAN-SETUP.md` for
  connection instructions.
- Use the `atlassian-integration` skill for all MCP calls — do not invoke MCP tools
  directly.
- `.memory/TEAM.md` is optional but recommended. Without it, handoff rules are skipped.

## Pre-Flight

- [ ] Read `.memory/RULES.md` — workflow conventions and non-negotiables.
- [ ] Read `.memory/MAP.md` — current project structure.
- [ ] Read `.memory/SYMBOLS.md` — relevant symbols for memory writers.
- [ ] Read `.memory/RESUME.md` — in-flight work that could conflict.
- [ ] Read `.memory/LESSONS.md` — prior mistakes to avoid.
- [ ] Read `.memory/SACRED.md` — behaviors that must not be changed.
- [ ] Verify MCP connection: use the `atlassian-integration` skill to call
      `atlassianUserInfo`. If it fails, STOP and point the user to
      `docs/ATLASSIAN-SETUP.md`.

## Step 1 — Auto-detect site and project

- [ ] Call `atlassianUserInfo` via the `atlassian-integration` skill to get the
      authenticated user and their accessible sites.
- [ ] Call `getAccessibleAtlassianResources` to list all available site URLs.
- [ ] If exactly one site is accessible, confirm with the user: "Use `{site_url}`?"
- [ ] If multiple sites are accessible, ask: "Which site should I use?" and list them.
- [ ] Ask the user for the Jira project key (e.g. `PROJ`).
- [ ] Call `getVisibleJiraProjects` and verify the key exists in the result. If not,
      STOP and show the user the list of valid keys.

## Step 2 — Branch naming pattern

- [ ] Ask: "Branch naming pattern? (default: `{key}-{slug}`)"
- [ ] Common alternatives to suggest:
  - `{key}/{slug}`
  - `feature/{key}-{slug}`
- [ ] Record the chosen pattern for use in `JIRA_WORKFLOW.md`.

## Step 3 — Introspect status transitions

- [ ] Explain: the Jira API only lists valid transitions from a specific ticket's
      current status, so we need a sample ticket to enumerate the project's workflow.
- [ ] Ask: "Give me any active ticket key from this project (e.g. `{KEY}-123`) so I
      can list your statuses."
- [ ] Call `getJiraIssue(key)` to verify access and capture the current status.
- [ ] Call `getTransitionsForJiraIssue(key)` — returns the list of valid transitions
      with current → target status mappings.
- [ ] Show the user the full list of statuses observed in their workflow so they can
      map events in Step 4.

## Step 4 — Map lifecycle events to transitions

For each of the following events, ask the user to pick the target status from the
list captured in Step 3. For each, also ask whether the transition should auto-apply.

- [ ] "Work started (branch created) → which status?" — e.g. `In Progress`.
- [ ] "Code in review (PR opened) → which status?" — e.g. `In Review`.
- [ ] "Code done, QA handoff (PR merged) → which status?" — e.g. `Ready for QA`.
- [ ] "Fully done (QA approves) → which status?" — e.g. `Done`.
- [ ] "Blocked → which status?" (optional; skip if no such status exists).
- [ ] For each mapped event ask: "Auto-apply at this event? (y/n)".

## Step 5 — Handoff rules (uses TEAM.md)

- [ ] If `.memory/TEAM.md` exists:
  - [ ] Ask: "After PR merge, reassign the ticket to the QA owner from TEAM.md? (y/n)"
  - [ ] Ask: "On blocker, tag the escalation contact from TEAM.md? (y/n)"
- [ ] If `.memory/TEAM.md` does not exist:
  - [ ] Tell the user: "Run `setup-team` first to enable automatic reassignment —
        I'll skip handoff rules for now."
  - [ ] Record in `JIRA_WORKFLOW.md` that handoff rules are disabled.

## Step 6 — Required fields discovery

- [ ] Call `getJiraProjectIssueTypesMetadata(projectKey)` to list the project's
      issue types.
- [ ] For each common issue type (Task, Bug, Story, and any other type the project
      uses), call `getJiraIssueTypeMetaWithFields` and note every field marked
      required.
- [ ] Record in `JIRA_WORKFLOW.md` under "Required fields": for each issue type list
      the required fields in the form "When creating a new ticket of type X, required
      fields: ...".
- [ ] For each required field, ask the user for a default value they want to use
      (e.g. default component, default priority).

## Step 7 — Fill Jira account IDs in TEAM.md

- [ ] If `.memory/TEAM.md` does not exist, skip this step.
- [ ] For each member in `.memory/TEAM.md` who has an email address, call
      `lookupJiraAccountId(email)`.
- [ ] Update the `Jira account` column in the TEAM.md Members table with the
      returned account ID.
- [ ] Flag any member whose email did not match a Jira account so the user can
      correct it manually.

## Step 8 — Write JIRA_WORKFLOW.md

- [ ] Read the template from `[SKELETON_PATH]/core/memory/JIRA_WORKFLOW.md`.
- [ ] Populate the template with:
  - Project section (site URL, project key, branch naming pattern).
  - Status transitions table (lifecycle event → target status → auto-apply flag).
  - Handoff rules (from Step 5).
  - Required fields (from Step 6).
- [ ] Write the populated file to `.memory/JIRA_WORKFLOW.md`.

## Step 9 — Update CONFIG.md

- [ ] Set `Jira Site` = the site URL chosen in Step 1.
- [ ] Set `Jira Project Key` = the project key chosen in Step 1.
- [ ] Leave existing non-Jira fields untouched.

## Step 10 — Confirm and commit

- [ ] Show the generated `JIRA_WORKFLOW.md` to the user for review.
- [ ] Commit the memory changes to the `ai-memory` branch.
- [ ] Suggest: "Run `setup-confluence` next to enable spec/ADR publishing."

## Final Step — Task Completion Checklist

Before responding to the user or starting the next task, run the Task Completion Checklist
from `core-behavior.md`. This is not optional.
