#!/usr/bin/env python3
"""Per-command checks for pre-bash-safety.sh.

Decided here, per command: recursive force rm, force branch delete, and
(v1.69.0, agentskel BL-007/BL-009/BL-010) every other destructive git form,
find -delete / -exec rm, and gh api writes:

    git push   --force / -f (any cluster, e.g. -uf) / --force-with-lease /
               a +refspec / --mirror / --prune
    git reset --hard
    git checkout -f / -- <paths> / . / <tree-ish> <paths>
    git switch -f / --discard-changes
    git restore (any)
    git clean -f / --force
    git worktree remove -f / --force
    git stash drop / clear
    find -delete / -exec|-execdir|-ok|-okdir rm
    gh api with a writing method, including the POST that -f/-F/--field/
           --raw-field/--input imply without -X; graphql only for an inline
           query that is not a mutation and that the shell cannot change

A remote branch delete (git push --delete / -d / :branch) is NOT decided here
when it is a plain top-level command: the hook's own verdict asks or blocks
(merged-branch check). Anywhere else (inside $( ), backticks, a ( ) group,
bash -c, eval, ...) it is blocked, because nothing can ask about a command it
cannot see.

The command arrives on stdin (heredoc bodies already removed, commit messages
NOT removed: a `$( )` inside a message runs). Prints one line:
    BLOCK <reason>    or    ALLOW    or    ALLOW DELETE
("ALLOW DELETE": nothing to block here, but a top-level remote branch delete
was seen; the hook must run its delete verdict even if its own prefilter
missed the command, e.g. a backslash-escaped or quoted `git` word.)
Anything else (CRASH, a timeout, missing python) makes the hook fall back to
blocking every rm and every destructive git / find / gh api word: fail closed.

Why a reader and not a regex (MCU-Watchlist, 2026-11-02): a regex sees one
string, so it either reads past the end of a command (`rm -r a; ls -f b`
counted as -rf; any hyphenated file name with an r and an f, "-confirmed",
"-four", tripped it) or stops at the wrong place (`rm -r $(cat list) -f` ended
at the `(`). This reads the line the way bash splits it:

- Words: quotes ('', "", $'' with escapes decoded, $""), backslashes, and
  brace expansion ({-r,-f}) give the word bash would pass. A quoted or escaped
  ; & | is part of a word, not a separator.
- Commands end at ; & && | || |& newline, and at the end of a ( ) group.
  `&>` and `>&` are redirections; their targets are not arguments. `#` at the
  start of a word starts a comment (inside backticks it ends at the backtick).
- $( ), backticks (and \\` nested in backticks), <( ), >( ) are commands of
  their own, read wherever they appear (in a word, in double quotes, in ${ },
  in $(( ))); in the outer command they count as one word. `$((` is read both
  as arithmetic and as a command substitution, since bash may take either.

Which text is read again as commands (owner decision 2026-11-02, after the
second review showed a list of "command runners" can never be complete:
trap, pipes into a shell, here-strings, flock, GIT_SSH_COMMAND, git rebase -x,
tmux, $SHELL -c ...):

- EVERY word that contains a space or a shell character after quote removal,
  every redirection target (here-strings included), and the arguments after
  eval / ssh / watch joined into one line (they join before running);
- EXCEPT search patterns (grep, egrep, fgrep, zgrep, rg, ag, ack, git grep,
  git log -S/-G/--grep) and message values (-m/--message on any command and
  combined git flags like -am; --title/--body, and -t/-b for gh).
  `echo "rm -rf is dangerous"` is therefore blocked: the fail-safe cost.

Not seen (no static check can): a command name or flags built at run time
(`$(which rm) -rf x`, `x=rm; $x -rf y`, `bash -c 'rm -r "$@"' _ -f x`). This
includes a flag assembled from the OUTPUT of a substitution or from word
splitting, e.g. `rm $(echo x-rf | cut -c2-) y` or `IFS=a; rm $(echo a-rf) y`:
the `-rf` does not exist in the command text, only after bash runs it. The
pre-v1.69.0 coarse substring rule blocked some of these by accident (it also
blocked real hyphenated filenames, the bug MCU-Watchlist PR #165 fixed);
allowing the filenames necessarily allows these, so they are an accepted limit
(MCU-Watchlist owner, 2026-11-03; kept as is in agentskel v1.69.0).
The environment's own delete-safety check is a second layer underneath.
"""
import os
import re
import signal
import sys

PLACEHOLDER = "\x00"
MAX_DEPTH = 40          # nesting of $( ) / backticks / ( ) before giving up
REREAD_DEPTH = 6        # quoted text inside quoted text inside ...
BRACE_LIMIT = 256       # expansions per word before giving up
TIME_LIMIT = 8          # seconds; then CRASH, and the hook blocks rm / branch
WRAPPERS = {"sudo", "doas", "env", "command", "builtin", "exec", "nohup", "nice",
            "time", "timeout", "stdbuf", "xargs", "!"}
