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
    # Nor through anything that runs its arguments as code: an escaped
    # newline inside $'...' handed to bash -c / eval / <<< is a second
    # command these checks cannot see (v1.69.0 review).
    if grep -qE "[\$]'|<<<" <<<"$one" \
       || grep -qiE '(^|[[:space:]])(eval|bash|sh|zsh|dash|ksh|fish|source|\.|ssh|xargs|env|sudo|doas|exec|command|builtin|parallel|watch|flock|nohup|timeout|su|python[0-9.]*|perl|node|ruby)([[:space:]]|$)' <<<"$one"; then
        return 1
    fi
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
# `[-_]`: the floor text below turns a hyphen inside a word into `_`.
# Before `git`: any character that cannot be part of a word (v1.69.0 review:
# `\git`, `(git`, `${x}git`, `=git` slipped past a space-only boundary), and
# any case (`GIT reset` runs git on macOS file systems).
GIT_CMD='(^|[^A-Za-z0-9_.-])([^[:space:];&|]*/)?[Gg][Ii][Tt]([[:space:]]+((-[Cc]|--(git[-_]dir|work[-_]tree|namespace|exec[-_]path|config[-_]env|super[-_]prefix|attr[-_]source|list[-_]cmds|shallow[-_]file))[[:space:]]+[^[:space:]]+|-[^[:space:]]+))*[[:space:]]+'

# --- Floor text for the git / find / gh api rules (v1.69.0, BL-008) ---
# These rules are a FLOOR under pre-bash-commands.py, which decides each
# command properly. Until v1.69.0 they matched `.*` across the whole line, so
# a flag of the NEXT command counted (`git push origin main && rm -f tmp` was
# a force push; `git checkout x && git update-ref ...` was `checkout -f`).
# They now stop at the end of the command (`[^;&|]*`), on a copy where:
#   - a ; & | < > inside quotes is part of the word ("a;b" does not end the
#     command, so quoting cannot hide a flag from the floor);
#   - & in a redirection (2>&1, &>file, <&3) is not a separator;
#   - a hyphen with a literal character before it in the same word
#     (update-ref, turn-it-off) is turned into `_`, as the rm floor does,
#     so it cannot read as an option; `$x-f` still reads as `-f`.
# A separator inside $( ) or backticks still ends the floor's command; the
# reader reads those as commands of their own.
# Python, not awk: an awk loop that appends one character at a time took
# 535 s on a 200,000-character command under macOS awk. This is linear.
# If python fails, the floor reads the plain command (separators inside
# quotes then end a command early; the reader still reads those).
read -r -d '' FLOOR_PY <<'PY' || true
import re
import sys

SEP = set(";&|<>")
LIT = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._/+:%=~^-")
LONG = re.compile(r"^--[A-Za-z0-9._/+:,%=~^-]*$")
IDENT = set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_")


def neutral(w, long_branch):
    # A hyphen with a literal character before it in the same word cannot
    # start an option: make it "_". Not after a $NAME (that may be empty) or
    # inside ${ } / { , }. The same rule as MCU-Watchlist's awk `neutral`,
    # in one pass: the awk walked back over the word for every hyphen and
    # took 109 s on a word of 20,000 hyphens (v1.69.0 review). long_branch:
    # the rm floor treats a plain `--long-option` word as all neutral.
    if long_branch and LONG.match(w):
        return w.replace("-", "_")
    out = list(w)
    name_end, last_lit, brace = 0, -1, False
    for k, c in enumerate(w):
        if k == 0 or w[k - 1] not in LIT:
            b = w[k - 1] if k > 0 else ""
            brace, last_lit, name_end = b == "{", -1, k
            if b == "$":
                if w[k:k + 1].isdigit():
                    name_end = k + 1
                elif w[k:k + 1] in IDENT:
                    while name_end < len(w) and w[name_end] in IDENT:
                        name_end += 1
        if c == "-":
            if not brace and last_lit >= name_end:
                out[k] = "_"
        elif c in LIT and k >= name_end:
            last_lit = k
    return "".join(out)


def rm_line(line):
    # MCU-Watchlist's rm floor: separators and redirections end a word; no
    # quote awareness (it matches the old rule exactly).
    for c in ";&|<>":
        line = line.replace(c, f" {c} ")
    return " ".join(neutral(w, True) for w in line.replace("\t", " ").split(" ") if w)


