#!/usr/bin/env bash
# agentskel pre-memory-push enforcement hook (Windsurf variant).
# Wired via .windsurf/hooks.json `pre_run_command` event.
# Auto-pulls --rebase before any push to ai-memory.
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

# Not a push to ai-memory — allow
if ! echo "$COMMAND" | grep -qE 'git[[:space:]].*push.*ai-memory'; then
    exit 0
fi

if [ -d ".memory" ]; then
    DIRTY=$(git -C .memory status --porcelain 2>/dev/null || echo "")
    if [ -z "$DIRTY" ]; then
        REMOTE_EXISTS=$(git -C .memory ls-remote --heads origin ai-memory 2>/dev/null || echo "")
        if [ -n "$REMOTE_EXISTS" ]; then
            REMOTE_TIP=$(git -C .memory rev-parse origin/ai-memory 2>/dev/null || echo "")
            ALREADY_INTEGRATED=""
            if [ -n "$REMOTE_TIP" ]; then
                git -C .memory merge-base --is-ancestor "$REMOTE_TIP" HEAD 2>/dev/null && ALREADY_INTEGRATED=1 || true
            fi
            if [ -z "$ALREADY_INTEGRATED" ]; then
                PULL_OUTPUT=$(git -C .memory pull --rebase origin ai-memory 2>&1) || {
                    echo "Pre-push pull failed: ${PULL_OUTPUT}. Resolve conflicts in .memory/ before pushing." >&2
                    exit 2
                }
            fi
        fi
    fi
fi

exit 0
