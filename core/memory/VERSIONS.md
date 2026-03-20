# Dependency & Toolchain Versions
> Managed by: AI Agent
> Policy: see `DEPENDENCY_MANAGEMENT.md` in the project's standards

This file tracks the current toolchain and key dependency versions for this project. The agent updates this file after each successful upgrade. Humans use it to understand the current state at a glance.

The **Release Notes** column must be populated for every row. The agent reads the release notes before any upgrade decision — never rely on version numbers alone.

---

## Toolchain

| Component | Current | Release Notes | Notes |
|-----------|---------|---------------|-------|
| [PLATFORM_TOOLCHAIN_1] | x.y.z | [Release Notes](URL) | |
| [PLATFORM_TOOLCHAIN_2] | x.y.z | [Release Notes](URL) | |

---

## Key Dependencies

| Dependency | Current | Release Notes | Notes |
|-----------|---------|---------------|-------|
| [DEPENDENCY_1] | x.y.z | [Release Notes](URL) | |
| [DEPENDENCY_2] | x.y.z | [Release Notes](URL) | |

---

## Upgrade Log

| Date | Component | From | To | Tier | PR |
|------|-----------|------|----|------|----|
| YYYY-MM-DD | example | 1.0 | 1.1 | Patch | #123 |

---

## Flags

Items that need attention. The agent adds rows here when an upgrade is overdue or a security advisory is found.

| Component | Issue | Severity | Action Needed |
|-----------|-------|----------|--------------|