JOINERS = {"eval", "ssh", "watch"}
SEARCHERS = {"grep", "egrep", "fgrep", "zgrep", "rg", "ag", "ack"}
MESSAGE_FLAGS = {"-m", "--message"}
GH_MESSAGE_FLAGS = {"-t", "--title", "-b", "--body"}
GIT_LOG_PATTERN_FLAGS = {"-S", "-G", "--grep"}
GIT_OPTS_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path",
                       "--config-env", "--super-prefix", "--list-cmds", "--attr-source"}
# What bash itself treats as special: ASCII blanks only (a non-breaking space
# is an ordinary character to bash, but \s in Python matches it).
SHELL_CHARS = re.compile(r"[ \t\n\r;&|()<>`$\\'\"\x00{!]")


class TooComplex(Exception):
    pass


class Reader:
    def __init__(self, text, depth=0):
        self.s = text
        self.i = 0
        self.commands = []      # every simple command found: a list of words
        self.nesting = []       # per command: its $( ) / ( ) / backtick depth
        self.strings = []       # redirection targets, read again as commands
        self.unterminated = False
        self.depth = depth

    def peek(self, k=0):
        j = self.i + k
        return self.s[j] if j < len(self.s) else ""

    def nested(self, stop):
        self.depth += 1
        if self.depth > MAX_DEPTH:
            raise TooComplex("nested too deep")
        self.parse(stop)
        self.depth -= 1

    def substitution_or_arithmetic(self):
        """At `$((`: bash reads arithmetic, unless that fails, when it reads a
        command substitution holding a subshell. Read it both ways."""
        start = self.i
        saved_unterminated = self.unterminated
        self.i = start + 2
        self.nested(")")               # as $( ( ... ) ... )
        self.i = start
        self.unterminated = saved_unterminated
        self.arithmetic()

    def arithmetic(self):
        """At `$((`: skip to the matching `))`, reading $( ), ${ } and
        backticks inside."""
        self.i += 3
        level = 2
        s = self.s
        while self.i < len(s) and level:
            c = s[self.i]
            if c == "$" and self.peek(1) == "(" and self.peek(2) != "(":
                self.i += 2
                self.nested(")")
                continue
            if c == "$" and self.peek(1) == "{":
                self.parameter()
                continue
            if c == "`":
                self.i += 1
                self.nested("`")
                continue
            if c == "(":
                level += 1
            elif c == ")":
                level -= 1
            self.i += 1

    def old_arithmetic(self):
        """At `$[`: skip to the matching `]`, reading $( ) and backticks inside."""
        self.i += 2
        level = 1
        s = self.s
        while self.i < len(s) and level:
            c = s[self.i]
            if c == "$" and self.peek(1) == "(" and self.peek(2) != "(":
                self.i += 2
                self.nested(")")
                continue
            if c == "`":
                self.i += 1
                self.nested("`")
                continue
            if c == "[":
                level += 1
            elif c == "]":
                level -= 1
            self.i += 1
        if level:
            self.unterminated = True

    def extglob(self, add):
        """At the `(` of @( ) / !( ) / *( ) / +( ) / ?( ): the pattern is part of
        the word; its | and & are not separators."""
        start = self.i
        self.i += 1
        level = 1
        s = self.s
        while self.i < len(s) and level:
            c = s[self.i]
            if c == "\\":
                self.i += 2
                continue
            if c == "(":
                level += 1
            elif c == ")":
                level -= 1
            self.i += 1
        if level:
            self.unterminated = True
        add(s[start:self.i])

    def parameter(self):
        """At `${`: skip to the matching `}`, honouring quotes and reading any
        $( ) or backticks inside."""
        self.i += 2
        level = 1
        s = self.s
        while self.i < len(s) and level:
            c = s[self.i]
            if c == "\\":
                self.i += 2
                continue
            if c == "'":
                self.single_quoted()
                continue
            if c == '"':
                self.double_quoted()
                continue
            if c == "$" and self.peek(1) == "(":
                if self.peek(2) == "(":
                    self.substitution_or_arithmetic()
                else:
                    self.i += 2
                    self.nested(")")
                continue
            if c == "$" and self.peek(1) == "{":
                self.i += 2
                level += 1
                continue
            if c == "`":
                self.i += 1
                self.nested("`")
                continue
            if c in "<>" and self.peek(1) == "(":
                self.i += 2
                self.nested(")")
                continue
            # Only `${` nests: bash closes ${x:-{} at the first `}` (third
            # review: counting a plain `{` hid the rest of the line).
            if c == "}":
                level -= 1
            self.i += 1
        if level:
            self.unterminated = True

    def single_quoted(self):
        end = self.s.find("'", self.i + 1)
        if end < 0:
            self.unterminated = True
            text, self.i = self.s[self.i + 1:], len(self.s)
            return text
        text, self.i = self.s[self.i + 1:end], end + 1
        return text

    def ansi_c(self):
        """At $'...': the decoded text. Never raises on malformed escapes."""
        self.i += 2
        out = []
        s = self.s
        simple = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "e": "\x1b",
                  "E": "\x1b", "f": "\f", "v": "\v"}
        while self.i < len(s):
            c = s[self.i]
            if c == "'":
                self.i += 1
                return "".join(out)
            if c == "\\":
                m = re.match(r"\\(x[0-9a-fA-F]{1,2}|u[0-9a-fA-F]{1,4}|U[0-9a-fA-F]{1,8}|[0-7]{1,3}|c.|.?)",
                             s[self.i:self.i + 12], re.S)
                esc = m.group(1)
                self.i += len(m.group(0))
                try:
                    if esc[:1] in ("x", "u", "U") and len(esc) > 1:
                        out.append(chr(int(esc[1:], 16)))
                    elif esc[:1].isdigit():
                        out.append(chr(int(esc, 8)))
                    elif esc[:1] == "c" and len(esc) == 2:
                        out.append(chr(ord(esc[1]) & 0x1F))
                    else:
                        out.append(simple.get(esc, esc))
                except (ValueError, OverflowError):
                    pass  # bash drops what it cannot encode
                continue
            out.append(c)
            self.i += 1
        self.unterminated = True
        return "".join(out)

    def double_quoted(self):
        """At '"': the text, reading substitutions inside."""
        self.i += 1
        out = []
        s = self.s
        while self.i < len(s):
            c = s[self.i]
            if c == '"':
                self.i += 1
                return "".join(out)
            if c == "\\" and self.peek(1) in ('$', '`', '"', '\\', '\n'):
                if self.peek(1) != "\n":
                    out.append(self.peek(1))
                self.i += 2
                continue
            if c == "$" and self.peek(1) == "(":
                if self.peek(2) == "(":
                    self.substitution_or_arithmetic()
                else:
                    self.i += 2
                    self.nested(")")
                out.append(PLACEHOLDER)
                continue
            if c == "$" and self.peek(1) == "{":
                self.parameter()
                out.append(PLACEHOLDER)
                continue
            if c == "`":
                self.i += 1
                self.nested("`")
                out.append(PLACEHOLDER)
                continue
            out.append(c)
            self.i += 1
        self.unterminated = True
        return "".join(out)

    def parse(self, stop=None):
        cmd = []
        word = None             # list of text pieces, or None between words
        target = False          # the next word is a redirection target
        cases = 0               # open `case ... esac`: a `)` ends a pattern
        s = self.s

        def end_word():
            nonlocal word, target, cases
            if word is not None:
                text = "".join(word)
                if target:
                    self.strings.append(text)
                    target = False
                else:
                    if not cmd and text == "case":
                        cases += 1
                    elif not cmd and text == "esac" and cases:
                        cases -= 1
                    cmd.append(text)
                word = None

        def end_command():
            nonlocal cmd, target
            end_word()
            target = False
            if cmd:
                self.commands.append(cmd)
                self.nesting.append(self.depth)
            cmd = []

        def add(text):
            nonlocal word
            if word is None:
                word = []
            word.append(text)

        while self.i < len(s):
            c = s[self.i]
            nxt = self.peek(1)
            if stop and s.startswith(stop, self.i):
                if stop == ")" and (cases or (cmd and cmd[0] == "case") or
                                    (word is not None and cmd and cmd[0] == "case")):
                    # a case pattern's `)`, not the end of $( ) (third review)
                    end_command()
                    self.i += 1
                    continue
                self.i += len(stop)
                end_command()
                return
            if c in " \t\r":
                end_word()
                self.i += 1
            elif c == "\n":
                end_command()
                self.i += 1
            elif c == "#" and word is None:
                end = s.find("\n", self.i)
                if stop == "`":     # bash finds the closing backtick first
                    tick = s.find("`", self.i)
                    if tick >= 0 and (end < 0 or tick < end):
                        end = tick
                self.i = len(s) if end < 0 else end
            elif c == "\\":
                if nxt == "\n":
                    self.i += 2
                elif nxt == "`" and stop == "`":
                    self.i += 2                 # \` inside backticks nests
                    self.nested("\\`")
                    add(PLACEHOLDER)
                else:
                    add(nxt)
                    self.i += 2
            elif c == "'":
                add(self.single_quoted())
            elif c == "$" and nxt == "'":
                add(self.ansi_c())
            elif c == "$" and nxt == '"':
                self.i += 1
                add(self.double_quoted())
            elif c == '"':
                add(self.double_quoted())
            elif c == "$" and nxt == "(":
                if self.peek(2) == "(":
                    self.substitution_or_arithmetic()
                else:
                    self.i += 2
                    self.nested(")")
                add(PLACEHOLDER)
            elif c == "$" and nxt == "{":
                self.parameter()
                add(PLACEHOLDER)
            elif c == "$" and nxt == "[":
                self.old_arithmetic()      # $[ ... ]: one word (fourth review)
                add(PLACEHOLDER)
            elif c == "(" and word is not None and word[-1][-1:] in ("@", "!", "*", "+", "?"):
                self.extglob(add)          # @(a|b) etc.: part of the word
            elif c == "`":
                self.i += 1
                self.nested("`")
                add(PLACEHOLDER)
            elif c in "<>" and nxt == "(":
                self.i += 2
                self.nested(")")
                add(PLACEHOLDER)
            elif c in "<>" or (c == "&" and nxt == ">"):
                # The digits right before a redirection are its file descriptor.
                if word is not None and "".join(word).isdigit():
                    word = None
                end_word()
                m = re.match(r"&>>?|<<<|<<-?|<>|>>|>&|<&|>\||[<>]", s[self.i:self.i + 3])
                self.i += len(m.group(0))
                target = True
            elif c in ";&|":
                end_command()
                while self.i < len(s) and s[self.i] in ";&|":
                    self.i += 1
            elif c == "(":
                end_command()
                self.i += 1
                self.nested(")")
            elif c == ")":
                end_command()
                self.i += 1
            else:
                add(c)
                self.i += 1
        end_command()


