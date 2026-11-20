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
# Then MCU-Watchlist PR #167 (every git rule decided per command, six review
# rounds) and PR #179 (the rm floor reads each rm's own arguments; flags
# written in a variable or an echo in the same command count), merged with
# agentskel's own v1.69.0 rules (gh, find / fd, nested shells, any-case
# names, aliases). Reader protocol: BLOCK-REMOTE / BLOCK / ASK-DELETE n /
# ALLOW / CRASH [GIT] [RM]. Every floor here is linear: an awk pass that
# walked back over a word per hyphen kept MCU-Watchlist's hook past Claude
# Code's 600 s timeout on 160,000 hyphens (691 s), and a timed-out hook lets
# the command run.
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


LEAD_EXPANSION_OPTION = re.compile(
    r"^(?:\$(?:\{[^{}]*\}|\([^()]*\)|[A-Za-z_][A-Za-z0-9_]*|[0-9@*#?$!-])|`[^`]*`)+(--?[A-Za-z][A-Za-z-]*)\)?$")


def rmseg_line(line):
    # MCU-Watchlist's NEUTRAL_AWK as its rm floor runs it (keeplong=0,
    # rmlong=1): separators and redirections end a word; a plain --long word
    # keeps its leading "--" and only its inner hyphens are neutralised.
    for c in ";&|<>":
        line = line.replace(c, f" {c} ")
    out = []
    for w in re.split(r"[ \t]+", line.strip(" \t")):
        if not w:
            continue
        out.append("--" + w[2:].replace("-", "_") if LONG.match(w) else neutral(w, False))
        # A whole option once the expansions in front are empty (`$x-rf`,
        # `$(:)-rf`, a backtick, `$x--force`) also stands on its own, so the
        # doubtful reading counts it too (agentskel v1.69.0 differential).
        m = LEAD_EXPANSION_OPTION.match(w)
        if m:
            out.append(m.group(1))
    return " ".join(out)


mode = sys.argv[1]
text = sys.stdin.buffer.read().decode("utf-8", "surrogateescape")
f = {"rm": rm_line, "rmseg": rmseg_line}.get(mode, git_line)
sys.stdout.buffer.write("\n".join(f(l) for l in text.split("\n")).encode("utf-8", "surrogateescape"))
PY
CMD_GITFLOOR=$(printf '%s' "$CMD_STRUCT" | python3 -I -c "$FLOOR_PY" git 2>/dev/null) || CMD_GITFLOOR="$CMD_STRUCT"

# git_floor <subcommand regex> <option pattern>: true when one `git
# <subcommand>`, read up to the end of its own command (; & | or line end) or
# a `--` word (MCU-Watchlist PR #167: after `--` come paths, so `git clean -n
# -- -f` and `git push origin main -- -f` are not forced), matches the
# pattern, on the floor text above. `x\ --` is not a `--`.
git_floor_seg() { # git_floor_seg <subcommand regex>: each such git command, cut at `--`
    grep -oE "$GIT_CMD$1([[:space:]][^;&|]*)?" <<<"$CMD_GITFLOOR" \
        | sed -E 's/([^\\])[[:space:]]--([[:space:]].*)?$/\1/' || true
}
git_floor() {
    local seg
    seg=$(git_floor_seg "$1")
    [ -n "$seg" ] && grep -qE "$1[[:space:]]+.*($2)" <<<"$seg"
}

