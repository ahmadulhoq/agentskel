#!/usr/bin/env bash
# agentskel pre-memory-push enforcement hook (Gemini CLI variant)
# Auto-pulls before any push to ai-memory to prevent non-fast-forward errors.
# Wired via .gemini/settings.json BeforeTool hook on run_shell_command.
#
# Gemini I/O contract: see pre-commit-check.sh comment.
set -euo pipefail

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | python3 -c "
import sys,json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

allow() {
    printf '{"decision":"allow"}\n'
    exit 0
}

# Not a push to ai-memory — allow
if ! echo "$COMMAND" | grep -qE 'git[[:space:]].*push.*ai-memory'; then
    allow
fi

# Auto-pull with rebase before the push proceeds.
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

allow
