#!/usr/bin/env bash
# agentskel pre-commit enforcement hook
# Blocks git commit if task-completion artifacts are missing.
# Installed to .claude/hooks/ by setup-skeleton.
set -euo pipefail

# Read the tool input from stdin (Claude Code passes JSON with tool details)
INPUT=$(cat)

# Extract the command being run
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# EXIT EARLY if this is NOT a git commit command.
# The settings.json "if" pattern is unreliable — verify explicitly here.
# Match: `git commit`, `git commit -m ...`, `cd X && git commit ...`
# Don't match: `git log`, `git status`, `git diff`, etc.
if ! echo "$COMMAND" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+commit([[:space:]]|$)'; then
    exit 0
fi

# Only check commits on the project branch, not ai-memory.
BRANCH=$(git branch --show-current 2>/dev/null || echo "")
MEMORY_BRANCH=$(git -C .memory branch --show-current 2>/dev/null || echo "")

if [ "$BRANCH" = "ai-memory" ] || [ "$MEMORY_BRANCH" = "ai-memory" ] || echo "$COMMAND" | grep -q '\.memory'; then
    exit 0
fi

# Skip for merge commits or amends
if echo "$COMMAND" | grep -qE '\-\-amend|merge'; then
    exit 0
fi

ERRORS=""

# Check if CHANGELOG.md and TIME_LOG.md have recent changes in .memory/
# Strategy: look at the LAST commit on ai-memory. If CHANGELOG/TIME_LOG weren't
# modified in the last commit OR aren't staged/modified right now, flag it.
# This avoids wall-clock time dependency.
if [ -d ".memory" ]; then
    # Check if files are modified (staged or unstaged) in .memory/
    DIRTY=$(git -C .memory status --porcelain 2>/dev/null || echo "")

    # Check if CHANGELOG.md was modified in the last commit OR is currently dirty
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

# Skeleton-only checks: VERSION must match README and MASTER_PLAN
if [ -f ".memory/CONFIG.md" ] && grep -q 'Skeleton Path.*\.' .memory/CONFIG.md 2>/dev/null; then
    if [ -f "VERSION" ]; then
        SKEL_VERSION=$(cat VERSION | tr -d '[:space:]')

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

# Lint: staged skill/workflow descriptions must not exceed 1024 chars
# (agentskills.io spec limit). Multi-line YAML folded scalars (>) are allowed;
# they are normalized to a single string for length measurement.
STAGED=$(git diff --cached --name-only 2>/dev/null || true)
if [ -n "$STAGED" ]; then
    BAD=$(echo "$STAGED" | python3 - <<'PY' 2>/dev/null || true
import sys, re, os

FM_RE = re.compile(r'^---\s*\n(.*?)\n---\s*\n', re.DOTALL)

def extract_desc(fm_block):
    m = re.search(r'^description:[ \t]*(.*)', fm_block, re.MULTILINE)
    if not m:
        return None
    first = m.group(1).rstrip()
    if first in ('>', '|', '>-', '|-', '>+', '|+', ''):
        rest = fm_block[m.end():]
        content = []
        for line in rest.split('\n'):
            if line and line[:1] in (' ', '\t'):
                content.append(line.strip())
            else:
                break
        joined = ' '.join(content).strip()
        return joined if joined else None
    stripped = first.strip()
    return stripped if stripped else None

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
    fm = FM_RE.match(text)
    if not fm:
        continue
    desc = extract_desc(fm.group(1))
    if desc and len(desc) > 1024:
        bad.append(f"{line} ({len(desc)} chars)")
if bad:
    print("; ".join(bad))
PY
)
    if [ -n "$BAD" ]; then
        ERRORS="${ERRORS}Description exceeds 1024-char limit in: ${BAD}. Shorten or split the skill scope. "
    fi
fi

if [ -n "$ERRORS" ]; then
    echo "${ERRORS}Fix before committing." >&2
    exit 2
fi

exit 0