def read(text, depth=0):
    """(commands, strings, top) of `text`. top[k]: command k is a plain
    top-level command of `text` (not inside $( ), backticks or ( ))."""
    r = Reader(text, depth)
    r.parse()
    commands, strings = r.commands, r.strings
    top = [n == depth for n in r.nesting]
    if r.unterminated:
        # bash would refuse to run this; read it once more with the quotes
        # removed so flags inside the unclosed quote still count (fail safe).
        q = Reader(re.sub(r"[\"']", " ", text), depth)
        q.parse()
        commands = commands + q.commands
        strings = strings + q.strings
        top = top + [False] * len(q.commands)
    return commands, strings, top


def braces(word):
    """Brace expansion, in order: {-r,-f} -> ['-r', '-f'], {r,}m -> ['rm', 'm']."""
    words = [word]
    while True:
        changed, out = False, []
        for w in words:
            m = re.search(r"\{([^{}]*,[^{}]*)\}", w)
            if m:
                changed = True
                out.extend(w[:m.start()] + part + w[m.end():] for part in m.group(1).split(","))
            else:
                out.append(w)
            if len(out) > BRACE_LIMIT:
                raise TooComplex("brace expansion too large")
        words = out
        if not changed:
            return words


def expand(args):
    out = []
    for a in args:
        out.extend(braces(a) if "{" in a else [a])
        if len(out) > 20 * BRACE_LIMIT + len(args):
            raise TooComplex("brace expansion too large")
    return out