# --- Force pushes ---
PUSH_SEG=$(git_floor_seg push)
# Refspecs are still read after `--` (`git push origin -- +main` force-pushes),
# so the +refspec rule reads the push uncut; only options stop at `--`.
PUSH_ALL=$(grep -oE "$GIT_CMD"'push([[:space:]][^;&|]*)?' <<<"$CMD_GITFLOOR" || true)
if git_floor push '--force([[:space:]]|=|$)|--force[-_]with[-_]lease|-f([[:space:]]|$)' \
   || { [ -n "$PUSH_ALL" ] && grep -qE 'push[[:space:]]+([^;&|]*[[:space:]])?["'\'']?\+[^:[:space:]"'\'']' <<<"$PUSH_ALL"; }; then
    # The second pattern (v1.69.0): a `+` refspec (`+main`, `+HEAD:main`)
    # force-pushes that ref with no --force flag at all. `+:x` is a delete,
    # decided by the remote-delete verdict below. Bounded to one command, so
    # `git push origin main && echo +5` is not a force push.
    block "force push (git push --force / -f / --force-with-lease / +refspec)"
fi

# --- Pushes that delete remote branches without naming them ---
# --mirror and --prune delete every remote branch the local repo lacks. A
# remote delete: never overridable (v1.69.0 differential: with the reader
# off, the overridable force-push rule above was the only floor rule here,
# so `AGENTSKEL_UNSAFE=i-understand git push -f --prune origin` ran).
# Only a literal word: `$x--mirror` is an option built from a variable,
# blocked but overridable by the reader (owner, 2026-11-17, as MCU-Watchlist).
if [ -n "$PUSH_SEG" ] && grep -qE 'push[[:space:]]+([^;&|]*[[:space:]])?["'\'']?--(mirror|prune)(["'\''[:space:]=]|$)' <<<"$PUSH_SEG"; then
    block "git push --mirror / --prune — deletes remote branches the local repo does not have" no-override
fi

# --- Hard reset ---
if git_floor reset '--hard'; then
    block "hard reset (git reset --hard) — discards uncommitted work"
fi

# --- Force delete branch ---
if git_floor branch '-D([[:space:]]|$)|--delete[[:space:]]+.*(--force|-f)([[:space:]]|$)|(--force|-f)[[:space:]]+.*--delete([[:space:]]|$)'; then
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
if git_floor clean '-[a-zA-Z]*f|--force'; then
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
    "ASK-DELETE "[0-9]*)
        # Plain top-level remote branch deletes and nothing else (how many):
        # the verdict at the end of this script decides them (ask / block),
        # even when the regex prefilter misses the spelling (`\git`, `'git'`,
        # `(git ...)`), and blocks unless it reads exactly that many.
        READER_DELETE="${CMD_VERDICT#ASK-DELETE }"
        ;;
    *)
        # Only reached when the reader itself is broken (it prints
        # "CRASH [GIT] [RM]" when it gives up, nothing at all when python is
        # missing), so be blunt: any rm, and any git command these rules
        # cover, waits for a person. Reads CMD_HD so a $( ) inside a commit
        # message is not hidden.
        # Quotes, backslashes, $ and braces removed first, so r\m, r$'m',
        # {r,}m and {rm,-rf,y} all read as rm; and "rm" anywhere counts
        # (-O'rm ...', rm${IFS}-rf, \nrm): this path is rare, so blunt is fine.
        # The reader's own flags (it decodes $'...' and globbed command
        # words) add to this, never replace it.
        CMD_PLAIN=$(tr -d '\\"'"'"'${},' <<<"$CMD_HD")
        case "$CMD_VERDICT" in
            CRASH*" GIT"*) block "git while the per-command check could not run (strict fallback; may delete remote branches)" no-override ;;
        esac
        if grep -qiE 'git.*(push|send-pack)' <<<"$CMD_PLAIN"; then
            # A push the reader could not read may delete remote branches
            # (--delete, :branch, --mirror, --prune), which the override
            # never covers (MCU-Watchlist PR #167).
            block "git push while the per-command check could not run (strict fallback; may delete remote branches)" no-override
        fi
        case "$CMD_VERDICT" in
            CRASH*" RM"*) block "rm while the per-command check could not run (strict fallback)" ;;
        esac
        if grep -qi 'rm' <<<"$CMD_PLAIN"; then
            block "rm while the per-command check could not run (strict fallback)"
        fi
        if grep -qiE 'git.*branch' <<<"$CMD_PLAIN"; then
            block "git branch while the per-command check could not run (strict fallback)"
        fi
        if grep -qiE 'git.*(reset|checkout|switch|restore|clean|worktree|stash|update-ref|read-tree|reflog|submodule|config)' <<<"$CMD_PLAIN"; then
            block "git while the per-command check could not run (strict fallback)"
        fi
        if grep -qiE 'find.*-(delete|exec|ok)|fd.*-(x|X|-exec)|gh.*(api|delete|remove)' <<<"$CMD_PLAIN"; then
            block "find / fd / gh while the per-command check could not run (strict fallback)"
        fi
        ;;
esac

