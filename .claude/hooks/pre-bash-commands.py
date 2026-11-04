#!/usr/bin/env python3
"""Per-command checks for pre-bash-safety.sh: recursive force rm, force
branch delete.

The command arrives on stdin (heredoc bodies already removed, commit messages
NOT removed: a `$( )` inside a message runs). Prints one line:
    BLOCK <reason>    or    ALLOW
Anything else (CRASH, a timeout, missing python) makes the hook fall back to
blocking every rm and every git branch delete: fail closed.

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
    """(commands, strings) of `text`."""
    r = Reader(text, depth)
    r.parse()
    commands, strings = r.commands, r.strings
    if r.unterminated:
        # bash would refuse to run this; read it once more with the quotes
        # removed so flags inside the unclosed quote still count (fail safe).
        q = Reader(re.sub(r"[\"']", " ", text), depth)
        q.parse()
        commands = commands + q.commands
        strings = strings + q.strings
    return commands, strings


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


def check_command(cmd):
    words = expand(cmd)     # {rm,-rf,y} and {r,}m are commands too
    rms = [i for i, w in enumerate(words) if name(w) == "rm"]
    if len(rms) > MAX_RM_WORDS:
        raise TooComplex("too many rm words")
    for i in rms:           # every rm: `env -u rm -- rm -rf y` runs the second
        if rm_forced_recursive(words[i + 1:]):
            return "BLOCK recursive force delete (rm with recursive + force flags) — cannot be undone"
    for i, w in enumerate(words):
        if name(w) == "git" and git_branch_force_delete(words, i):
            return "BLOCK force branch delete (git branch delete + force, any spelling) — discards unmerged work"
    return None


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
    commands, strings = read(text, depth)
    for cmd in commands:
        found = check_command(cmd)
        if found:
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
        if found != "ALLOW":
            return found
    return "ALLOW"


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
