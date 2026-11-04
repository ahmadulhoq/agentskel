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
# Installed to .claude/hooks/ by setup-skeleton, next to its two helpers
# (pre-bash-heredocs.py, pre-bash-commands.py). Runs before Bash calls.
# The other tools run this same script through a thin wrapper of their own
# (core/<tool>-hooks/pre-bash-safety.sh) that converts their hook JSON.
#
# v1.69.0: upstreamed from MCU-Watchlist (PRs #164, #165): heredoc stripping
# for a few exact text-writing shapes, the AGENTSKEL_UNSAFE override (first
# word of a single command only, never for remote deletes), git restore,
# every spelling of force branch delete, git clean --force, worktree remove
# -f, and per-command checks for rm and git branch (pre-bash-commands.py)
# with the old regexes kept as a floor. Developed over five rounds of
# independent adversarial review there. Tests: pre-bash-safety.test.sh.
set -euo pipefail

# Read the tool input from stdin (Claude Code passes JSON with tool details)
INPUT=$(cat)
# python3 -I: a json.py or shlex.py in the session folder must not replace the
# real module. errors="replace": a command python cannot print as-is (a lone
# surrogate, non-ASCII under an ASCII locale) used to come out EMPTY, and an
# empty command is allowed (MCU-Watchlist 2026-11-02).
COMMAND=$(printf '%s' "$INPUT" | python3 -I -c "import sys,json; sys.stdout.reconfigure(errors='replace'); d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null || echo "")
SESSION_CWD=$(printf '%s' "$INPUT" | python3 -I -c "import sys,json; sys.stdout.reconfigure(errors='replace'); d=json.load(sys.stdin); print(d.get('cwd',''))" 2>/dev/null || echo "")

# Empty command = nothing to check
[ -z "$COMMAND" ] && exit 0

# Strip heredoc BODIES: they are content, not commands. Found 2026-08-16
# (MCU-Watchlist) when an edit to THIS FILE was blocked because the patch text
# quoted a force-delete command inside a comment. Writing documentation about a
# dangerous command is not running it, and a hook that cannot be safely edited
# is a hook nobody will fix.
#
# pre-bash-heredocs.py decides what a heredoc is (2026-11-02: the awk version
# read `<<<`, `$((1<<x))` and a quoted "<<EOF" as heredocs and hid every line
# after them). A heredoc fed to a shell (`bash <<EOF`, `cat <<EOF | sh`) keeps
# its body: that is commands. If the helper fails, nothing is stripped (fail
# closed: more is checked, not less).
CMD_HD=$(printf '%s' "$COMMAND" | python3 -I "$(dirname "$0")/pre-bash-heredocs.py" 2>/dev/null) || CMD_HD="$COMMAND"

# Strip -m "..." / -m '...' / --message variants so patterns don't match text
# inside commit messages (a commit message like "reset the hard state" must not
# trigger the reset --hard block).
CMD_STRUCT=$(echo "$CMD_HD" | sed -E 's/-m[[:space:]]+"[^"]*"//g; s/-m[[:space:]]+'\''[^'\'']*'\''//g; s/--message[[:space:]]+"[^"]*"//g; s/--message[[:space:]]+'\''[^'\'']*'\''//g')

# Deliberate, auditable escape hatch. Added 2026-08-16 (MCU-Watchlist).
#
# The message below used to say "do it manually or explicitly override" while no
# override existed. So the only ways past were the human running the command, or
# the agent rephrasing a flag to dodge the regex. The second happened: the short
# force-delete flag was blocked and the long spelling of the same operation went
# straight through, because the rules matched SPELLINGS rather than OPERATIONS.
#
# A control that a rephrase defeats is not a control, and an agent routing around
# one learns that safety is negotiable. So the rules below match operations, and
# intent gets a front door that shows up in the transcript.
#
#     AGENTSKEL_UNSAFE=i-understand <one command>
#
# It must be the FIRST word, and the command must be a single command (no ; & |
# or line break once commit messages and heredoc bodies are set aside). Until
# 2026-11-02 it matched the phrase anywhere — a commit message, a heredoc, an
# echo — and then switched off every rule in the whole compound command.
# It never applies to remote branch deletes (see the verdict at the end).
override_requested() {
    # Read with commit messages KEPT (CMD_HD): the message stripping is not
    # quote-aware, so `'-m "'; <second command>; echo '"'` would hide a command.
    grep -qE '^[[:space:]]*AGENTSKEL_UNSAFE=i-understand[[:space:]]' <<<"$CMD_HD" || return 1
    # Redirections belong to the one command (2>&1, >&2, &>/dev/null); set them
    # aside, then refuse anything that is, or hides, a second command:
    # ; & | newline, $( ), backticks, <( ), >( ) (second review, 2026-11-02).
    local one
    one=$(sed -E 's/[0-9]*>&[0-9-]+//g; s/&>>?//g' <<<"$CMD_HD")
    case "$one" in
        *[';&|`']* | *'$('* | *'<('* | *'>('* | *$'\n'*) return 1 ;;
    esac
    return 0
}

block() { # block <reason> [no-override]
    local reason="$1" overridable=yes
    [ "${2:-}" = no-override ] && overridable=no
    if [ "$overridable" = yes ] && override_requested; then
        echo "pre-bash-safety.sh: OVERRIDDEN ($reason) — AGENTSKEL_UNSAFE set explicitly." >&2
        return 0
    fi
    cat >&2 <<EOF
BLOCKED by pre-bash-safety.sh: $reason

Command: $COMMAND

This is a destructive operation. agentskel refuses to auto-approve it,
regardless of Autopilot Mode.

Agent: do NOT add the override below on your own. Stop and ask the user.
Use it only after they have approved this exact command in the current
conversation. If they have, run it as a single command with this first word
(not available for remote branch deletes):

    AGENTSKEL_UNSAFE=i-understand <your command>

That is deliberate and reviewable. Rewording a flag to slip past this check is
neither — if you find a variant that gets through, that is a bug in this hook,
not a way around it.

See docs/AUTONOMY-MODES.md → "Always pause" for the full list.
EOF
    exit 2
}

# Every git rule below starts with GIT_CMD: `git` (or a path ending in /git:
# /usr/bin/git, ./git) and then ANY global options before the subcommand.
# Until v1.69.0 only `-C <path>` / `-c <k=v>` were allowed there, so
# `git --no-pager reset --hard`, `git -P checkout -f` and `/usr/bin/git push
# --force` matched no rule at all. Only git's value-taking global options
# (-C, -c, --git-dir, ...) consume the next word: letting any option do so
# read `git --no-pager log --grep restore` as a `restore` (PR review).
GIT_CMD='(^|[;&|[:space:]])([^[:space:];&|]*/)?git([[:space:]]+((-[Cc]|--(git-dir|work-tree|namespace|exec-path|config-env|super-prefix|attr-source|list-cmds))[[:space:]]+[^[:space:]]+|-[^[:space:]]+))*[[:space:]]+'

# --- Force pushes ---
if grep -qE "$GIT_CMD"'push[[:space:]]+.*(--force([[:space:]]|=|$)|--force-with-lease|-f([[:space:]]|$))' <<<"$CMD_STRUCT" \
   || grep -qE "$GIT_CMD"'push[[:space:]]+([^;&|]*[[:space:]])?["'\'']?\+[^:[:space:]"'\'']' <<<"$CMD_STRUCT"; then
    # The second pattern (v1.69.0): a `+` refspec (`+main`, `+HEAD:main`)
    # force-pushes that ref with no --force flag at all. `+:x` is a delete,
    # decided by the remote-delete verdict below. Bounded to one command, so
    # `git push origin main && echo +5` is not a force push.
    block "force push (git push --force / -f / --force-with-lease / +refspec)"
fi

# --- Hard reset ---
if grep -qE "$GIT_CMD"'reset[[:space:]]+.*--hard' <<<"$CMD_STRUCT"; then
    block "hard reset (git reset --hard) — discards uncommitted work"
fi

# --- Force delete branch ---
if grep -qE "$GIT_CMD"'branch[[:space:]]+.*(-D([[:space:]]|$)|--delete[[:space:]]+.*(--force|-f)([[:space:]]|$)|(--force|-f)[[:space:]]+.*--delete([[:space:]]|$))' <<<"$CMD_STRUCT"; then
    block "force branch delete (short or long form) — discards unmerged work"
fi

# --- Checkout file discard: git checkout -- <path> ---
if grep -qE "$GIT_CMD"'checkout[[:space:]]+--([[:space:]]|$)' <<<"$CMD_STRUCT"; then
    block "checkout -- <file> — discards uncommitted changes"
fi

# --- Checkout bulk file discard: git checkout . ---
if grep -qE "$GIT_CMD"'checkout[[:space:]]+\.([[:space:]]|$)' <<<"$CMD_STRUCT"; then
    block "git checkout . — discards ALL uncommitted changes"
fi

# --- git restore: the modern spelling of "checkout -- <file>" ---
# Added 2026-08-16 (MCU-Watchlist). The old spelling was blocked and this one,
# which discards exactly the same work, was not covered at all.
if grep -qE "$GIT_CMD"'restore([[:space:]]|$)' <<<"$CMD_STRUCT"; then
    block "git restore — discards uncommitted changes (modern 'checkout -- <file>')"
fi

# --- git clean with -f (force) ---
if grep -qE "$GIT_CMD"'clean[[:space:]]+.*(-[a-zA-Z]*f|--force)' <<<"$CMD_STRUCT"; then
    block "git clean force (-f / --force) — removes untracked files, cannot be undone"
fi

# --- Recursive force rm, force branch delete: decided per command ---
# pre-bash-commands.py reads the command the way bash splits it (quotes, $'',
# braces, $( ), backticks, <( ), redirections, comments) and blocks only when
# ONE rm carries recursive + force, or ONE git branch carries delete + force,
# in any spelling. Its header has the rules and the history: the regexes this
# replaces read past the end of a command (any hyphenated file name with an r
# and an f — "-confirmed", "-four" — tripped them) or stopped too early
# (`rm -r $(cat list) -f`).
#
# It reads CMD_HD: heredoc bodies removed, commit messages KEPT, because a
# `$( )` in a message runs (`git commit -m "$(rm -rf y)"`), and plain message
# text is a single word the reader does not treat as a command.
#
# If it cannot run or answers anything else, every rm and every git branch
# delete is blocked until a person runs it. Fail closed.
CMD_VERDICT=$(printf '%s' "$CMD_HD" | python3 -I "$(dirname "$0")/pre-bash-commands.py" 2>/dev/null) || CMD_VERDICT=""
case "$CMD_VERDICT" in
    "BLOCK "*)
        block "${CMD_VERDICT#BLOCK }"
        ;;
    ALLOW)
        ;;
    *)
        # Only reached when the reader itself is broken, so be blunt: any rm,
        # and any git branch delete, waits for a person. Reads CMD_HD so a
        # $( ) inside a commit message is not hidden.
        # Quotes, backslashes, $ and braces removed first, so r\m, r$'m',
        # {r,}m and {rm,-rf,y} all read as rm; and "rm" anywhere counts
        # (-O'rm ...', rm${IFS}-rf, \nrm): this path is rare, so blunt is fine.
        CMD_PLAIN=$(tr -d '\\"'"'"'${},' <<<"$CMD_HD")
        if grep -q 'rm' <<<"$CMD_PLAIN"; then
            block "rm while the per-command check could not run (strict fallback)"
        fi
        if grep -qE 'git.*branch' <<<"$CMD_PLAIN"; then
            block "git branch while the per-command check could not run (strict fallback)"
        fi
        ;;