# --- Floor: the rm rule, read precisely only where that is safe ---
# MCU-Watchlist PR #179 (2026-11-10), ported in agentskel v1.69.0. Until then
# the floor read from `rm` to the end of the line, so the -fr of ffmpeg's
# `-frames:v` in the NEXT command counted against `rm x.jpg`. Accepted
# exception (owner, 2026-11-17): the floor no longer catches a delete that
# the old rule caught only because an unrelated word on the line held the
# letters -rf; the reader still reads rm's own options.
# The reader may only ADD blocks (third and fourth reviews, 2026-11-02: every
# round found a place where it misread bash). The floor is main's rule — an rm
# given a recursive option and a force option is refused — applied to each rm
# in one of two ways:
#
# P (precise, 2026-11-08). When the rm is at the top level of its line (not
# inside a quote, a substitution or a comment there) and RM_SCOPE_AWK can
# follow its arguments to a real end (; & | line break or # comment, as bash
# ends a command), only those arguments count. A quoted or escaped separator,
# `2>&1`, `&>`, `>|`, $( ), ` `, ${ }, $[ ] and ( ) do not end rm, and an
# escaped line break carries it on (joined as bash joins it). This is what
# lets `rm x.jpg; ffmpeg -i a.mp4 -frames:v 1 b.jpg` through: main's rule read
# from `rm` to the end of the line and counted ffmpeg's options. The options
# of a command inside $( ) or ` ` are not rm's (`rm -r dir $(ls -f)`), but a
# whole -rf or a long option there counts, and so does any -r or -f main's
# one-command rule counted: a blank-separated word up to the next ; & |, a
# substitution included (mainflags), and it pairs with any other option of
# that rm (`rm $(echo --force) $(echo -r x)`). Bash pastes the output into rm's
# arguments: `rm -f $(echo -r x)` is a real delete main caught, and the first
# P reading let it through (second review, 2026-11-09).
#
# D (doubt: main's reach exactly, review of 2026-11-09). Anywhere the floor
# cannot be sure where the rm starts or ends, it reads the rm as main did:
# bundled options and long-option pairs to the end of the line, separate -r
# and -f up to the next ; & | (a redirection such as >| or 2>&1 is not one).
# That is: the rm sits inside a quote, a substitution or a comment on its line
# (an rm inside `bash -c "..."`, a backtick or eval, or just the word in prose
# or a message); its arguments
# hold an escaped quote or backtick (inside such a string \" is a real quote);
# a quote, separator, comment or backslash inside $( ), ` `, ${ }, $[ ] or
# ( ), or a `case` there (its pattern closes a parenthesis); or a quote still
# open where the line ends. The first version (cc17b6b) read these precisely
# and was wrong both ways: it let through five real recursive force deletes
# that only main's floor caught (`` echo "` rm \"a;b\" -rf`" ``, `rm $(case a
# in a) echo y;; esac) -rf`), and an apostrophe after an "rm" in prose ("Don't
# rm it's needed" in a heredoc) read every later line as rm's arguments.
#
# Both ways count whole option words only (RM_FLAGS_AWK): a word is an option
# when nothing literal follows its letters, so -frames:v and -rf.txt are not
# (rm would reject them and delete nothing). Both read the spellings main
# never saw: "-rf", -r'f', -rf"", -rf$x, -{r,f}, -r{f,}, and long options by
# the prefixes rm accepts (--rec, --forc), except that the D way pairs long
# options across the whole line only as the full words, as main did. The
# options in one brace list combine ({-r,-f} is -r -f to rm). Both ways also
# read a long word glued to something (`"--force"`, `--force)` as in
# `$(echo --force)`) as -f...r, as main did: that is how main caught real
# deletes the second and third versions missed (`rm "a;b" $(echo --force)
# $(echo -r x)`), at the cost main paid too (`rm $(echo --force) x`). (A D way
# that counted words exactly as main did lost real deletes main had caught only
# because an unrelated word held the letters, tried and measured 2026-11-09.)
# Hyphens that cannot start a working option are set aside first
# (NEUTRAL_AWK above): one inside a word that does not start with
# "-", or in the middle of an option cluster ("-confirmed", "-four",
# `$DIR/run-after.txt`); `$x-rf` (x empty), `$(:)-rf`, `` `:`-rf ``, `*-rf`,
# `$x--force` and `{-rf,}` stay.
#
# If RM_SCOPE_AWK runs out of its step budget, fails, or finds an awk that
# cannot split a line into characters, every rm is read exactly as main read it
# (to the end of its line, and to the next ; & | with no redirection
# exception), with whole option words. If RM_FLAGS_AWK fails, every rm is
# refused. The price, as on main: an rm the floor cannot tell is inside a
# string or comment counts (`gh pr create --body "Blocks rm path -rf now"`), so
# does one bash would not run (behind a || that succeeds, in a heredoc whose end
# line has more on it) or that also holds an option rm rejects, and so does -rf
# after `--`. Measured on 5,300 generated commands, those are the only kinds of
# refusal the floor adds over main (2026-11-09).
#
# Lines are read once into characters: substr() on a long line is slow in
# BWK awk (macOS), and a character loop over it was quadratic. No [[:space:]]
# inside awk: some mawk builds do not have it.
#
# agentskel: MCU's NEUTRAL_AWK pass between the two awk programs below is
# replaced by FLOOR_PY's linear "rmseg" mode (the same rule): the awk walked
# back over a word for every hyphen, and a long run of hyphens kept the hook
# past Claude Code's 600 s timeout, which lets the command run (measured on
# MCU-Watchlist main, 2026-11-16: 691 s at 160,000 hyphens).
RM_SCOPE_AWK='
function load(l,    n, i) {       # the characters of line l, read once
    if (l in LEN) return
    n = split(L[l], T, "")
    if (n != length(L[l])) bail = 1
    LEN[l] = n
    for (i = 1; i <= n; i++) CH[l, i] = T[i]
}
function ch(l, c) { load(l); if (c <= LEN[l]) return CH[l, c]; return (l < N) ? "\n" : "" }
function nxt() { return (Cc <= LEN[Cl]) ? ch(Cl, Cc + 1) : ch(Cl + 1, 1) }
function adv() {
    if (++steps > 1000000) bail = 1
    load(Cl)
    if (Cc <= LEN[Cl]) Cc++
    else { Cl++; Cc = 1 }
}
# where a $( ), ` ` or ( ) starts and ends at the top of rm k (its text is not rm k)
function open(k) { if (++BD == 1) { NIV[k]++; IVSL[k, NIV[k]] = Cl; IVSC[k, NIV[k]] = Cc } }
function shut(k) { if (--BD == 0) { IVEL[k, NIV[k]] = Cl; IVEC[k, NIV[k]] = Cc } }
# Mark the rm starts on line l that sit at its top level (TOP). Stops at a
# comment, or where it cannot follow a quote inside a substitution: every rm
# after that is read the D way.
function prescan(l,    c, n, x, y, st, top, prev) {
    load(l); n = LEN[l]; st = ""; prev = " "
    for (c = 1; c <= n; c++) {
        x = CH[l, c]; y = (c < n) ? CH[l, c + 1] : ""
        top = substr(st, length(st), 1)
        if (st == "") {
            if ((l, c) in START) TOP[START[l, c]] = 1
            if (x == "\\") { c++; prev = "x"; continue }
            if (x == "\047" || (x == "$" && y == "\047")) {
                if (x == "$") c++
                for (c++; c <= n && CH[l, c] != "\047"; c++) if (x == "$" && CH[l, c] == "\\") c++
                prev = "x"; continue
            }
            if (x == "#" && (prev == " " || prev == "\t")) return
        } else if (top == "D") {
            if (x == "\\") { c++; continue }
            if (x == "\"") { st = ""; prev = x; continue }
        } else {
            if (x == top) { st = substr(st, 1, length(st) - 1); prev = x; continue }
            if (x == "\"" || x == "\047" || x == "\\" || x == "#") return
        }
        if (x == "(" && top != "D") { st = st ")"; prev = x; continue }
        if ((x == "$" || (top != "D" && (x == "<" || x == ">"))) && y == "(") { st = st ")"; c++; prev = y; continue }
        if (x == "$" && y == "[") { st = st "]"; c++; prev = y; continue }
        if (x == "$" && y == "{") { st = st "}"; c++; prev = y; continue }
        if (x == "`") { st = st "`"; prev = x; continue }
        if (x == "\"" && st == "") { st = "D"; prev = x; continue }
        prev = x
    }
}
# Read rm k from after its name. A stack holds what is open: D for a double
# quote, and the closer of each $( ), ` `, ${ }, $[ ] or ( ). MODE ends P or D.
function scan(k,    st, x, y, top, prev, np, i) {
    Cl = SL[k]; Cc = SC[k] + 2; st = ""; prev = ""; BD = 0; NIV[k] = 0; np = 0; MODE = "P"
    while (!bail) {
        x = ch(Cl, Cc)
        if (x == "") { if (st != "") MODE = "D"; break }
        y = nxt()
        top = substr(st, length(st), 1)
        if (st == "") {
            # a later rm passed here unquoted reads exactly as this one does from now on
            if (((Cl, Cc) in START) && START[Cl, Cc] > k) PEND[++np] = START[Cl, Cc]
            if (x == "\\") {
                if (y == "\"" || y == "\047" || y == "`") { MODE = "D"; break }
                adv(); adv()
                if (y != "\n") prev = "x"   # a line continuation keeps the character before it
                continue
            }
            if (x == "\047" || (x == "$" && y == "\047")) {
                if (x == "$") adv()
                adv()
                while (!bail) {
                    y = ch(Cl, Cc)
                    if (y == "\047" || y == "" || y == "\n") break
                    if (x == "$" && y == "\\") { if (nxt() == "\n") { y = "\n"; break } adv() }
                    adv()
                }
                if (y != "\047") { MODE = "D"; break }
                adv(); prev = "x"; continue
            }
            if (x == ";" || x == "\n" || (x == "|" && prev != ">") ||
                (x == "&" && prev != ">" && prev != "<" && y != ">") ||
                (x == "#" && (prev == " " || prev == "\t"))) break
        } else if (top == "D") {
            if (x == "\n" || (x == "\\" && (y == "\"" || y == "`" || y == "\n"))) { MODE = "D"; break }
            if (x == "\\") { adv(); adv(); prev = "x"; continue }
            if (x == "\"") { st = ""; adv(); prev = x; continue }
        } else {
            if (x == top) { st = substr(st, 1, length(st) - 1); if (x == ")" || x == "`") shut(k); adv(); prev = x; continue }
            if (x == "\"" || x == "\047" || x == "\\" || x == ";" || x == "&" || x == "|" || x == "#" || x == "\n" ||
                (x == "c" && y == "a" && ch(Cl, Cc + 2) == "s" && ch(Cl, Cc + 3) == "e")) { MODE = "D"; break }
        }
        # openers: valid unquoted, inside a double quote, and inside each other
        if (x == "(" && top != "D") { st = st ")"; adv(); open(k); prev = x; continue }
        if ((x == "$" || (top != "D" && (x == "<" || x == ">"))) && y == "(") { st = st ")"; adv(); adv(); open(k); prev = y; continue }
        if (x == "$" && y == "[") { st = st "]"; adv(); adv(); prev = y; continue }
        if (x == "$" && y == "{") { st = st "}"; adv(); adv(); prev = y; continue }
        if (x == "`") { st = st "`"; adv(); open(k); prev = x; continue }
        if (x == "\"" && st == "") { st = "D"; adv(); prev = x; continue }
        adv(); prev = x
    }
    EL[k] = Cl; EC[k] = Cc
    if (MODE == "P") for (i = 1; i <= np; i++) if (!(PEND[i] in SAME)) SAME[PEND[i]] = k
}
# text from (l1, c1) up to (l2, c2); a line continuation joins with nothing between
function piece(l1, c1, l2, c2,    out, l) {
    if (l1 == l2) return substr(L[l1], c1, c2 - c1)
    out = substr(L[l1], c1)
    for (l = l1 + 1; l <= l2; l++) {
        sub(/\\$/, "", out)
        out = out ((l < l2) ? L[l] : substr(L[l], 1, c2 - 1))
    }
    return out
}
function outer(k,    s, m, pl, pc) {    # rm k without the text of its $( ), ` ` and ( )
    pl = SL[k]; pc = SC[k]; s = ""
    for (m = 1; m <= NIV[k]; m++) { s = s piece(pl, pc, IVSL[k, m], IVSC[k, m]); pl = IVEL[k, m]; pc = IVEC[k, m] }
    return s piece(pl, pc, EL[k], EC[k])
}
function clean(s) { gsub(SEP, " ", s); return s }
# rm k read the D way: to the end of its line (once per line), and to the next ; & | (once per stretch)
function dline(k,    l, c, n, e, x) {
    l = SL[k]; c = SC[k]; load(l); n = LEN[l]
    if (!(l in DL)) { DL[l] = 1; OUT[++no] = "D " SEP " " SEP " " clean(substr(L[l], c)) }
    if (c >= DP[l]) {
        e = plainend(l, c, 1)
        DP[l] = e
        OUT[++no] = "D " SEP " " clean(substr(L[l], c, e - c)) " " SEP
    }
}
# Where main stopped reading rm k: the next ; & | on its line. One escaped by a
# backslash is not a separator in any quoting, so it never ends the stretch;
# with redir, neither does a redirection (>| 2>&1 <&0 &>).
function plainend(l, c, redir,    n, e, x, b) {
    load(l); n = LEN[l]
    for (e = c; e <= n; e++) {
        x = CH[l, e]
        if (x != ";" && x != "&" && x != "|") continue
        for (b = 0; e - b - 1 >= 1 && CH[l, e - b - 1] == "\\"; b++) ;
        if (b % 2) continue
        if (redir && ((x == "|" && e > 1 && CH[l, e - 1] == ">") ||
            (x == "&" && ((e > 1 && (CH[l, e - 1] == ">" || CH[l, e - 1] == "<")) || (e < n && CH[l, e + 1] == ">"))))) continue
        break
    }
    if ((steps += e - c) > 1000000) bail = 1
    return e
}
# main one-command rule on rm k: R when a -r (or --recursive) and F when a -f
# (or --force) stands as a whole blank-separated word before the next ; & |,
# a substitution included (bash pastes its output into rm arguments).
function mainflags(k,    l, c, e, s, out) {
    l = SL[k]; c = SC[k]
    e = plainend(l, c, 0)
    if (k in SAME) { if (c < MP[l]) return ""; MP[l] = e }   # a stretch already read
    s = " " substr(L[l], c, e - c) " "
    gsub(/[\t\r\f]/, " ", s)
    out = (s ~ / (-[A-Za-z]*[rR][A-Za-z]*|--recursive) /) ? "R" : ""
    if (s ~ / (-[A-Za-z]*[fF][A-Za-z]*|--force) /) out = out "F"
    return out
}
BEGIN { if (SEP == "") SEP = sprintf("%c", 28); WS = " \t\r\v\f" }
{ L[++N] = $0 }
END {
    if (split("ab", T, "") != 2) { print "WHOLE"; exit }
    for (i = 1; i <= N; i++) {      # every rm that main would start reading at
        if (!index(L[i], "rm")) continue
        load(i); n = LEN[i]; found = 0
        for (j = 1; j + 2 <= n; j++)
            if (CH[i, j] == "r" && CH[i, j + 1] == "m" && (j == 1 || index(";&|(`" WS, CH[i, j - 1])) && index(WS, CH[i, j + 2])) {
                K++; SL[K] = i; SC[K] = j; START[i, j] = K; found = 1
            }
        if (found) prescan(i)
    }
    for (k = 1; k <= K && !bail; k++) {
        if (!(k in TOP)) { dline(k); continue }
        if (k in SAME) {            # ends where an earlier rm ends: inside its text
            if (mainflags(k) == "RF") OUT[++no] = "H " SEP " " SEP
            continue
        }
        scan(k)
        if (bail) break
        if (MODE == "D") dline(k)
        else OUT[++no] = "P " SEP " " clean(outer(k)) " " SEP " " clean(piece(SL[k], SC[k], EL[k], EC[k])) " " SEP " x" mainflags(k)
    }
    if (bail) { print "WHOLE"; exit }
    for (i = 1; i <= no; i++) print OUT[i]
}'
# One line per rm: "P outer full flags", "D plain line", or "H" when main's
# one-command rule already refuses (SEP between; flags: R and F for a -r and a
# -f that main's one-command rule counted). A word is an
# option when its letters (quotes, backslashes and a brace list inside it are
# bash's, not the word's) are followed by nothing literal. One hyphen: a
# cluster, read by its letters. Two at the start of a word: a long option,
# read by prefix. Two or more glued to something else are read both ways,
# since an expansion before them may come out empty (`$x--force`) or be an
# operator (`${u:--rf}` is -rf, `${u:---force}` is --force).
# P: one cluster with r and f anywhere, or a recursive and a force option where
# short options come from outside $( ), long ones from anywhere, and -r / -f
# from wherever main's one-command rule counted them. D: one such
# cluster to the end of the line; --recursive and --force as whole words to the
# end of the line (as main read long options); or a recursive and a force
# option before the next ; & |, where a word that ends a $( ) or ` ` opened
# after the rm (the -f of `$(ls -f)`) does not count. Prints HIT when an rm qualifies, else NONE.
RM_FLAGS_AWK='
function part(s, dmode,    n, i, j, h, w, x, br, glued, r, f, sub_end, dp, bt, bo, bR, bF, odd) {
    R = 0; F = 0; B = 0; LR = 0; LF = 0; dp = 0; bt = 0; bo = 0
    n = split(s, T, "")
    for (i = 1; i <= n; i++) {
        if (T[i] == "(") dp++         # a $( ) or ` ` opened after the rm started
        else if (T[i] == ")" && dp) dp--
        else if (T[i] == "`") bt = !bt
        # a brace list is one word to the reader but several to rm: {-r,-f} is -r -f
        if (T[i] == "{") { bo = 1; bR = 0; bF = 0 }
        else if (T[i] == "}" && bo) { if (bR && bF) B = 1; bo = 0 }
        else if (T[i] == " " || T[i] == "\t") bo = 0
        if (T[i] != "-" || (i > 1 && T[i - 1] == "-")) continue
        for (j = i; j <= n && T[j] == "-"; j++) ;
        h = j - i; w = ""; br = 0; odd = 0
        for (; j <= n; j++) {
            x = T[j]
            if (x ~ /[A-Za-z]/) w = w x
            else if (x == "{") { br = 1; odd = 1 }
            else if (br && x == ",") continue
            else if (br && x == "}") br = 0
            else if (x != "\"" && x != "\047" && x != "\\") break
            else odd = 1
        }
        if (w == "" || (j <= n && index(LIT, T[j]))) continue
        glued = (h > 1 && i > 1 && !index(" \t\"\047", T[i - 1]))
        sub_end = dmode && j <= n && ((T[j] == ")" && dp) || (T[j] == "`" && bt))
        if (h == 1 || glued) {
            r = (w ~ /[rR]/); f = (w ~ /[fF]/)
            if (r && f) B = 1
            if (!sub_end) { if (r) R = 1; if (f) F = 1 }
            if (bo && (T[i - 1] == "{" || T[i - 1] == ",")) { if (r) bR = 1; if (f) bF = 1 }
        }
        # main kept the hyphens of a long word that is not plain (`"--force"`,
        # `--force)`, as in $(echo --force)) and read -force as -f...r; both
        # ways keep that reading, so neither misses what main caught this way
        if (h == 2 && !glued && w ~ /[rR]/ && w ~ /[fF]/ &&
            (odd || (i > 1 && !index(" \t", T[i - 1])) || (j <= n && !index(" \t", T[j])))) B = 1
        if (h == 2 || glued) {
            if (index("recursive", w) == 1) { if (!dmode || w == "recursive") LR = 1; if (!sub_end) R = 1 }
            if (index("force", w) == 1) { if (!dmode || w == "force") LF = 1; if (!sub_end) F = 1 }
        }
    }
}
BEGIN {
    if (SEP == "") SEP = sprintf("%c", 28)
    LIT = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._/:=~^%#_-"
}
{
    k = index($0, SEP); if (!k) { hit = 1; next }
    kind = substr($0, 1, k - 1); rest = substr($0, k + 1)
    k = index(rest, SEP); if (!k) { hit = 1; next }
    if (index(kind, "H")) { hit = 1; next }
    dmode = !index(kind, "P")
    a = substr(rest, 1, k - 1); rest = substr(rest, k + 1); fl = ""
    if (!dmode) { k = index(rest, SEP); if (!k) { hit = 1; next } fl = substr(rest, k + 1); rest = substr(rest, 1, k - 1) }
    part(a, dmode); ra = R; fa = F
    part(rest, dmode)
    if (!dmode) { if (B || ((ra || LR || index(fl, "R")) && (fa || LF || index(fl, "F")))) hit = 1 }
    else if (B || (LR && LF) || (ra && fa)) hit = 1
}
END { print (hit ? "HIT" : "NONE") }'
RM_SEP=$(printf '\034')
RM_SEGS=$(LC_ALL=C awk -v SEP="$RM_SEP" "$RM_SCOPE_AWK" <<<"$CMD_STRUCT" 2>/dev/null) || RM_SEGS=WHOLE
if [ "$RM_SEGS" = WHOLE ]; then
    # the old rule on every rm: to the end of the line, and to the next ; & |
    RM_SEGS=$( { grep -oE '(^|[;&|[:space:](`])rm[[:space:]].*' <<<"$CMD_STRUCT" | sed "s/^/D $RM_SEP $RM_SEP /"
                 grep -oE '(^|[;&|[:space:](`])rm[[:space:]][^;&|]*' <<<"$CMD_STRUCT" | sed "s/^/D $RM_SEP /; s/\$/ $RM_SEP/"; } ) || true
