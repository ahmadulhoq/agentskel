#!/usr/bin/env bash
# agentskel pre-commit enforcement hook (Cursor variant)
# Wired via .cursor/hooks.json beforeShellExecution event.
#
# Cursor I/O contract:
#   - stdin: JSON with `command`, `cwd`, `sandbox` + common base fields
#   - stdout: JSON {"permission": "allow"|"deny", "user_message", "agent_message"}
#   - exit 0 + JSON = use decision; exit 2 = block; other = fail open
#
# Checks, in order:
#   1. Skill/workflow descriptions <= 1024 chars, in what the commit records
#      (check-skill-descriptions.py, installed next to this script). Runs in
#      every checkout.
#   2. Skeleton repo only: VERSION matches README and MASTER_PLAN.
# python missing or the checker crashing lets the commit through (fail-open).
#
# v1.68.0: CHANGELOG/TIME_LOG gate removed (never ran in a main checkout;
# switching it on would refuse the first commit of every task). See the
# claude-hooks variant for the full notes.
set -euo pipefail

INPUT=$(cat)

# Cursor sends `command` at top level (not nested under tool_input like Claude)
COMMAND=$(echo "$INPUT" | python3 -c "
import sys,json
try:
    d = json.load(sys.stdin)
    print(d.get('command', ''))
except Exception:
    print('')
" 2>/dev/null || echo "")

allow() {
    printf '{"permission":"allow"}\n'
    exit 0
}

# The message goes through the environment, not into python source, so quotes
# in a path or reason cannot break (or inject into) the generated JSON.
deny() {
    DENY_MSG="$1" python3 -c '
import json, os
m = os.environ["DENY_MSG"]
print(json.dumps({"permission": "deny", "user_message": m, "agent_message": m}))
'
    exit 0
}

# 1. Description length. Runs before every early exit below: the checker parses
# the command itself (`cd X && git commit`, `git -C X commit`, `-a`,
# `-- <paths>`), reads what the commit will record, and skips commits whose
# target checkout is on ai-memory. Keep `||` outside the $(...): a pipeline +
# heredoc + redirect + `||` inside command substitution is a runtime syntax
# error in bash 5.2 that `bash -n` does not catch (pre-v1.68.0 bug).
case "$COMMAND" in
    *git*commit*)
        # Block only on the checker's own verdict: python3 also exits 2 when it
        # can't open the script, which must fail open, not block every commit.
        rc=0
        MSG=$(HOOK_INPUT="$INPUT" python3 "$(dirname "$0")/check-skill-descriptions.py" 2>&1 >/dev/null) || rc=$?
        if [ "$rc" -eq 2 ] && [ "${MSG#Description exceeds}" != "$MSG" ]; then
            deny "$MSG"
        fi
        ;;
esac

# EXIT EARLY if this is NOT a git commit command.
# Match: `git commit`, `git commit -m ...`, `cd X && git commit ...`
# Don't match: `git log`, `git status`, `git commit-tree`, etc.
if ! echo "$COMMAND" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
    allow
fi

# Strip -m "..." / -m '...' / --message variants so structural checks below
# don't accidentally match text inside the commit message (e.g. a message like
# "fix .memory mount" must not skip the checks).
CMD_STRUCT=$(echo "$COMMAND" | sed -E 's/-m[[:space:]]+"[^"]*"//g; s/-m[[:space:]]+'\''[^'\'']*'\''//g; s/--message[[:space:]]+"[^"]*"//g; s/--message[[:space:]]+'\''[^'\'']*'\''//g')

# Skip commits into the ai-memory checkout itself. This is about the commit's
# target, not about `.memory/` existing: pre-v1.68.0 also skipped whenever
# `git -C .memory branch` said ai-memory, which is true in every main checkout.
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ "$BRANCH" = "ai-memory" ] || \
   echo "$CMD_STRUCT" | grep -qE '(^|[[:space:];&|])cd[[:space:]]+\.memory(/|[[:space:]]|$)|git[[:space:]]+-C[[:space:]]+\.memory(/|[[:space:]]|$)'; then
    allow
fi

ERRORS=""

# 2. Skeleton-only checks: VERSION must match README and MASTER_PLAN.
# Strict match for the markdown table row `| Skeleton Path | . |` — value
# column must be literally `.`. Pre-v1.63.2 used `'Skeleton Path.*\.'`
# which matched any dot anywhere on the line, so downstream projects with
# Skeleton Path values like `../agentskel`, `~/.agentskel/skeleton`, or
# `./agentskel` all triggered these checks incorrectly.
if [ -f ".memory/CONFIG.md" ] && grep -qE '^\|[[:space:]]+Skeleton Path[[:space:]]+\|[[:space:]]+\.[[:space:]]+\|' .memory/CONFIG.md 2>/dev/null; then
    if [ -f "VERSION" ]; then
        SKEL_VERSION=$(tr -d '[:space:]' < VERSION)

        # Match X.Y.Z or X.Y format
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

if [ -n "$ERRORS" ]; then
    deny "${ERRORS}Fix before committing."
fi

allow
