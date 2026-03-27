# agentskel — Project Rules

> Framework rules live in `.agents/rules/` (always active).
> This file is for **project-specific overrides and context** only.

## Project Context
agentskel is a framework that provides AI agents with structured workflows,
skills, rules, standards, and memory management. It installs into downstream
projects via `setup-skeleton` and keeps them in sync via `sync-skeleton`.
The goal is consistent, high-quality agent behavior across all projects.

## Project Rules
- **MASTER_PLAN Maintenance:** Before completing any skeleton change, read
  `MAINTAIN_MASTER_PLAN.md` and check each trigger against the change. If any
  trigger matches, update `MASTER_PLAN.md` content AND its `Corresponds to:`
  version marker. Do not bump the marker without verifying the content is
  current. This is a mechanical check — always read the trigger list.
