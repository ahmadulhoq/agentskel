#!/usr/bin/env bash
# agentskel pre-commit enforcement hook
# Installed to .claude/hooks/ by setup-skeleton, next to
# check-skill-descriptions.py (Codex reuses this script from .codex/hooks/).
#
# Checks, in order:
#   1. Skill/workflow descriptions <= 1024 chars, in what the commit records
#      (check-skill-descriptions.py). Runs in every checkout.
#   2. Skeleton repo only: VERSION matches README and MASTER_PLAN.
#
# Block = exit 2 + reason on stderr. Anything else lets the commit through,
# including python being missing (fail-open).
#
# v1.68.0: the CHANGELOG/TIME_LOG gate was removed. It sat behind a skip that
# fired in every main checkout (.memory is always on ai-memory there), so it
# never ran; switching it on would have refused the first commit of every task,
# because task-completion writes the logs after the code commit.
set -euo pipefail

# Read the tool input from stdin (Claude Code passes JSON with tool details)
INPUT=$(cat)

# Extract the command being run
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

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
            echo "$MSG" >&2
            exit 2
        fi
        ;;
esac

# EXIT EARLY if this is NOT a git commit command.
# Match: `git commit`, `git commit -m ...`, `cd X && git commit ...`
# Don't match: `git log`, `git status`, `git commit-tree`, etc.
if ! echo "$COMMAND" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
    exit 0
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
    exit 0
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
    echo "${ERRORS}Fix before committing." >&2
    exit 2
fi

exit 0