def name(word):
    return os.path.basename(word)


def command_name(cmd):
    """Index of the command word: after NAME=value words and wrappers."""
    i = 0
    while i < len(cmd) and (re.match(r"^[A-Za-z_][A-Za-z0-9_]*\+?=", cmd[i]) or name(cmd[i]) in WRAPPERS):
        i += 1
    return i


def rm_forced_recursive(args):
    recursive = force = False
    for arg in args:
        if arg == "--":
            break
        if arg.startswith("--"):
            opt = arg[2:].split("=", 1)[0]
            recursive |= bool(opt) and "recursive".startswith(opt)
            force |= bool(opt) and "force".startswith(opt)
        elif arg.startswith("-") and len(arg) > 1:
            recursive |= "r" in arg or "R" in arg
            force |= "f" in arg
        if recursive and force:
            return True
    return False


def git_subcommand(cmd, i):
    """cmd[i] is git: index of its subcommand, after global options."""
    j = i + 1
    while j < len(cmd) and cmd[j].startswith("-"):
        j += 2 if cmd[j] in GIT_OPTS_WITH_VALUE else 1
    return j


def git_branch_force_delete(cmd, i):
    j = git_subcommand(cmd, i)
    if j >= len(cmd) or cmd[j] != "branch":
        return False
    delete = force = False
    for arg in cmd[j + 1:]:
        if arg == "--":
            break
        if arg.startswith("--"):
            opt = arg[2:].split("=", 1)[0]
            delete |= bool(opt) and "delete".startswith(opt)
            force |= len(opt) >= 3 and "force".startswith(opt)
        elif arg.startswith("-") and len(arg) > 1:
            delete |= "d" in arg or "D" in arg
            force |= "f" in arg or "D" in arg
    return delete and force