fi
if [ -n "$RM_SEGS" ]; then
    # Either step failing is a block, not a pass.
    RM_FLAGS=$(printf '%s\n' "$RM_SEGS" | python3 -I -c "$FLOOR_PY" rmseg 2>/dev/null | LC_ALL=C awk -v SEP="$RM_SEP" "$RM_FLAGS_AWK" 2>/dev/null) || RM_FLAGS=HIT
    if [ "$RM_FLAGS" != NONE ]; then
        block "recursive force delete (rm -rf / -fr / -r -f / --recursive --force) — cannot be undone"
    fi
fi

# --- Worktree force remove ---
if git_floor 'worktree[[:space:]]+remove' '--force|-f([[:space:]]|$)'; then
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
if git_floor checkout '--force([[:space:]]|$)|-[a-zA-Z]*f([[:space:]]|$)'; then
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
def strip_comments(text):
    # A `#` that STARTS a word, outside quotes, starts a comment that ends at
    # the line break (MCU-Watchlist PR #167: `git push origin --delete
    # merged-a # cleanup` read "#" and "cleanup" as branch names). Not
    # shlex's commenters: it also cuts `a#b` in the middle of a word, so the
    # ask would name branch "a" while bash deletes "a#b".
    out, i, n, sq, dq = [], 0, len(text), False, False
    while i < n:
        c = text[i]
        if sq:
            sq = c != "'"
        elif c == "\\":
            out.append(text[i:i + 2])
            i += 2
            continue
        elif dq:
            dq = c != '"'
        elif c == "'":
            sq = True
        elif c == '"':
            dq = True
        elif c == "#" and (i == 0 or text[i - 1] in " \t\n;&|()"):
            end = text.find("\n", i)
            i = n if end < 0 else end
            continue
        out.append(c)
        i += 1
    return "".join(out)


