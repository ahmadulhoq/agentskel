#!/usr/bin/env bash
# Advisory plan-gate check (Windsurf variant).
# Wired via .windsurf/hooks.json `pre_write_code` event.
# Non-blocking — informational message to stderr (visible if show_output: true).
set -euo pipefail

# Discard stdin (not needed for advisory reminder)
cat >/dev/null 2>&1 || true

echo "PLAN CHECK (agentskel): Before continuing edits — have you presented a plan and received explicit approval (\"go ahead\" / \"do it\" / \"proceed\") in the current exchange? If not, stop and present a plan first." >&2
exit 0