# Options whose next word is a value, not the search pattern (third review:
# rg -r REPLACEMENT and --pre COMMAND are re-read; a blanket exemption let
# `rg a -r 'rm -rf y' | sh` through).
GREP_VALUE_OPTS = {"-A", "-B", "-C", "-m", "-f", "-d", "-D", "--file", "--include", "--exclude",
                   "--exclude-dir", "--label", "--color", "--colour", "--context", "--after-context",
                   "--before-context", "--max-count", "--devices", "--directories", "--binary-files",
                   "--group-separator"}
RG_VALUE_OPTS = {"-A", "-B", "-C", "-m", "-f", "-g", "-t", "-T", "-M", "-j", "-E", "-r", "-d",
                 "--replace", "--pre", "--pre-glob", "--glob", "--iglob", "--type", "--type-not",
                 "--max-count", "--file", "--encoding", "--max-depth", "--max-filesize",
                 "--path-separator", "--sort", "--sortr", "--ignore-file", "--threads", "--colors",
                 "--color", "--context", "--after-context", "--before-context", "--type-add",
                 "--type-clear", "--context-separator", "--field-match-separator",
                 "--field-context-separator", "--engine", "--hostname-bin", "--hyperlink-format",
                 "--dfa-size-limit", "--regex-size-limit"}
GIT_GREP_VALUE_OPTS = {"-A", "-B", "-C", "-f", "-m", "--max-depth", "--threads", "--max-count",
                       "--context", "--after-context", "--before-context"}
# A definition can make `grep`, `git` or `gh` mean anything: no exemptions then.
DEFINITION = re.compile(r"(^|[\s;&|(){}])(function\s|alias\s|[A-Za-z_][A-Za-z0-9_-]*\s*\(\s*\))")


def pattern_word(cmd, start, value_opts):
    """Indexes of the search pattern in cmd[start:]: -e/--regexp values, or
    the first word that is neither an option nor an option's value."""
    exempt, i, taken = set(), start, False
    while i < len(cmd):
        w = cmd[i]
        if w in ("-e", "--regexp"):
            if i + 1 < len(cmd):
                exempt.add(i + 1)
            taken = True
            i += 2
            continue
        if w.startswith("--regexp="):
            exempt.add(i)
            taken = True
        elif w == "--":
            if not taken and i + 1 < len(cmd):
                exempt.add(i + 1)
            break
        elif w in value_opts:
            i += 2
            continue
        elif not w.startswith("-") and not taken:
            exempt.add(i)
            taken = True
        i += 1
    return exempt


def exempt_words(cmd, definitions):
    """Indexes of words in `cmd` that are search patterns or message text."""
    exempt = set()
    if definitions:
        return exempt
    k = command_name(cmd)
    if k >= len(cmd):
        return exempt
    prog = name(cmd[k])
    if prog in ("grep", "egrep", "fgrep", "zgrep"):
        return pattern_word(cmd, k + 1, GREP_VALUE_OPTS)
    if prog == "rg":
        return pattern_word(cmd, k + 1, RG_VALUE_OPTS)
    if prog not in ("git", "gh"):
        return exempt
    sub = None
    if prog == "git":
        j = git_subcommand(cmd, k)
        sub = cmd[j] if j < len(cmd) else None
        if sub == "grep":
            if any(w.startswith("-O") or w.startswith("--open-files-in-pager") for w in cmd[j + 1:]):
                return exempt          # git grep -O<command> runs it
            return pattern_word(cmd, j + 1, GIT_GREP_VALUE_OPTS)
    for idx in range(k + 1, len(cmd)):
        w, prev = cmd[idx], cmd[idx - 1]
        if prev in MESSAGE_FLAGS or (prog == "gh" and prev in GH_MESSAGE_FLAGS):
            exempt.add(idx)
        elif prog == "git" and re.fullmatch(r"-[a-zA-Z]*m", prev):
            exempt.add(idx)                              # -am, -sm
        elif prog == "git" and sub == "log" and prev in GIT_LOG_PATTERN_FLAGS:
            exempt.add(idx)
        elif re.match(r"^(--message|--title|--body)=", w):
            exempt.add(idx)
        elif prog == "git" and sub == "log" and re.match(r"^(--grep=|-[SG].)", w):
            exempt.add(idx)
    return exempt


MAX_RM_WORDS = 64


