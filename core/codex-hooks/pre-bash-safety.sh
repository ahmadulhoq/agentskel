#!/usr/bin/env bash
# agentskel destructive-command hook (Codex variant).
# Wired via .codex/hooks.json PreToolUse on Bash.
#
# Codex I/O contract (same as Claude Code's, verified in v1.62.2):
#   - stdin: JSON with tool_input.command, cwd
#   - exit 2 + stderr = block. Claude's "ask" JSON is NOT assumed to work
#     here, so this wrapper exists only to set AGENTSKEL_NO_ASK=1.
#
# The rules live in ONE place: pre-bash-safety-engine.sh is
# core/claude-hooks/pre-bash-safety.sh, installed next to this file with its
# helpers (pre-bash-heredocs.py, pre-bash-commands.py). This wrapper only
# converts this tool's hook JSON in and the verdict out (v1.69.0).
# Tests: core/claude-hooks/pre-bash-safety-tools.test.sh.
allow() { exit 0; }
block() { printf '%s\n' "$1" >&2; exit 2; }

set -uo pipefail   # not -e: the engine's exit status is the verdict

ENGINE="$(dirname "$0")/pre-bash-safety-engine.sh"
INPUT=$(cat)

# A missing engine is a broken install. Block loudly rather than run every
# command unchecked: a safety hook that silently turns off is never noticed.
if [ ! -f "$ENGINE" ]; then
    block "agentskel pre-bash-safety: rule engine missing ($ENGINE). Re-run sync-skeleton (Step 5n) to reinstall it."
fi

# This tool's hook JSON -> the engine's (Claude Code) input. Reads every
# supported shape, like check-skill-descriptions.py:
#   tool_input.command / command / tool_info.command_line, cwd / tool_info.cwd
ENGINE_INPUT=$(printf '%s' "$INPUT" | python3 -I -c '
import json, sys
sys.stdout.reconfigure(errors="replace")
d = json.load(sys.stdin)
ti, tf = d.get("tool_input") or {}, d.get("tool_info") or {}
cmd = ti.get("command") or d.get("command") or tf.get("command_line") or ""
cwd = d.get("cwd") or tf.get("cwd") or ""
print(json.dumps({"tool_input": {"command": cmd}, "cwd": cwd}))
' 2>/dev/null) || ENGINE_INPUT='{"tool_input":{"command":""}}'

# AGENTSKEL_NO_ASK=1: a merged remote-branch delete is blocked here instead of
# asked (Claude Code's "ask" has no verified equivalent in this tool).
rc=0
MSG=$(printf '%s' "$ENGINE_INPUT" | AGENTSKEL_NO_ASK=1 bash "$ENGINE" 2>&1 >/dev/null) || rc=$?

if [ "$rc" -eq 2 ]; then
    block "$MSG"
fi
allow
