#!/usr/bin/env python3
"""Drop the heredoc body of a known text-writing command, for pre-bash-safety.sh.

The command arrives on stdin and goes to stdout unchanged, unless the WHOLE
command has one of the exact shapes below. Then the heredoc body (and only the
body) is removed, so prose about a dangerous command in a commit message, a PR
body or a notes file does not trigger a block:

    git commit [flags] -F - <<'EOF'      (also -F-, --file -, --file=-)
    gh pr|issue create|edit|comment|review [opts] --body-file - <<'EOF'
    cat > FILE <<'EOF'   /   cat >> FILE <<'EOF'   /   tee [-a] FILE > /dev/null <<'EOF'

Each may be preceded by `cd DIR &&` and `git add ... &&`. The end marker must be
quoted ('EOF' or "EOF"), so bash expands nothing in the body; the body ends at
the first line that is exactly the marker; nothing may follow the heredoc.
Arguments outside the body must be plain words or quoted strings with no $,
backtick, backslash or !.

Everything else is left as it is and checked in full. That includes every
other heredoc form, unquoted markers, several heredocs, CRLF, `<<-`, a heredoc
followed by more commands, and `-m "$(cat <<'EOF' ...)"`: inside "$( )" bash
5.2 ends a heredoc at a line that only starts with the marker (`EOF)"`), so
that form cannot be matched safely. To write a message that mentions a
blocked command, use `git commit -F - <<'EOF'` or `gh ... --body-file -`.

History (MCU-Watchlist, 2026-11-02). Three versions tried to RECOGNISE heredoc
bodies anywhere in a command and skip them. Each of three independent reviews
found commands bash runs that the scanner hid: arithmetic, CRLF, `EOF)`,
`while read`, `source /dev/stdin`, `bash <(cat <<'EOF' ...)`, `cat <<'EOF' >
>(bash)`, `( cat <<'EOF' ... ) | bash`, `git rebase -x "$(cat ...)"`, a `cat`
redefined as a function, line continuations. Matching a handful of whole
command shapes, and checking everything else, has no such failure mode: a shape
it does not know is simply checked.
"""
import re
import signal
import sys

S = r"[ \t]+"                                   # spaces between words
O = r"[ \t]*"
WORD = r"[A-Za-z0-9_./@:+,=%~^-]+"              # a plain word: nothing to expand
QUOTED = r"(?:\"[^\"$`\\!\n]*\"|'[^'\n]*')"     # a quoted string with nothing to expand
ARG = rf"(?:{WORD}|{QUOTED})"
FLAG = r"(?:-[A-Za-z]+|--[a-z][a-z-]*)"         # a flag without a value
MSG = rf"(?:(?:-m|--message){S}{QUOTED})"       # an extra plain -m "..."

PREFIX = rf"(?:(?:cd{S}{ARG}|git{S}add(?:{S}{ARG})+){O}&&{O})*"
MARK = r"<<[ \t]*(?:'(?P<tag>[A-Za-z_][A-Za-z0-9_-]*)'|\"(?P<tag2>[A-Za-z_][A-Za-z0-9_-]*)\")"
# The body ends at the first line that is exactly the marker, as in bash: no
# body line may itself be the marker. (Fourth review: a lazy `(?:.*\n)*?`
# grew past the first end line whenever the rest of the shape failed there,
# so lines between two `EOF` lines were hidden although bash runs them.)
BODY = r"\n(?P<body>(?:(?!(?P=tagname)(?:\n|\Z)).*\n)*)(?P=tagname)(?=\n|\Z)"
END = r"\n?[ \t]*\Z"

GIT_COMMIT = rf"git(?:{S}-C{S}{ARG})?{S}commit(?:{S}(?:{FLAG}|{MSG}))*"
GH = rf"gh{S}(?:pr|issue){S}(?:create|edit|comment|review)(?:{S}(?:{FLAG}(?:{S}{ARG})?|{WORD}))*"

# No "$(cat <<'EOF' ... )" shapes (fourth review): inside "$( )" bash 5.2 ends
# a heredoc at a line that only STARTS with the marker (`EOF)"`, `EOF `) and
# runs the lines after it, and other shells and versions differ again. Plain
# heredocs end only at an exact marker line, so only those are matched.
SHAPES = [
    # git commit ... -F - <<'EOF'
    rf"{PREFIX}{GIT_COMMIT}{S}(?:-F{O}-|--file(?:{S}|=)-){O}{MARK}BODY{END}",
    # gh pr|issue ... --body-file - <<'EOF'
    rf"{PREFIX}{GH}{S}(?:--body-file|-F)(?:{S}|=)-{O}{MARK}BODY{END}",
    # cat > FILE <<'EOF'  /  cat >> FILE  /  tee [-a] FILE > /dev/null
    rf"{PREFIX}(?:cat{O}>>?{O}{WORD}|tee(?:{S}-a)?{S}{WORD}{O}>{O}/dev/null){O}{MARK}BODY{END}",
]


def compile_shape(shape):
    # One marker group name per shape; the body ends at the same marker.
    shape = shape.replace("BODY", BODY)
    return shape


MAX_LEN = 200_000   # longer commands are left as they are (checked in full)
TIME_LIMIT = 3      # seconds; a match taking longer is abandoned (checked in full)


def _timeout(signum, frame):
    raise TimeoutError()


def strip(text):
    if len(text) > MAX_LEN or "<<" not in text:
        return text
    try:
        signal.signal(signal.SIGALRM, _timeout)
        signal.alarm(TIME_LIMIT)
        return _strip(text)
    except TimeoutError:
        return text
    finally:
        signal.alarm(0)


def _strip(text):
    for shape in SHAPES:
        for tag_group in ("tag", "tag2"):
            pattern = compile_shape(shape).replace("(?P=tagname)", f"(?P={tag_group})")
            m = re.match(pattern, text)
            if m and m.group(tag_group):
                return text[:m.start("body")] + text[m.end("body"):]
    return text


if __name__ == "__main__":
    data = sys.stdin.buffer.read().decode("utf-8", "surrogateescape")
    sys.stdout.buffer.write(strip(data).encode("utf-8", "surrogateescape"))