# --- v1.69.0: every other destructive git form, find, gh api ------------------
# Each takes the words after the subcommand. Long options may be abbreviated
# (git accepts any unambiguous prefix), so prefixes count; a short option
# cluster (-uf) counts letter by letter, up to a letter that takes a value.

def opt_name(arg):
    return arg[2:].split("=", 1)[0]


def is_long(arg, full, minimum):
    o = opt_name(arg)
    return arg.startswith("--") and len(o) >= minimum and full.startswith(o)


def split_args(args, long_values=(), short_values=""):
    """(options, positionals, after_dashdash), skipping option values."""
    opts, pos, i = [], [], 0
    while i < len(args):
        a = args[i]
        if a == "--":
            return opts, pos, args[i + 1:]
        if a.startswith("--") and len(a) > 2:
            opts.append(a)
            if "=" not in a and opt_name(a) in long_values:
                i += 1
        elif a.startswith("-") and len(a) > 1:
            opts.append(a)
            for k, ch in enumerate(a[1:]):
                if ch in short_values:
                    if k == len(a) - 2:
                        i += 1          # its value is the next word
                    break
        else:
            pos.append(a)
        i += 1
    return opts, pos, []


def letters(arg, short_values=""):
    """Letters of a short option cluster, up to one that takes a value."""
    out = []
    if arg.startswith("-") and not arg.startswith("--"):
        for ch in arg[1:]:
            out.append(ch)
            if ch in short_values:
                break
    return out


PUSH_VALUES = {"push-option", "repo", "receive-pack", "exec"}


def git_push(args):
    """A reason to block, "DELETE" for a remote branch delete, or None."""
    opts, pos, rest = split_args(args, PUSH_VALUES, "o")
    refs = pos + rest
    delete = False
    for a in opts:
        if (is_long(a, "force", 3) or is_long(a, "force-with-lease", 3)
                or "f" in letters(a, "o")):
            return "force push (--force / -f / --force-with-lease) — overwrites remote history"
        if is_long(a, "mirror", 2):
            return "git push --mirror — deletes remote branches that are not local"
        if is_long(a, "prune", 3):
            return "git push --prune — deletes remote branches that are not local"
        if is_long(a, "delete", 2) or "d" in letters(a, "o"):
            delete = True
    for r in refs:
        if r.startswith("+") and not r.startswith("+:"):
            return "force push of a +refspec — overwrites remote history"
        if (r.startswith(":") and len(r) > 1) or (r.startswith("+:") and len(r) > 2):
            delete = True       # `:` alone pushes matching branches
    return "DELETE" if delete else None


def git_reset(args):
    if any(is_long(a, "hard", 2) for a in args):
        return "hard reset (git reset --hard) — discards uncommitted work"
    return None


def git_checkout(args):
    opts, pos, rest = split_args(args, {"orphan"}, "bB")
    if any(is_long(a, "force", 3) or "f" in letters(a, "bB") for a in opts):
        return "git checkout --force / -f — discards uncommitted changes"
    if rest or "." in pos or len(pos) >= 2 or any(is_long(a, "pathspec-from-file", 5) for a in opts):
        return "git checkout <paths> — overwrites uncommitted changes in those files"
    return None


def git_switch(args):
    opts, _, _ = split_args(args, {"create", "force-create", "orphan"}, "cC")
    for a in opts:
        if is_long(a, "force", 3) and not is_long(a, "force-create", 7) or "f" in letters(a, "cC"):
            return "git switch --force / -f — discards uncommitted changes"
        if is_long(a, "discard-changes", 4):
            return "git switch --discard-changes — discards uncommitted changes"
    return None


def git_clean(args):
    opts, _, _ = split_args(args, {"exclude"}, "e")
    if any(is_long(a, "force", 2) or "f" in letters(a, "e") for a in opts):
        return "git clean force (-f / --force) — removes untracked files, cannot be undone"
    return None


def git_worktree(args):
    if args[:1] == ["remove"] and any(is_long(a, "force", 2) or "f" in letters(a) for a in args[1:]):
        return "git worktree remove force (--force / -f) — discards uncommitted worktree changes"
    return None


def git_stash(args):
    if args[:1] in (["drop"], ["clear"]):
        return "git stash drop/clear — discards stashed work"
    return None


GIT_RULES = {"push": git_push, "reset": git_reset, "checkout": git_checkout, "switch": git_switch,
             "clean": git_clean, "worktree": git_worktree, "stash": git_stash}


def git_destructive(cmd, i):
    j = git_subcommand(cmd, i)
    if j >= len(cmd):
        return None
    if cmd[j] == "restore":
        return "git restore — discards uncommitted changes (modern 'checkout -- <file>')"
    rule = GIT_RULES.get(cmd[j])
    return rule(cmd[j + 1:]) if rule else None


