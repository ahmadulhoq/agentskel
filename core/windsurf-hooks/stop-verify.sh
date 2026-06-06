#!/usr/bin/env bash
# agentskel stop-verify hook (Windsurf variant).
# Wired via .windsurf/hooks.json `post_cascade_response` event.
#
# Note: post_cascade_response is a POST event — per Windsurf docs, post-hooks
# CANNOT block (exit 2 is pre-hooks only). We surface the warning via stderr
# (visible in UI when show_output: true) and exit 0.
set -euo pipefail

# Discard stdin
cat >/dev/null 2>&1 || true

WARNINGS=""

PROJECT_DIRTY=$(git status --porcelain 2>/dev/null | grep -v "^.. \.memory" | grep -v "^$" || true)
if [ -n "$PROJECT_DIRTY" ]; then
    WARNINGS="${WARNINGS}Uncommitted project file changes — run task-completion before finishing:
${PROJECT_DIRTY}
"
fi

if [ -d ".memory" ]; then
    MEMORY_DIRTY=$(git -C .memory status --porcelain 2>/dev/null | grep -v "RESUME.md" | grep -v "^$" || true)
    if [ -n "$MEMORY_DIRTY" ]; then
        WARNINGS="${WARNINGS}Uncommitted .memory/ changes — commit to ai-memory before finishing:
${MEMORY_DIRTY}
"
    fi
fi

if [ -n "$WARNINGS" ]; then
    printf "agentskel stop check:\n%b" "$WARNINGS" >&2
fi

exit 0
