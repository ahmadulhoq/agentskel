#!/usr/bin/env bash
# agentskel pre-commit enforcement hook
# Blocks git commit if task-completion artifacts are missing.
# Installed to .claude/hooks/ by setup-skeleton.
set -euo pipefail

# Read the tool input from stdin (Claude Code passes JSON with tool details)
INPUT=$(cat)

# Only check commits on the project branch, not ai-memory
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ "$BRANCH" = "ai-memory" ]; then
    exit 0
fi

# Check if this is a merge commit or amend (skip enforcement)
COMMIT_MSG=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 || true)
if echo "$COMMIT_MSG" | grep -q '\-\-amend\|merge'; then
    exit 0
fi

ERRORS=""

# Check if .memory/CHANGELOG.md was modified in this session
# Look for recent ai-memory commits (within last hour)
if [ -d ".memory" ]; then
    RECENT_CHANGELOG=$(cd .memory && git log --since="1 hour ago" --name-only --format="" 2>/dev/null | grep "CHANGELOG.md" || true)
    if [ -z "$RECENT_CHANGELOG" ]; then
        ERRORS="${ERRORS}CHANGELOG.md not updated in .memory/. "
    fi

    RECENT_TIMELOG=$(cd .memory && git log --since="1 hour ago" --name-only --format="" 2>/dev/null | grep "TIME_LOG.md" || true)
    if [ -z "$RECENT_TIMELOG" ]; then
        ERRORS="${ERRORS}TIME_LOG.md not updated in .memory/. "
    fi
fi

if [ -n "$ERRORS" ]; then
    echo "${ERRORS}Run task-completion before committing." >&2
    exit 2
fi

exit 0