def find_destructive(args):
    for k, a in enumerate(args):
        if a == "-delete":
            return True
        if a in ("-exec", "-execdir", "-ok", "-okdir") and k + 1 < len(args) and name(args[k + 1]) == "rm":
            return True
    return False


GH_API_LONG_VALUE_OPTS = {"--method", "--raw-field", "--field", "--header", "--input", "--jq",
                          "--template", "--cache", "--hostname", "--preview"}
GH_API_SHORT_VALUE = "XfFHqtp"    # short flags that take a value
GH_SHORT_TO_LONG = {"X": "-X", "f": "-f", "F": "-F", "H": "-H", "q": "-q", "t": "-t", "p": "-p"}
WRITE_METHODS = {"POST", "PUT", "PATCH", "DELETE"}
GRAPHQL_VAR_DECL = re.compile(r"\$([A-Za-z_][A-Za-z0-9_]*)\s*:")
# A $ reference as bash reads it: a name, one digit, or one special parameter.
DOLLAR_REF = re.compile(r"\$([A-Za-z_][A-Za-z0-9_]*|[0-9@*#?!$-])")


def gh_api(cmd, i, expansions):
    """A reason to block a `gh api` call, or None. `expansions`: the $
    references bash expands in the raw command (shell_expansions)."""
    if i + 1 >= len(cmd) or cmd[i + 1] != "api":
        return None
    method, fields, has_input, endpoint = None, [], False, None
    k = i + 2
    while k < len(cmd):
        a = cmd[k]
        if a in GH_API_LONG_VALUE_OPTS:
            opt, val, k = a, (cmd[k + 1] if k + 1 < len(cmd) else ""), k + 2
        elif a.startswith("--") and "=" in a:
            (opt, val), k = a.split("=", 1), k + 1
        elif a.startswith("--"):
            opt, val, k = a, None, k + 1
        elif a.startswith("-") and len(a) > 1:
            # gh's flag parser (pflag) bundles short flags: -iX DELETE is
            # --include plus -X DELETE, and -iXDELETE the same (PR review:
            # read as one unknown flag, a repo DELETE passed as a GET).
            opt, val, step = a, None, 1
            for pos_, ch in enumerate(a[1:], start=1):
                if ch in GH_API_SHORT_VALUE:
                    opt = GH_SHORT_TO_LONG[ch]
                    if pos_ + 1 < len(a):
                        val = a[pos_ + 1:]
                    else:
                        val, step = (cmd[k + 1] if k + 1 < len(cmd) else ""), 2
                    break
            k += step
        else:
            if endpoint is None:
                endpoint = a
            k += 1
            continue
        if opt in ("-X", "--method"):
            method = (val or "").strip().upper()
        elif opt in ("-f", "--raw-field"):
            fields.append(("raw", val or ""))
        elif opt in ("-F", "--field"):
            fields.append(("typed", val or ""))
        elif opt == "--input":
            has_input = True
    if endpoint is not None and endpoint.lstrip("/") == "graphql":
        if has_input:
            return "gh api graphql --input — the hook cannot see the query (it may be a mutation)"
        queries = [(kind, v.split("=", 1)[1]) for kind, v in fields if v.split("=", 1)[0] == "query" and "=" in v]
        if not queries:
            return "gh api graphql with no inline query — the hook cannot see what runs"
        for kind, q in queries:
            if kind == "typed" and q.startswith("@"):
                return "gh api graphql -F query=@file — the hook cannot see the query (it may be a mutation)"
            if PLACEHOLDER in q:
                return "gh api graphql query built by a command substitution — the hook cannot see it"
            if re.search(r"\bmutation\b", q):
                return "gh api graphql mutation — writes to GitHub"
            # After quote removal, a GraphQL variable ($owner, in single
            # quotes) and a shell expansion bash fills in ("$M", "$1") look
            # the same. Block when a $ reference in the query is one bash
            # expands somewhere in the raw command, or is not a declared
            # GraphQL variable. A shell variable elsewhere (-F o="$OWNER") is
            # fine.
            refs = set(DOLLAR_REF.findall(q))
            declared = set(GRAPHQL_VAR_DECL.findall(q))
            if refs & expansions or refs - declared:
                return "gh api graphql query with a $ the shell may expand — the hook cannot see the final query"
        return None
    effective = method or ("POST" if fields or has_input else "GET")
    if effective in WRITE_METHODS:
        return (f"gh api {effective} — can delete repos, remove branch protection or post content "
                "(-f/-F/--field/--input imply POST without -X)")
    return None


