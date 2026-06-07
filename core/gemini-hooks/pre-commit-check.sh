#!/usr/bin/env bash
# agentskel pre-commit enforcement hook (Gemini CLI variant)
# Blocks git commit if task-completion artifacts are missing.
# Wired via .gemini/settings.json BeforeTool hook on run_shell_command.
#
# Gemini I/O contract:
#   - stdin: JSON with tool_name, tool_input.command, cwd, etc.
#   - stdout: JSON only (NO plain text — silence is mandatory).
#   - stderr: free for logs and the rejection reason on exit 2.
#   - exit 0 + JSON {"decision":"allow"} → proceed
#   - exit 2 + stderr → block tool, stderr text becomes the rejection reason
set -euo pipefail

INPUT=$(cat)

# Extract command from the Gemini bash tool input
COMMAND=$(echo "$INPUT" | python3 -c "
import sys,json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

# Helper: emit JSON allow and exit 0
allow() {
    printf '{"decision":"allow"}\n'
    exit 0
}

# Not a git commit — allow
if ! echo "$COMMAND" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
    allow
fi

# Only check commits on project branch, not ai-memory
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
MEMORY_BRANCH=$(git -C .memory branch --show-current 2>/dev/null || echo "")

# Strip -m "..." / -m '...' / --message variants so structural checks below
# don't accidentally match commit message text (see claude-hooks notes).
CMD_STRUCT=$(echo "$COMMAND" | sed -E 's/-m[[:space:]]+"[^"]*"//g; s/-m[[:space:]]+'\''[^'\'']*'\''//g; s/--message[[:space:]]+"[^"]*"//g; s/--message[[:space:]]+'\''[^'\'']*'\''//g')

if [ "$BRANCH" = "ai-memory" ] || [ "$MEMORY_BRANCH" = "ai-memory" ] || \
   echo "$CMD_STRUCT" | grep -qE '(^|[[:space:];&|])cd[[:space:]]+\.memory(/|[[:space:]]|$)|git[[:space:]]+-C[[:space:]]+\.memory(/|[[:space:]]|$)'; then
    allow
fi

# Skip merge commits or amends (flag/command match only — not message text)
if echo "$CMD_STRUCT" | grep -qE '(^|[[:space:]])--amend([[:space:]]|$)|(^|[;&|[:space:]])git[[:space:]]+merge([[:space:]]|$)'; then
    allow
fi

ERRORS=""

# CHANGELOG/TIME_LOG checks (identical logic to Claude variant)
if [ -d ".memory" ]; then
    DIRTY=$(git -C .memory status --porcelain 2>/dev/null || echo "")
    CHANGELOG_RECENT=$(git -C .memory log -1 --name-only --format="" 2>/dev/null | grep "^CHANGELOG.md$" || true)
    CHANGELOG_DIRTY=$(echo "$DIRTY" | grep " CHANGELOG.md$" || true)
    if [ -z "$CHANGELOG_RECENT" ] && [ -z "$CHANGELOG_DIRTY" ]; then
        ERRORS="${ERRORS}.memory/CHANGELOG.md not updated for this task. "
    fi

    TIMELOG_RECENT=$(git -C .memory log -1 --name-only --format="" 2>/dev/null | grep "^TIME_LOG.md$" || true)
    TIMELOG_DIRTY=$(echo "$DIRTY" | grep " TIME_LOG.md$" || true)
    if [ -z "$TIMELOG_RECENT" ] && [ -z "$TIMELOG_DIRTY" ]; then
        ERRORS="${ERRORS}.memory/TIME_LOG.md not updated for this task. "
    fi
fi

# Skeleton-only checks: VERSION must match README and MASTER_PLAN.
# Strict match for `| Skeleton Path | . |` (see claude-hooks notes for the
# pre-v1.63.2 false-positive regex bug fixed here).
if [ -f ".memory/CONFIG.md" ] && grep -qE '^\|[[:space:]]+Skeleton Path[[:space:]]+\|[[:space:]]+\.[[:space:]]+\|' .memory/CONFIG.md 2>/dev/null; then
    if [ -f "VERSION" ]; then
        SKEL_VERSION=$(cat VERSION | tr -d '[:space:]')
        if [ -f "README.md" ]; then
            README_VERSION=$(grep -oE 'v[0-9]+\.[0-9]+(\.[0-9]+)?' README.md | head -1 | sed 's/^v//' || echo "")
            if [ -n "$README_VERSION" ] && [ "$README_VERSION" != "$SKEL_VERSION" ]; then
                ERRORS="${ERRORS}README.md version (v${README_VERSION}) != VERSION (${SKEL_VERSION}). "
            fi
        fi
        if [ -f "MASTER_PLAN.md" ]; then
            MP_VERSION=$(grep -oE 'Corresponds to: agentskel v[0-9]+\.[0-9]+(\.[0-9]+)?' MASTER_PLAN.md | sed 's/^Corresponds to: agentskel v//' || echo "")
            if [ -n "$MP_VERSION" ] && [ "$MP_VERSION" != "$SKEL_VERSION" ]; then
                ERRORS="${ERRORS}MASTER_PLAN.md version (v${MP_VERSION}) != VERSION (${SKEL_VERSION}). "
            fi
        fi
    fi
fi

# Multi-line YAML description lint (matches Claude variant)
STAGED=$(git diff --cached --name-only 2>/dev/null || true)
if [ -n "$STAGED" ]; then
    BAD=$(echo "$STAGED" | python3 - <<'PY' 2>/dev/null || true
import sys, re, os
pattern = re.compile(r'^description:.*\n[ \t]+\S', re.MULTILINE)
bad = []
for line in sys.stdin.read().splitlines():
    line = line.strip()
    if not line.endswith('.md'):
        continue
    if not (line.endswith('/SKILL.md') or '/workflows/' in line):
        continue
    if not os.path.isfile(line):
        continue
    with open(line) as f:
        text = f.read()
    if pattern.search(text):
        bad.append(line)
if bad:
    print("; ".join(bad))
PY
)
    if [ -n "$BAD" ]; then
        ERRORS="${ERRORS}Multi-line YAML description in: ${BAD}. Collapse to a single line (required for stub + catalog generation). "
    fi
fi

if [ -n "$ERRORS" ]; then
    # Block: stderr becomes the reason sent to the agent
    echo "${ERRORS}Fix before committing." >&2
    exit 2
fi

allow
