#!/usr/bin/env bash
# Advisory plan-gate check — non-blocking (exit 0).
# Reminds the agent to verify explicit approval before any file edit.
set -euo pipefail
printf "PLAN CHECK (agentskel): Before editing — have you presented a plan and received explicit approval (\"go ahead\" / \"do it\" / \"proceed\") in the current exchange? If not, stop and present a plan first.\n"
exit 0
