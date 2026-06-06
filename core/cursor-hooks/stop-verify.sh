#!/usr/bin/env bash
# agentskel stop-verify hook (Cursor variant)
# Wired via .cursor/hooks.json stop event. Surfaces uncommitted project /
# .memory/ changes so the agent runs task-completion before stopping.
#
# Cursor I/O contract: JSON on stdout, exit 0.
set -euo pipefail

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
    python3 - <<PY
import json
msg = """agentskel stop check:
$WARNINGS"""
print(json.dumps({
    "permission": "deny",
    "user_message": msg,
    "agent_message": msg,
}))
PY
    exit 0
fi

printf '{"permission":"allow"}\n'
exit 0