esac

# --- Floor: the pre-v1.69.0 rm rules, which apply whatever the reader says ---
# The reader may only ADD blocks (third and fourth reviews, 2026-11-02: every
# round found a place where it misread bash). The floor is the old rule,
# unchanged, run on a copy of the command in which some hyphens are
# neutralised: those that cannot start a working rm option. A hyphen that has
# a literal character before it in the same word (other than a $NAME variable
# name, and other than more hyphens) is either inside a word that does not
# start with "-" or in the middle of an option cluster, where rm rejects the
# option and deletes nothing. That is the "-confirmed" / "-four" / "-verify"
# case, and `$DIR/run-after.txt`. Everything else is matched exactly as the old rule
# matches it: `$x-rf` (x empty), `$(:)-rf`, `` `:`-rf ``, `*-rf`, `$x--force`.
# A word that starts with "--" and is all plain characters is a long option:
# its hyphens are neutralised for the bundled-flag rule (`rm --force x` is not
# -f...r), and the long-form rule below reads the original.
# LC_ALL=C (v1.69.0): macOS awk in a UTF-8 locale splits a non-breaking space
# in half while splitting fields and dies ("towc: multibyte conversion
# failure"). Under `set -e` that exited the hook with status 2 (blocked by
# accident); in the split-flag `if` below it made the rule fail OPEN. Byte
# semantics change nothing else: every class here is ASCII.
CMD_FLOOR=$(LC_ALL=C awk '
function neutral(f,    out, n, k, c, j, run, b, lit) {
    if (f ~ /^--[A-Za-z0-9._\/+:,%=~^-]*$/) { gsub(/-/, "_", f); return f }
    out = ""; n = length(f)
    for (k = 1; k <= n; k++) {
        c = substr(f, k, 1)
        if (c == "-") {
            j = k
            while (j > 1 && substr(f, j - 1, 1) ~ /[A-Za-z0-9._\/+:%=~^-]/) j--
            run = substr(f, j, k - j)
            b = (j > 1) ? substr(f, j - 1, 1) : ""
            lit = run
            if (b == "$") {
                if (match(lit, /^[A-Za-z_][A-Za-z0-9_]*/)) lit = substr(lit, RLENGTH + 1)
                else if (match(lit, /^[0-9]/)) lit = substr(lit, 2)
            } else if (b == "{") {
                lit = ""        # inside ${ } or { , }: an expansion, not literal text
            }
            if (lit ~ /[^-]/) c = "_"
        }
        out = out c
    }
    return out
}
{
    gsub(/[;&|<>]/, " & ")      # a separator or redirection ends a word
    line = ""
    for (i = 1; i <= NF; i++) line = line (i > 1 ? " " : "") neutral($i)
    print line
}' <<<"$CMD_STRUCT")
if grep -qE '(^|[;&|[:space:]])rm[[:space:]]+.*(-[a-zA-Z]*[rR][a-zA-Z]*[fF]|-[a-zA-Z]*[fF][a-zA-Z]*[rR])' <<<"$CMD_FLOOR" \
   || grep -qE '(^|[;&|[:space:]])rm[[:space:]]+.*(--recursive[[:space:]]+.*--force|--force[[:space:]]+.*--recursive)' <<<"$CMD_STRUCT"; then
    block "recursive force delete (rm -rf / -fr / --recursive --force) — cannot be undone"
fi
# Split flags (rm -r x -f) within one command, up to the next ; & | or line
# break, in a single pass (one grep per segment took 110 s on 30,000 segments).
if grep -oE '(^|[;&|[:space:]])rm[[:space:]][^;&|]*' <<<"$CMD_STRUCT" | LC_ALL=C awk '
    /(^|[[:space:]])(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)([[:space:]]|$)/ &&
    /(^|[[:space:]])(-[a-zA-Z]*[fF][a-zA-Z]*|--force)([[:space:]]|$)/ { found = 1 }
    END { exit !found }'; then
    block "recursive force delete (rm with -r and -f) — cannot be undone"
fi

# --- Worktree force remove ---
if grep -qE "$GIT_CMD"'worktree[[:space:]]+remove[[:space:]]+.*(--force|-f([[:space:]]|$))' <<<"$CMD_STRUCT"; then
    block "git worktree remove force (--force / -f) — discards uncommitted worktree changes"
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
if grep -qE "$GIT_CMD"'push[[:space:]]+.*((--delete|[[:space:]"'\'']-d)(["'\''[:space:]=]|$)|[[:space:]]\+?:[^[:space:]]+)' <<<"$CMD_STRUCT"; then
    REMOTE_DELETE=1
fi

# --- Forced checkout: discards every uncommitted change without naming a path ---
if grep -qE "$GIT_CMD"'checkout[[:space:]]+.*(--force([[:space:]]|$)|-[a-zA-Z]*f([[:space:]]|$))' <<<"$CMD_STRUCT"; then
    block "git checkout --force / -f — discards uncommitted changes"
fi

# --- Stash destruction: drop/clear cannot be recovered through the reflog UI ---
if grep -qE "$GIT_CMD"'stash[[:space:]]+(drop|clear)([[:space:]]|$)' <<<"$CMD_STRUCT"; then
    block "git stash drop/clear — discards stashed work"
fi

# --- find with a destructive action. `Bash(find *)` is allowlisted as a search
#     tool, but -delete and -exec rm turn it into a bulk remover. ---
if grep -qE '(^|[;&|[:space:]])find[[:space:]]' <<<"$CMD_STRUCT" \
   && grep -qE '(-delete([[:space:]]|$)|-exec[[:space:]]+rm([[:space:]]|$)|-execdir[[:space:]]+rm([[:space:]]|$))' <<<"$CMD_STRUCT"; then
    block "find with -delete / -exec rm — bulk delete"
fi

# --- gh api with a writing method. `gh api` is a general-purpose authenticated
#     GitHub client: `gh api -X DELETE /repos/:owner/:repo` deletes the repo,
#     and other endpoints can strip branch protection. Read-only is fine. ---
if grep -qE '(^|[;&|[:space:]])gh[[:space:]]+api([[:space:]]|$)' <<<"$CMD_STRUCT" \
   && grep -qiE '(-X|--method)[[:space:]]*=?[[:space:]]*["'\'']?(POST|PUT|PATCH|DELETE)' <<<"$CMD_STRUCT"; then
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
import json, os, re, shlex, subprocess

cmd = os.environ.get("SAFETY_CMD", "")
cwd = os.environ.get("SAFETY_CWD") or os.getcwd()
PROTECTED = {"main", "master", "ai-memory"}
SEPARATORS = {"&&", "||", ";", "|", "&", "(", ")", ";;", "|&"}
WRAPPERS = {"env", "command", "builtin", "exec", "sudo", "doas", "nohup", "nice",
            "time", "timeout", "xargs", "stdbuf", "chronic", "unbuffer"}


def verdict(text):
    print(text)
    raise SystemExit(0)


def git(*args):
    return subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True, timeout=20)