def git_line(line):
    buf, sq, dq, prev, i, n = [], False, False, "", 0, len(line)
    while i < n:
        c = line[i]
        if sq:
            if c == "'":
                sq = False
            elif c in SEP:
                c = "_"
        elif c == "\\":
            buf.append(line[i:i + 2])
            prev = line[i + 1:i + 2]
            i += 2
            continue
        elif dq:
            if c == '"':
                dq = False
            elif c in SEP:
                c = "_"
        elif c == "'":
            sq = True
        elif c == '"':
            dq = True
        elif c == "&" and (prev in ("<", ">") or line[i + 1:i + 2] == ">"):
            c = "_"
        elif c in SEP:
            buf.append(" " + c + " ")
            prev = c
            i += 1
            continue
        prev = line[i]
        buf.append(c)
        i += 1
    return " ".join(neutral(w, False) for w in "".join(buf).replace("\t", " ").split(" ") if w)


mode = sys.argv[1]
text = sys.stdin.buffer.read().decode("utf-8", "surrogateescape")
f = rm_line if mode == "rm" else git_line
sys.stdout.buffer.write("\n".join(f(l) for l in text.split("\n")).encode("utf-8", "surrogateescape"))
PY
CMD_GITFLOOR=$(printf '%s' "$CMD_STRUCT" | python3 -I -c "$FLOOR_PY" git 2>/dev/null) || CMD_GITFLOOR="$CMD_STRUCT"

