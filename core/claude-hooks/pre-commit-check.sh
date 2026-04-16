#!/usr/bin/env bash
# agentskel pre-commit enforcement hook
# Blocks git commit if task-completion artifacts are missing.
# Installed to .claude/hooks/ by setup-skeleton.
set -euo pipefail

# Read the tool input from stdin (Claude Code passes JSON with tool details)
INPUT=$(cat)

# Only check commits on the project branch, not ai-memory.
# git branch --show-current runs in the project root (always returns main),
# so also check: (a) the .memory worktree's own branch, and (b) the commit command path.
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
MEMORY_BRANCH=$(git -C .memory branch --show-current 2>/dev/null || echo "")
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

if [ "$BRANCH" = "ai-memory" ] || [ "$MEMORY_BRANCH" = "ai-memory" ] || echo "$COMMAND" | grep -q '\.memory'; then
    exit 0
fi

# Check if this is a merge commit or amend (skip enforcement)
COMMIT_MSG=$(echo "$INPUT" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 || true)
if echo "$COMMIT_MSG" | grep -q '\-\-amend\|merge'; then
    exit 0
fi

ERRORS=""

# Check if .memory/CHANGELOG.md was modified in this session
# Use --since with a wide window (8 hours) to cover long sessions
if [ -d ".memory" ]; then
    RECENT_CHANGELOG=$(cd .memory && git log --since="8 hours ago" --name-only --format="" 2>/dev/null | grep "CHANGELOG.md" || true)
    if [ -z "$RECENT_CHANGELOG" ]; then
        ERRORS="${ERRORS}.memory/CHANGELOG.md not updated. "
    fi

    RECENT_TIMELOG=$(cd .memory && git log --since="8 hours ago" --name-only --format="" 2>/dev/null | grep "TIME_LOG.md" || true)
    if [ -z "$RECENT_TIMELOG" ]; then
        ERRORS="${ERRORS}.memory/TIME_LOG.md not updated. "
    fi
fi

# Skeleton-only checks: VERSION must match README and MASTER_PLAN
# Only runs when Skeleton Path = . (this IS the skeleton repo)
if [ -f ".memory/CONFIG.md" ] && grep -q 'Skeleton Path.*\.' .memory/CONFIG.md 2>/dev/null; then
    if [ -f "VERSION" ]; then
        SKEL_VERSION=$(cat VERSION | tr -d '[:space:]')

        # Check README version marker
        if [ -f "README.md" ]; then
            README_VERSION=$(grep -oP 'v\K[0-9]+\.[0-9]+' README.md | head -1 || echo "")
            if [ -n "$README_VERSION" ] && [ "$README_VERSION" != "$SKEL_VERSION" ]; then
                ERRORS="${ERRORS}README.md version (v${README_VERSION}) != VERSION (${SKEL_VERSION}). "
            fi
        fi

        # Check MASTER_PLAN version marker
        if [ -f "MASTER_PLAN.md" ]; then
            MP_VERSION=$(grep -oP 'Corresponds to: agentskel v\K[0-9]+\.[0-9]+' MASTER_PLAN.md || echo "")
            if [ -n "$MP_VERSION" ] && [ "$MP_VERSION" != "$SKEL_VERSION" ]; then
                ERRORS="${ERRORS}MASTER_PLAN.md version (v${MP_VERSION}) != VERSION (${SKEL_VERSION}). "
            fi
        fi
    fi
fi

if [ -n "$ERRORS" ]; then
    echo "${ERRORS}Fix before committing." >&2
    exit 2
fi

exit 0
