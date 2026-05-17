#!/usr/bin/env bash
# agentskel stop hook — verify no uncommitted changes remain before finishing.
# Exits 0 (allow stop) or 2 (block with message).
# Installed to .claude/hooks/ by setup-skeleton / sync-skeleton.
set -euo pipefail

WARNINGS=""

# Check for uncommitted project file changes (excluding .memory/ worktree)
PROJECT_DIRTY=$(git status --porcelain 2>/dev/null | grep -v "^.. \.memory" | grep -v "^$" || true)
if [ -n "$PROJECT_DIRTY" ]; then
    WARNINGS="${WARNINGS}Uncommitted project file changes — run task-completion before finishing:\n${PROJECT_DIRTY}\n"
fi

# Check for uncommitted .memory/ changes
if [ -d ".memory" ]; then
    MEMORY_DIRTY=$(git -C .memory status --porcelain 2>/dev/null | grep -v "RESUME.md" | grep -v "^$" || true)
    if [ -n "$MEMORY_DIRTY" ]; then
        WARNINGS="${WARNINGS}Uncommitted .memory/ changes — commit to ai-memory before finishing:\n${MEMORY_DIRTY}\n"
    fi
fi

if [ -n "$WARNINGS" ]; then
    printf "agentskel stop check:\n%b" "$WARNINGS" >&2
    exit 2
fi

exit 0
