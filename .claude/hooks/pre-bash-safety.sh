#!/usr/bin/env bash
# agentskel pre-bash safety hook
# Blocks destructive shell patterns that must never auto-approve, regardless of
# what the permissions.allow list would match. The allowlist uses glob matchers
# (e.g. `Bash(git push *)`) which are broad and would match destructive variants
# like `git push --force`. This hook enforces the "always pause for destructive
# ops" boundary from docs/AUTONOMY-MODES.md.
#
# Blocks: exit 2 with stderr message asking user to confirm explicitly.
# Asks:   exit 0 + PreToolUse JSON permissionDecision "ask" — Claude Code shows
#         its own approval prompt, which only the user can answer. Used for one
#         case: deleting remote branches that are fully merged (v1.68.0).
# Allows: exit 0 (falls through to next hook or tool execution).
#
# Installed to .claude/hooks/ by setup-skeleton. Runs before Bash calls.
set -euo pipefail

# Read the tool input from stdin (Claude Code passes JSON with tool details)
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
SESSION_CWD=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")

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
# Not decided here. Every other rule must run first: if this returned an "ask"
# early, a delete chained with a blocked command would prompt instead of block.
# The verdict is made at the end of the script ("Remote branch deletion
# verdict").
REMOTE_DELETE=0
# Coarse prefilter only (quoted flags like "--delete" included): the python
# verdict below parses the command and decides. A match that turns out not to
# be a delete (`git push origin main && date -d tomorrow`) is allowed there.
if echo "$CMD_STRUCT" | grep -qE '(^|[;&|[:space:]])git[[:space:]]+(-[Cc][[:space:]]+[^[:space:]]+[[:space:]]+)*push[[:space:]]+.*((--delete|[[:space:]"'\'']-d)(["'\''[:space:]=]|$)|[[:space:]]:[^[:space:]]+)'; then
    REMOTE_DELETE=1
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

# --- Remote branch deletion verdict (runs last, after every block rule) ---
# Ask the user (Claude Code's own approval prompt — an agent cannot answer it)
# only when ALL of these hold; anything else is blocked:
#   - the plain form `git push <remote> --delete <branch>...` (no `:branch`
#     refspec, no `git -C`/`-c`, no `cd` anywhere in the command, no extra
#     push flags), so the branches are resolved in the session's repo;
#   - no branch is the remote's default branch, main, master or ai-memory;
#   - every branch exists on the remote and its tip, as the remote has it NOW
#     (`git ls-remote`, not a possibly stale origin/<branch>), is an ancestor
#     of the remote's default branch tip. Squash-merged branches fail this
#     check and stay blocked: their commits are not in the default branch.
# Network down, parse failure, missing objects: blocked.
# The "ask" decision is Claude Code's PreToolUse contract; this script is not
# wired into other tools.
if [ "$REMOTE_DELETE" = 1 ]; then
    read -r -d '' DELETE_CHECK_PY <<'PY' || true
import json, os, shlex, subprocess

cmd = os.environ.get("SAFETY_CMD", "")
cwd = os.environ.get("SAFETY_CWD") or os.getcwd()
PROTECTED = {"main", "master", "ai-memory"}
SEPARATORS = {"&&", "||", ";", "|", "&", "(", ")", ";;", "|&"}


def verdict(text):
    print(text)
    raise SystemExit(0)


def git(*args):
    return subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True, timeout=20)


try:
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    tokens = list(lex)
except ValueError:
    verdict("BLOCK could not parse the command")

segments, cur = [], []
for tok in tokens:
    if tok in SEPARATORS:
        segments.append(cur)
        cur = []
    else:
        cur.append(tok)
segments.append(cur)

if any(seg[:1] == ["cd"] for seg in segments):
    verdict("BLOCK `cd` in the same command; run the delete from the repo itself")

deletes = []
for words in segments:
    if not words or words[0] != "git":
        continue
    i, global_opts = 1, []
    while i < len(words) and words[i].startswith("-"):
        global_opts.append(words[i])
        i += 2 if words[i] in ("-C", "-c", "--git-dir", "--work-tree") else 1
    if i >= len(words) or words[i] != "push":
        continue
    args = words[i + 1:]
    positional = [a for a in args if not a.startswith("-")]
    flags = [a for a in args if a.startswith("-")]
    if not ({"--delete", "-d"} & set(flags) or any(":" in a for a in positional)):
        continue
    if global_opts:
        verdict("BLOCK git options before `push` (-C/-c); run it from the repo itself")
    if any(":" in a for a in positional):
        verdict("BLOCK refspec form (`:branch`); use `git push <remote> --delete <branch>`")
    if set(flags) - {"--delete", "-d"}:
        verdict("BLOCK extra push options alongside --delete")
    if len(positional) < 2:
        verdict("BLOCK name the remote and at least one branch")
    names = [b[len("refs/heads/"):] if b.startswith("refs/heads/") else b for b in positional[1:]]
    deletes.append((positional[0], names))

if not deletes:
    # The prefilter matched, but no segment is a `git push` delete: e.g. a
    # plain push chained with `date -d …`. Allow it — unless a single word
    # carries a whole push-delete (a nested `bash -c "git push --delete …"`),
    # which this parser cannot see into.
    nested = [t for t in tokens if "push" in t and ("--delete" in t or " -d" in t or " :" in t)]
    if nested:
        verdict("BLOCK branch delete inside a nested command string; run it directly")
    verdict("ALLOW")

for _, names in deletes:
    hit = PROTECTED & set(names)
    if hit:
        verdict(f"BLOCK protected branch: {', '.join(sorted(hit))}")

asked, bases = [], []
try:
    for remote, names in deletes:
        sym = git("ls-remote", "--symref", remote, "HEAD")
        default = ""
        for line in sym.stdout.splitlines():
            if line.startswith("ref: refs/heads/") and line.endswith("\tHEAD"):
                default = line[len("ref: refs/heads/"):-len("\tHEAD")]
        if sym.returncode != 0 or not default:
            verdict(f"BLOCK could not read {remote}'s default branch (offline?)")
        if default in names:
            verdict(f"BLOCK {default} is {remote}'s default branch")
        heads = {}
        for line in git("ls-remote", "--heads", remote).stdout.splitlines():
            sha, _, ref = line.partition("\t")
            heads[ref[len("refs/heads/"):]] = sha
        base = heads.get(default, "")
        for name in names:
            sha = heads.get(name)
            if not sha:
                verdict(f"BLOCK {name} does not exist on {remote}")
            if not base or git("merge-base", "--is-ancestor", sha, base).returncode != 0:
                verdict(f"BLOCK {name} is not fully merged into {remote}/{default} "
                        "(or not fetched; squash merges count as unmerged)")
            asked.append(f"{remote}/{name}")
        bases.append(f"{remote}/{default}")
except (OSError, subprocess.TimeoutExpired):
    verdict("BLOCK git failed or timed out while checking the remote")

print(json.dumps({"hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": (
        f"pre-bash-safety: delete remote branch(es) {', '.join(asked)}. Every tip is "
        f"already in {', '.join(sorted(set(bases)))}, so no commits are lost. Approve to run."
    ),
}}))
PY
    VERDICT=$(SAFETY_CMD="$COMMAND" SAFETY_CWD="$SESSION_CWD" python3 -c "$DELETE_CHECK_PY" 2>/dev/null) || VERDICT="BLOCK the merge check crashed"
    case "$VERDICT" in
        "{"*)
            printf '%s\n' "$VERDICT"
            exit 0
            ;;
        ALLOW)
            ;;
        *)
            block "remote branch delete (git push --delete / push origin :branch): ${VERDICT#BLOCK }"
            ;;
    esac
fi

# All checks passed — safe to proceed.
exit 0
