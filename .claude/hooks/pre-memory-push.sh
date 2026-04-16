#!/usr/bin/env bash
# agentskel pre-memory-push enforcement hook
# Auto-pulls before any push to ai-memory to prevent non-fast-forward errors.
# Runs as a PreToolUse hook — fires before the push executes.
set -euo pipefail

# Read tool input from stdin
INPUT=$(cat)

# Extract the command being run
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Only act on pushes to ai-memory
if ! echo "$COMMAND" | grep -q 'push.*ai-memory'; then
    exit 0
fi

# Auto-pull with rebase before the push proceeds
# Skip if there are uncommitted changes (the command chain will commit first)
if [ -d ".memory" ]; then
    DIRTY=$(git -C .memory status --porcelain 2>/dev/null || echo "")
    if [ -z "$DIRTY" ]; then
        PULL_OUTPUT=$(git -C .memory pull --rebase origin ai-memory 2>&1) || {
            echo "Pre-push pull failed: ${PULL_OUTPUT}. Resolve conflicts in .memory/ before pushing." >&2
            exit 2
        }
    fi
fi

# Allow the push to proceed
exit 0