def shell_expansions(text):
    """The $ references bash expands in `text` (outside single quotes, not
    backslash-escaped): names, digits and special parameters. `${x}` counts
    as `x`."""
    found = set()
    single = double = False
    i = 0
    while i < len(text):
        c = text[i]
        if single:
            if c == "'":
                single = False
        elif c == "\\":
            i += 2
            continue
        elif c == "'" and not double:
            single = True
        elif c == '"':
            double = not double
        elif c == "$":
            m = re.match(r"\{?([A-Za-z_][A-Za-z0-9_]*|[0-9@*#?!$-])", text[i + 1:i + 200])
            if m:
                found.add(m.group(1))
        i += 1
    return found


def check_command(cmd, top=False, expansions=frozenset()):
    """A "BLOCK <reason>" for `cmd`, "DELETE" for a top-level remote branch
    delete (the hook's own verdict decides it), or None."""
    words = expand(cmd)     # {rm,-rf,y} and {r,}m are commands too
    rms = [i for i, w in enumerate(words) if name(w) == "rm"]
    if len(rms) > MAX_RM_WORDS:
        raise TooComplex("too many rm words")
    for i in rms:           # every rm: `env -u rm -- rm -rf y` runs the second
        if rm_forced_recursive(words[i + 1:]):
            return "BLOCK recursive force delete (rm with recursive + force flags) — cannot be undone"
    delete = False
    for i, w in enumerate(words):
        n = name(w)
        if n == "git":
            if git_branch_force_delete(words, i):
                return "BLOCK force branch delete (git branch delete + force, any spelling) — discards unmerged work"
            found = git_destructive(words, i)
            if found == "DELETE":
                if not top:
                    return ("BLOCK remote branch delete inside $( ), backticks, ( ), bash -c, eval or similar"
                            " — nothing can ask about a command it cannot see; run it as a plain command")
                delete = True
            elif found:
                return "BLOCK " + found
        elif n == "find" and find_destructive(words[i + 1:]):
            return "BLOCK find with -delete / -exec rm — bulk delete"
        elif n == "gh":
            found = gh_api(words, i, expansions)
            if found:
                return "BLOCK " + found
    return "DELETE" if delete else None


def readings(w):
    """The texts to read again for word `w`."""
    out = [w]
    m = re.match(r"^[A-Za-z_][A-Za-z0-9_.]*\+?=(.*)\Z", w, re.S)
    if m:                   # X='rm -rf y', alias z='...', -c alias.z='!rm ...'
        out.append(m.group(1))
    m = re.match(r"^(?:--[A-Za-z][A-Za-z0-9-]*=|-[A-Za-z])(.+)\Z", w, re.S)
    if m:                   # an option's attached value: --pager='...', -O'...'
        out.append(m.group(1))
    for v in list(out):
        if v.startswith("!"):
            out.append(v[1:])   # git alias / config value run by the shell
        if "\\n" in v or "\\t" in v:
            out.append(v.replace("\\n", "\n").replace("\\t", "\t"))  # printf / echo -e
    return out


def verdict(text, depth=0):
    commands, strings, top = read(text, depth)
    expansions = shell_expansions(text)
    delete = False
    for cmd, is_top in zip(commands, top):
        found = check_command(cmd, top=is_top and depth == 0, expansions=expansions)
        if found == "DELETE":
            delete = True
        elif found:
            return found
    definitions = bool(DEFINITION.search(text))
    again = []
    for w in strings:
        again.extend(readings(w))
    for cmd in commands:
        exempt = exempt_words(cmd, definitions)
        for idx, w in enumerate(cmd):
            if idx not in exempt and SHELL_CHARS.search(w):
                again.extend(readings(w))
            if name(w) in JOINERS and idx + 1 < len(cmd):
                again.append(" ".join(cmd[idx + 1:]))
    if again and depth >= REREAD_DEPTH:
        # Out of depth with text still to read: do not guess. The hook then
        # blocks any rm or git branch delete in the command (fail closed).
        raise TooComplex("quoted text nested too deep")
    for text_again in again:
        text_again = text_again.replace(PLACEHOLDER, " ")
        if text_again == text:
            continue        # reading it again would only repeat this level
        found = verdict(text_again, depth + 1)
        if not found.startswith("ALLOW"):
            return found
    return "ALLOW DELETE" if delete else "ALLOW"


def on_timeout(signum, frame):
    raise TooComplex("took too long")


if __name__ == "__main__":
    data = sys.stdin.buffer.read().decode("utf-8", "replace")
    try:
        signal.signal(signal.SIGALRM, on_timeout)
        signal.alarm(TIME_LIMIT)
        result = verdict(data)
        signal.alarm(0)
    except (TooComplex, RecursionError, Exception):
        print("CRASH")
        sys.exit(1)
    print(result)
