#!/usr/bin/env bash
# Advisory plan-gate check (Cursor variant). Fires afterFileEdit.
# Non-blocking — just surfaces a reminder via user_message.
set -euo pipefail

# Discard stdin (afterFileEdit input not used for the reminder)
cat >/dev/null 2>&1 || true

cat <<'JSON'
{"permission":"allow","user_message":"PLAN CHECK (agentskel): Before continuing edits — have you presented a plan and received explicit approval (\"go ahead\" / \"do it\" / \"proceed\") in the current exchange? If not, stop and present a plan first."}
JSON
exit 0
