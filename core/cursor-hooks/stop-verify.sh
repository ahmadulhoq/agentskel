#!/usr/bin/env bash
# agentskel stop verification hook
# Reminds agent to check task-completion before finishing.
# Works across Cursor, Windsurf, Copilot, Codex.

echo "Before finishing: check if APPLICATION code was modified. If yes, verify .memory/CHANGELOG.md and .memory/TIME_LOG.md were updated. Do NOT require these for skeleton syncs, discussion, or infrastructure chores." >&2
exit 0
