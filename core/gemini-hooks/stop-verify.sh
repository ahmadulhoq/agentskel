#!/usr/bin/env bash
# agentskel stop-verify hook (Gemini CLI variant).
# Wired via .gemini/settings.json AfterAgent hook. Surfaces uncommitted
# project / .memory/ changes so the agent runs task-completion before stopping.
#
# Gemini I/O contract: stdout MUST be JSON only. We emit a systemMessage so the
# warning is visible to the user; if there are issues we also set
# decision:"deny" so the model is forced to address them rather than silently
# stop.
set -euo pipefail

# Discard stdin (AfterAgent input — not used)
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
    # Emit a JSON object with the warning, blocking the loop so the agent
    # addresses it. systemMessage shows the warning to the user.
    python3 - <<PY
import json
msg = """agentskel stop check:
$WARNINGS"""
print(json.dumps({
    "decision": "deny",
    "reason": msg,
    "systemMessage": msg,
}))
PY
    exit 0
fi

printf '{"decision":"allow"}\n'
exit 0
