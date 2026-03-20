---
activation: always
description: Rules specific to the agentskel repository. Never overwritten by setup or sync.
---

# Repo Rules — agentskel

These rules apply only to this repository. They survive skeleton syncs because
this file has no upstream template.

## Architecture Documentation

When a change affects **architecture** (file layout, entry points, discovery
mechanisms, how rules/skills/workflows are structured, memory system design),
update `MASTER_PLAN.md` with the relevant details. The MASTER_PLAN is the
authoritative ADR (Architecture Decision Record) for agentskel — it documents
every design decision, the reasoning behind it, and the full system structure.

## Scope

This repo contains zero application code. Every change here affects all
downstream project repos that install from this skeleton. Work with extra care.