# --- Force pushes ---
if grep -qE "$GIT_CMD"'push[[:space:]]+[^;&|]*(--force([[:space:]]|=|$)|--force[-_]with[-_]lease|-f([[:space:]]|$))' <<<"$CMD_GITFLOOR" \
   || grep -qE "$GIT_CMD"'push[[:space:]]+([^;&|]*[[:space:]])?["'\'']?\+[^:[:space:]"'\'']' <<<"$CMD_GITFLOOR"; then
    # The second pattern (v1.69.0): a `+` refspec (`+main`, `+HEAD:main`)
    # force-pushes that ref with no --force flag at all. `+:x` is a delete,
    # decided by the remote-delete verdict below. Bounded to one command, so
    # `git push origin main && echo +5` is not a force push.
    block "force push (git push --force / -f / --force-with-lease / +refspec)"
fi

# --- Hard reset ---
if grep -qE "$GIT_CMD"'reset[[:space:]]+[^;&|]*--hard' <<<"$CMD_GITFLOOR"; then
    block "hard reset (git reset --hard) — discards uncommitted work"
fi

# --- Force delete branch ---
if grep -qE "$GIT_CMD"'branch[[:space:]]+[^;&|]*(-D([[:space:]]|$)|--delete[[:space:]]+[^;&|]*(--force|-f)([[:space:]]|$)|(--force|-f)[[:space:]]+[^;&|]*--delete([[:space:]]|$))' <<<"$CMD_GITFLOOR"; then
    block "force branch delete (short or long form) — discards unmerged work"
fi

# --- Checkout file discard: git checkout -- <path> ---
if grep -qE "$GIT_CMD"'checkout[[:space:]]+--([[:space:]]|$)' <<<"$CMD_GITFLOOR"; then
    block "checkout -- <file> — discards uncommitted changes"
fi

# --- Checkout bulk file discard: git checkout . ---
if grep -qE "$GIT_CMD"'checkout[[:space:]]+\.([[:space:]]|$)' <<<"$CMD_GITFLOOR"; then
    block "git checkout . — discards ALL uncommitted changes"
fi

# --- git restore: the modern spelling of "checkout -- <file>" ---
# Added 2026-08-16 (MCU-Watchlist). The old spelling was blocked and this one,
# which discards exactly the same work, was not covered at all.
# `--staged` / -S alone only unstages (what `git status` suggests): allowed.
if grep -oE "$GIT_CMD"'restore([[:space:]][^;&|]*|$)' <<<"$CMD_GITFLOOR" | LC_ALL=C awk '
    !(/(^|[[:space:]])(--staged|-[A-Za-z]*S[A-Za-z]*)([[:space:]]|$)/ && !/(^|[[:space:]])(--worktree|-[A-Za-z]*W[A-Za-z]*)([[:space:]]|$)/) { found = 1 }
    END { exit !found }'; then
    block "git restore — discards uncommitted changes (modern 'checkout -- <file>')"
fi

# --- git clean with -f (force) ---
if grep -qE "$GIT_CMD"'clean[[:space:]]+[^;&|]*(-[a-zA-Z]*f|--force)' <<<"$CMD_GITFLOOR"; then
    block "git clean force (-f / --force) — removes untracked files, cannot be undone"
fi

# --- Every destructive form: decided per command ---
# pre-bash-commands.py reads the command the way bash splits it (quotes, $'',
# braces, $( ), backticks, <( ), redirections, comments) and blocks only when
# ONE command carries the destructive form: rm recursive + force, git branch
# delete + force, and since v1.69.0 every git rule below, find -delete and
# gh api writes, also inside bash -c / eval / $( ). The regexes further down
# stay as a floor: the reader may only ADD blocks. Its header has the rules and the history: the regexes this
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
CMD_VERDICT=$(printf '%s' "$CMD_HD" | SAFETY_CWD="$SESSION_CWD" python3 -I "$(dirname "$0")/pre-bash-commands.py" 2>/dev/null) || CMD_VERDICT=""
READER_DELETE=0
case "$CMD_VERDICT" in
    "BLOCK-REMOTE "*)
        # A remote branch delete the hook cannot ask about: never overridable
        # (v1.69.0 review: the override reached `bash -c 'git push --delete'`).
        block "${CMD_VERDICT#BLOCK-REMOTE }" no-override
        ;;
    "BLOCK "*)
        block "${CMD_VERDICT#BLOCK }"
        ;;
    ALLOW)
        ;;
    "ALLOW DELETE "*)
        # Plain top-level remote branch deletes (how many): the verdict at the
        # end of this script decides them (ask / block), even when the regex
        # prefilter misses the spelling (`\git`, `'git'`, `(git ...)`), and
        # blocks if it cannot account for every one of them.
        READER_DELETE="${CMD_VERDICT#ALLOW DELETE }"
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
        if grep -qiE 'git.*(push|reset|checkout|switch|restore|clean|worktree|stash|update-ref|read-tree|send-pack|reflog|submodule|config)' <<<"$CMD_PLAIN"; then
            block "git while the per-command check could not run (strict fallback)"
        fi
        if grep -qiE 'find.*-(delete|exec|ok)|fd.*-(x|X|-exec)|gh.*(api|delete|remove)' <<<"$CMD_PLAIN"; then
            block "find / fd / gh while the per-command check could not run (strict fallback)"
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
# v1.69.0: built by FLOOR_PY (above), the same rule as MCU-Watchlist's awk in
# one pass. The awk was quadratic (109 s on a word of 20,000 hyphens; a hook
# that runs past Claude Code's timeout lets the command through) and, in a
# UTF-8 locale, crashed on a non-breaking space under macOS awk. If python
# fails, the floor reads the plain command: more blocks, never fewer.
CMD_FLOOR=$(printf '%s' "$CMD_STRUCT" | python3 -I -c "$FLOOR_PY" rm 2>/dev/null) || CMD_FLOOR="$CMD_STRUCT"
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
if grep -qE "$GIT_CMD"'worktree[[:space:]]+remove[[:space:]]+[^;&|]*(--force|-f([[:space:]]|$))' <<<"$CMD_GITFLOOR"; then
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
if grep -qE "$GIT_CMD"'checkout[[:space:]]+[^;&|]*(--force([[:space:]]|$)|-[a-zA-Z]*f([[:space:]]|$))' <<<"$CMD_GITFLOOR"; then
    block "git checkout --force / -f — discards uncommitted changes"
fi

# --- Stash destruction: drop/clear cannot be recovered through the reflog UI ---
if grep -qE "$GIT_CMD"'stash[[:space:]]+(drop|clear)([[:space:]]|$)' <<<"$CMD_GITFLOOR"; then
    block "git stash drop/clear — discards stashed work"
fi

# --- find with a destructive action. `Bash(find *)` is allowlisted as a search
#     tool, but -delete and -exec rm turn it into a bulk remover. ---
if grep -qE '(^|[;&|[:space:]])([^[:space:];&|]*/)?find[[:space:]][^;&|]*(-delete([[:space:]]|$)|-exec[[:space:]]+rm([[:space:]]|$)|-execdir[[:space:]]+rm([[:space:]]|$))' <<<"$CMD_GITFLOOR"; then
    block "find with -delete / -exec rm — bulk delete"