# A newline ends a command, as ; does (MCU-Watchlist 2026-11-02: a delete on
# the second line was not seen).
cmd = cmd.replace("\\\n", " ").replace("\n", " ; ")

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
    # Leading NAME=value words only set the environment for this one command
    # (`FOO=1 git push …`, `X+=1 git push …`, `AGENTSKEL_UNSAFE=… git push …`); skip
    # them so the push is still seen (MCU-Watchlist 2026-11-02).
    while words and "=" in words[0] and words[0].split("=", 1)[0].rstrip("+").isidentifier():
        words = words[1:]
    # A path-qualified git (/usr/bin/git) is git too (v1.69.0): it used to be
    # skipped here, so its deletes were allowed. Ask only for the plain form.
    if words and words[0] != "git" and os.path.basename(words[0]) == "git":
        rest = words[1:]
        if "push" in rest and ({"--delete", "-d"} & set(rest) or any(re.match(r"^\+?:", w) for w in rest[rest.index("push") + 1:])):
            verdict("BLOCK path-qualified git before the push; run the delete as a plain `git push` command")
    if words and words[0] in WRAPPERS and "git" in words:
        rest = words[words.index("git"):]
        if "push" in rest and ({"--delete", "-d"} & set(rest) or any(re.match(r"^\+?:", w) for w in rest[rest.index("push") + 1:])):
            verdict(f"BLOCK `{words[0]}` before the push; run the delete as a plain `git push` command")
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
    if not ({"--delete", "-d"} & set(flags) or any(re.match(r"^\+?:", a) for a in positional)):
        continue
    if global_opts:
        verdict("BLOCK git options before `push` (-C/-c); run it from the repo itself")
    if any(re.match(r"^\+?:", a) for a in positional):
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
    VERDICT=$(SAFETY_CMD="$COMMAND" SAFETY_CWD="$SESSION_CWD" python3 -I -c "$DELETE_CHECK_PY" 2>/dev/null) || VERDICT="BLOCK the merge check crashed"
    case "$VERDICT" in
        "{"*)
            # AGENTSKEL_NO_ASK=1 is set by the other tools' wrappers
            # (core/<tool>-hooks/pre-bash-safety.sh, v1.69.0): their hook
            # contracts have no verified approval prompt, and an output a tool
            # does not understand may be read as "allow". There a merged
            # delete is blocked, for the user to run.
            if [ "${AGENTSKEL_NO_ASK:-}" = 1 ]; then
                block "remote branch delete: the branches are merged, but this tool has no approval prompt only you can answer; run it yourself" no-override
            fi
            printf '%s\n' "$VERDICT"
            exit 0
            ;;
        ALLOW)
            ;;
        *)
            block "remote branch delete (git push --delete / push origin :branch): ${VERDICT#BLOCK }" no-override
            ;;
    esac
fi

# All checks passed — safe to proceed.
exit 0
