#!/usr/bin/env bash
# agentskel pre-memory-push enforcement hook
# Auto-pulls before any push to ai-memory to prevent non-fast-forward errors.
# Runs as a PreToolUse hook — fires before the push executes.
set -euo pipefail

# Read tool input from stdin
INPUT=$(cat)

# Extract the command being run
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# EXIT EARLY if this is NOT a push to ai-memory.
# Explicit check since the "if" pattern in settings.json is unreliable.
if ! echo "$COMMAND" | grep -qE 'git[[:space:]].*push.*ai-memory'; then
    exit 0
fi

# Auto-pull with rebase before the push proceeds.
# Skip if:
# - .memory/ doesn't exist (not a worktree — nothing to pull into)
# - uncommitted changes (the command chain will commit first)
# - remote ai-memory doesn't exist yet (first push during setup, nothing to pull)
if [ -d ".memory" ]; then
    DIRTY=$(git -C .memory status --porcelain 2>/dev/null || echo "")
    if [ -z "$DIRTY" ]; then
        # Check if remote ai-memory branch exists before attempting pull
        REMOTE_EXISTS=$(git -C .memory ls-remote --heads origin ai-memory 2>/dev/null || echo "")
        if [ -n "$REMOTE_EXISTS" ]; then
            # Skip pull if remote tip is already an ancestor (already merged/rebased in).
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

# Allow the push to proceed
exit 0
