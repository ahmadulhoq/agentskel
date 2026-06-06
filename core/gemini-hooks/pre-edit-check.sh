#!/usr/bin/env bash
# Advisory plan-gate check — non-blocking (Gemini CLI variant).
# Wired via .gemini/settings.json BeforeTool hook on `replace` and `write_file`.
#
# Gemini contract: stdout MUST be JSON only. We allow, but inject a systemMessage
# so the reminder is visible in the terminal. stderr could carry logs but the
# user-visible reminder lives in systemMessage.
set -euo pipefail

# We don't need stdin for an advisory check — but Gemini sends JSON; read and discard.
cat >/dev/null 2>&1 || true

printf '{"decision":"allow","systemMessage":"PLAN CHECK (agentskel): Before editing — have you presented a plan and received explicit approval (\\"go ahead\\" / \\"do it\\" / \\"proceed\\") in the current exchange? If not, stop and present a plan first."}\n'
exit 0
