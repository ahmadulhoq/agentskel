#!/usr/bin/env bash
# agentskel pre-bash safety hook
# Blocks destructive shell patterns that must never auto-approve, regardless of
# what the permissions.allow list would match. The allowlist uses glob matchers
# (e.g. `Bash(git push *)`) which are broad and would match destructive variants
# like `git push --force`. This hook enforces the "always pause for destructive
# ops" boundary from docs/AUTONOMY-MODES.md.
#
# Blocks: exit 2 with stderr message asking user to confirm explicitly.
# Allows: exit 0 (falls through to next hook or tool execution).
#
# Installed to .claude/hooks/ by setup-skeleton. Runs before Bash calls.
set -euo pipefail

# Read the tool input from stdin (Claude Code passes JSON with tool details)
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")

# Empty command = nothing to check
[ -z "$COMMAND" ] && exit 0

# Strip -m "..." / -m '...' / --message variants so patterns don't match text
# inside commit messages (a commit message like "reset the hard state" must not
# trigger the reset --hard block).
CMD_STRUCT=$(echo "$COMMAND" | sed -E 's/-m[[:space:]]+"[^"]*"//g; s/-m[[:space:]]+'\''[^'\'']*'\''//g; s/--message[[:space:]]+"[^"]*"//g; s/--message[[:space:]]+'\''[^'\'']*'\''//g')

block() {
    local reason="$1"
    cat >&2 <<EOF
BLOCKED by pre-bash-safety.sh: $reason

Command: $COMMAND

This is a destructive operation. agentskel refuses to auto-approve it,
regardless of Autopilot Mode. If you genuinely intend to run this, do it
manually or explicitly override.

See docs/AUTONOMY-MODES.md → "Always pause" for the full list.
EOF
    exit 2
}

# --- Force pushes ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+[[:space:]]+)*push[[:space:]]+.*(--force([[:space:]]|=|$)|--force-with-lease|-f([[:space:]]|$))'; then
    block "force push (git push --force / -f / --force-with-lease)"
fi

# --- Hard reset ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+[[:space:]]+)*reset[[:space:]]+.*--hard'; then
    block "hard reset (git reset --hard) — discards uncommitted work"
fi

# --- Force delete branch ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+[[:space:]]+)*branch[[:space:]]+.*-D([[:space:]]|$)'; then
    block "force branch delete (git branch -D) — discards unmerged work"
fi

# --- Checkout file discard: git checkout -- <path> ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+[[:space:]]+)*checkout[[:space:]]+--([[:space:]]|$)'; then
    block "checkout -- <file> — discards uncommitted changes"
fi

# --- Checkout bulk file discard: git checkout . ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+[[:space:]]+)*checkout[[:space:]]+\.([[:space:]]|$)'; then
    block "git checkout . — discards ALL uncommitted changes"
fi

# --- git clean with -f (force) ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+[[:space:]]+)*clean[[:space:]]+.*-[a-zA-Z]*f'; then
    block "git clean -f — removes untracked files, cannot be undone"
fi

# --- Recursive force rm ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*[fF]|-[a-zA-Z]*[fF][a-zA-Z]*[rR])'; then
    block "rm -rf (or -fr / -Rf) — recursive force delete"
fi

# --- rm with recursive AND force given SEPARATELY (rm -r -f, rm --recursive
#     --force). The bundled-flag pattern above misses these entirely. ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])rm[[:space:]]' \
   && echo "$CMD_STRUCT" | grep -qE '(^|[[:space:]])(-[a-zA-Z]*[rR]|--recursive)([[:space:]]|$)' \
   && echo "$CMD_STRUCT" | grep -qE '(^|[[:space:]])(-[a-zA-Z]*[fF]|--force)([[:space:]]|$)'; then
    block "rm with recursive + force (split or long flags) — cannot be undone"
fi

# --- Worktree force remove ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+[[:space:]]+)*worktree[[:space:]]+remove[[:space:]]+.*--force'; then
    block "git worktree remove --force — discards uncommitted worktree changes"
fi

# --- Remote branch deletion: git push --delete / git push origin :branch ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+[[:space:]]+)*push[[:space:]]+.*(--delete([[:space:]]|=|$)|[[:space:]]:[^[:space:]]+)'; then
    block "remote branch delete (git push --delete / push origin :branch)"
fi

# --- Forced checkout: discards every uncommitted change without naming a path ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+[[:space:]]+)*checkout[[:space:]]+.*(--force([[:space:]]|$)|-[a-zA-Z]*f([[:space:]]|$))'; then
    block "git checkout --force / -f — discards uncommitted changes"
fi

# --- Stash destruction: drop/clear cannot be recovered through the reflog UI ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+[[:space:]]+)*stash[[:space:]]+(drop|clear)([[:space:]]|$)'; then
    block "git stash drop/clear — discards stashed work"
fi

# --- find with a destructive action. `Bash(find *)` is allowlisted as a search
#     tool, but -delete and -exec rm turn it into a bulk remover. ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])find[[:space:]]' \
   && echo "$CMD_STRUCT" | grep -qE '(-delete([[:space:]]|$)|-exec[[:space:]]+rm([[:space:]]|$)|-execdir[[:space:]]+rm([[:space:]]|$))'; then
    block "find with -delete / -exec rm — bulk delete"
fi

# --- gh api with a writing method. `gh api` is a general-purpose authenticated
#     GitHub client: `gh api -X DELETE /repos/:owner/:repo` deletes the repo,
#     and other endpoints can strip branch protection. Read-only is fine. ---
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])gh[[:space:]]+api([[:space:]]|$)' \
   && echo "$CMD_STRUCT" | grep -qiE '(-X|--method)[[:space:]]*=?[[:space:]]*(POST|PUT|PATCH|DELETE)'; then
    block "gh api with a writing method (POST/PUT/PATCH/DELETE) — can delete repos or remove branch protection"
fi

# --- Rebase interactive with drop (harder to detect; skip for now) ---

# All checks passed — safe to proceed.
exit 0