cmd = strip_comments(cmd.replace("\\\n", " ")).replace("\n", " ; ")

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

if int(os.environ.get("SAFETY_READER_DELETE") or 0) != len(deletes):
    # The per-command reader and this parser must count the same plain
    # deletes (v1.69.0 review: an ask named one branch while a second delete,
    # spelled --{d..d}elete, went through with it; MCU-Watchlist PR #167:
    # exactly n, in either direction). Disagree -> block.
    verdict("BLOCK could not identify every branch being deleted; run each as a plain `git push <remote> --delete <branch>`")

def nested_delete(words):
    # A git push delete that starts inside backticks, $( ), ( ) or quotes in
    # this segment (v1.69.0 differential: `echo \`git push origin --delete
    # x\` # note` went through once the comment was read as one).
    for k, w in enumerate(words):
        core = re.sub(r"^[`$(\"'{\\]+", "", w)
        if core != w and os.path.basename(core).lower() == "git":
            rest = [re.sub(r"[`)\"'}]+$", "", x) for x in words[k + 1:]]
            if "push" in rest:
                tail = rest[rest.index("push") + 1:]
                if ({"--delete", "-d", "--mirror", "--prune"} & set(tail)
                        or any(re.match(r"^\+?:[^:]", x) for x in tail)):
                    return True
    return False


# A whole push-delete in one word (`bash -c "git push --delete …"`) or one
# that starts inside a substitution: this parser cannot ask about either.
nested = ([t for t in tokens if "push" in t and ("--delete" in t or " -d" in t or " :" in t)]
          or any(nested_delete(s) for s in segments))
if nested:
    verdict("BLOCK branch delete inside a nested command string; run it directly")

if not deletes:
    # The prefilter matched, but no segment is a `git push` delete: e.g. a
    # plain push chained with `date -d …`. Allow it.
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
