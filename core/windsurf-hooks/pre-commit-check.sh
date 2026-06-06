#!/usr/bin/env bash
# agentskel pre-commit enforcement hook (Windsurf variant).
# Wired via .windsurf/hooks.json `pre_run_command` event.
#
# Windsurf I/O contract:
#   - stdin: JSON {agent_action_name, tool_info: {command_line, cwd}, ...}
#   - stdout: informational (shown in UI if show_output: true)
#   - stderr: error / rejection reason
#   - exit 0 = allow; exit 2 = block (pre-hooks only); other = error, allow
#
# Note: Windsurf nests under `tool_info.command_line` (NOT `tool_input.command`
# like Claude/Codex). Pre-v1.62.2 used Claude scripts here and never saw the
# command — silently allowing everything.
set -euo pipefail

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | python3 -c "
import sys,json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_info', {}).get('command_line', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

# Not a git commit — allow
if ! echo "$COMMAND" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
    exit 0
fi

# Only check commits on project branch, not ai-memory
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
MEMORY_BRANCH=$(git -C .memory branch --show-current 2>/dev/null || echo "")
if [ "$BRANCH" = "ai-memory" ] || [ "$MEMORY_BRANCH" = "ai-memory" ] || echo "$COMMAND" | grep -q '\.memory'; then
    exit 0
fi

# Skip merge commits or amends
if echo "$COMMAND" | grep -qE '\-\-amend|merge'; then
    exit 0
fi

ERRORS=""

if [ -d ".memory" ]; then
    DIRTY=$(git -C .memory status --porcelain 2>/dev/null || echo "")
    CHANGELOG_RECENT=$(git -C .memory log -1 --name-only --format="" 2>/dev/null | grep "^CHANGELOG.md$" || true)
    CHANGELOG_DIRTY=$(echo "$DIRTY" | grep " CHANGELOG.md$" || true)
    if [ -z "$CHANGELOG_RECENT" ] && [ -z "$CHANGELOG_DIRTY" ]; then
        ERRORS="${ERRORS}.memory/CHANGELOG.md not updated for this task. "
    fi

    TIMELOG_RECENT=$(git -C .memory log -1 --name-only --format="" 2>/dev/null | grep "^TIME_LOG.md$" || true)
    TIMELOG_DIRTY=$(echo "$DIRTY" | grep " TIME_LOG.md$" || true)
    if [ -z "$TIMELOG_RECENT" ] && [ -z "$TIMELOG_DIRTY" ]; then
        ERRORS="${ERRORS}.memory/TIME_LOG.md not updated for this task. "
    fi
fi

# Skeleton-only checks
if [ -f ".memory/CONFIG.md" ] && grep -q 'Skeleton Path.*\.' .memory/CONFIG.md 2>/dev/null; then
    if [ -f "VERSION" ]; then
        SKEL_VERSION=$(cat VERSION | tr -d '[:space:]')
        if [ -f "README.md" ]; then
            README_VERSION=$(grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' README.md | head -1 | sed 's/^v//' || echo "")
            if [ -n "$README_VERSION" ] && [ "$README_VERSION" != "$SKEL_VERSION" ]; then
                ERRORS="${ERRORS}README.md version (v${README_VERSION}) != VERSION (${SKEL_VERSION}). "
            fi
        fi
        if [ -f "MASTER_PLAN.md" ]; then
            MP_VERSION=$(grep -oE 'Corresponds to: agentskel v[0-9]+\.[0-9]+(\.[0-9]+)?' MASTER_PLAN.md | sed 's/^Corresponds to: agentskel v//' || echo "")
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