fi

# --- gh api with a writing method. `gh api` is a general-purpose authenticated
#     GitHub client: `gh api -X DELETE /repos/:owner/:repo` deletes the repo,
#     and other endpoints can strip branch protection. Read-only is fine. ---
# Per command (v1.69.0). A POST to graphql passes the floor: whether it is a
# read (an inline query) or a write (a mutation) is the reader's call.
# `-[A-Z]*X`: gh bundles short flags, so `-iX DELETE` is `-X DELETE`.
if grep -oE '(^|[;&|[:space:]])([^[:space:];&|]*/)?gh[[:space:]]+api([[:space:]][^;&|]*)?' <<<"$CMD_GITFLOOR" | LC_ALL=C awk '
    { line = toupper($0) }
    line ~ /(-[A-Z]*X|--METHOD)[[:space:]]*=?[[:space:]]*["\047]?(POST|PUT|PATCH|DELETE)/ {
        graphql_post = (line ~ /(^|[[:space:]])\/?GRAPHQL([[:space:]]|$)/) && (line !~ /(-[A-Z]*X|--METHOD)[[:space:]]*=?[[:space:]]*["\047]?(PUT|PATCH|DELETE)/)
        if (!graphql_post) found = 1
    }
    END { exit !found }'; then
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
if [ "$REMOTE_DELETE" = 1 ] || [ "$READER_DELETE" != 0 ]; then
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

# A redirection and its target are not words of the command (v1.69.0
# review: `2>&1` became branch names "2" and "1" that did not exist).
REDIRS = {">", ">>", "<", ">&", "<&", "&>", "&>>", ">|", "<>", "<<", "<<<", "<<-"}
clean, skip = [], False
for tok in tokens:
    if skip:
        skip = False
        continue
    if tok in REDIRS:
        if clean and clean[-1].isdigit():
            clean.pop()
        skip = True
        continue
    clean.append(tok)
tokens = clean

segments, cur = [], []
for tok in tokens:
    if tok in SEPARATORS:
        segments.append(cur)
        cur = []
    else:
        cur.append(tok)
segments.append(cur)

# The merged-branch check runs in the session's repo, so the delete must run
# there too (v1.69.0 review: `{ cd X;`, `pushd X`, `builtin cd X`,
# `GIT_DIR=X` and `export GIT_DIR` all moved the push elsewhere while the
# check approved it).
if {"cd", "pushd", "popd"} & set(tokens):
    verdict("BLOCK `cd` / `pushd` in the same command; run the delete from the repo itself")
if any(re.match(r"^GIT_(DIR|WORK_TREE|CONFIG\w*|NAMESPACE|COMMON_DIR|INDEX_FILE|OBJECT_DIRECTORY|ALTERNATE_OBJECT_DIRECTORIES)=", t) for t in tokens):
    verdict("BLOCK a GIT_* variable that moves git to another repo or config; run the delete plainly")

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

if int(os.environ.get("SAFETY_READER_DELETE") or 0) > len(deletes):
    # The per-command reader saw more remote deletes than this parser can
    # place (v1.69.0 review: an ask named one branch while a second delete,
    # spelled --{d..d}elete, went through with it). Disagree -> block.
    verdict("BLOCK could not identify every branch being deleted; run each as a plain `git push <remote> --delete <branch>`")

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
        # A push goes to remote.<name>.pushurl when one is set: check that.
        target = git("config", "--get", f"remote.{remote}.pushurl").stdout.strip() or remote
        sym = git("ls-remote", "--symref", target, "HEAD")
        default = ""
        for line in sym.stdout.splitlines():
            if line.startswith("ref: refs/heads/") and line.endswith("\tHEAD"):
                default = line[len("ref: refs/heads/"):-len("\tHEAD")]
        if sym.returncode != 0 or not default:
            verdict(f"BLOCK could not read {remote}'s default branch (offline?)")
        if default in names:
            verdict(f"BLOCK {default} is {remote}'s default branch")
        heads = {}
        for line in git("ls-remote", "--heads", target).stdout.splitlines():
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
    VERDICT=$(SAFETY_CMD="$COMMAND" SAFETY_CWD="$SESSION_CWD" SAFETY_READER_DELETE="$READER_DELETE" python3 -I -c "$DELETE_CHECK_PY" 2>/dev/null) || VERDICT="BLOCK the merge check crashed"
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
