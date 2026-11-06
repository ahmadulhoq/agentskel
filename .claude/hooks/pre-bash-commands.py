#!/usr/bin/env python3
"""Per-command checks for pre-bash-safety.sh.

Decided here, per command: recursive force rm, force branch delete, and
(v1.69.0, agentskel BL-007/BL-009/BL-010) every other destructive git form,
find -delete / -exec rm, and gh api writes:

    git push   --force / -f (any cluster, e.g. -uf) / --force-with-lease /
               a +refspec / --mirror / --prune
    git reset --hard
    git checkout -f / -- <paths> / . / <tree-ish> <paths> / --ours /
               --theirs / --conflict / -p / one path (./ .. :/ a glob, or a
               file that exists in the session folder)
    git switch -f / --discard-changes
    git restore (any, except --staged alone, which only unstages)
    git clean -f / --force
    git worktree remove -f / --force
    git stash drop / clear
    git branch -M / -C (and --move/--copy --force)
    plumbing: update-ref -d, read-tree --reset -u, checkout-index -f,
               send-pack --force / +ref, reflog delete / expire,
               submodule update / deinit -f
    git aliases that run any of these (-c alias.*, --config-env,
               GIT_CONFIG_*, git config alias.* in the same command, aliases
               stored in the repo); a shell (!) alias defined and run in one
               command; git config storing a destructive or shell alias,
               remote.*.mirror, remote.*.push=+..., clean.requireForce=false
    find -delete / -exec|-execdir|-ok|-okdir and fd -x/-X running a remover
               (rm, unlink, shred, or a shell script that runs one)
    gh <group> delete / delete-asset / remove (not alias / extension:
           local config only)
    gh api with a writing method, including the POST that -f/-F/--field/
           --raw-field/--input imply without -X; graphql only for an inline
           query that is not a mutation and that the shell cannot change

Command names match the way the shell and file system find them: any case
(macOS file systems are case-insensitive), a glob, zsh =cmd, git's dashed
builtins (git-reset), and with an always-empty expansion glued on (${x}git).
Each command is also checked as if every unknown expansion were empty
(--ha$()rd is --hard).

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
The same class, found in the v1.69.0 review and filed as agentskel BL-013:
a variable or array holding a flag (`x=--hard; git reset $x`), a command
name from a variable (`${GIT:-git} reset --hard`), arguments read from stdin
(`... | xargs git push origin`, `parallel`), a shell function or alias
wrapping a command (`f(){ git reset "$@"; }; f --hard`), and interpreters
given list-form arguments (`python3 -c 'subprocess.run([...])'`).
The environment's own delete-safety check is a second layer underneath.
"""
import fnmatch
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
                       "--config-env", "--super-prefix", "--list-cmds", "--attr-source",
                       "--shallow-file"}
# What bash itself treats as special: ASCII blanks only (a non-breaking space
# is an ordinary character to bash, but \s in Python matches it).
SHELL_CHARS = re.compile(r"[ \t\n\r;&|()<>`$\\'\"\x00{!]")


class TooComplex(Exception):
    pass


class Reader:
    def __init__(self, text, depth=0, zsh=False):
        self.s = text
        self.zsh = zsh          # zsh closes ${ ... } at the first } (quotes do not protect it)
        self.heredocs = []      # (delimiter, strip_tabs) waiting for the end of the line
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

    def backtick(self):
        """At a backtick: bash takes the text up to the next UNESCAPED
        backtick (quotes do not protect a backtick), removes one backslash
        before \\, ` and $, and reads the result as commands (review: the
        old reading honoured quotes inside and kept `\\git` as a word)."""
        s = self.s
        j = self.i + 1
        while j < len(s) and s[j] != "`":
            j += 2 if s[j] == "\\" else 1
        body = re.sub(r"\\([\\`$])", r"\1", s[self.i + 1:min(j, len(s))])
        if j >= len(s):
            self.unterminated = True
        self.i = min(j + 1, len(s))
        if self.depth + 1 > MAX_DEPTH:
            raise TooComplex("nested too deep")
        inner = Reader(body, self.depth + 1, self.zsh)
        inner.parse()
        self.commands += inner.commands
        self.nesting += inner.nesting
        self.strings += inner.strings
        self.unterminated = self.unterminated or inner.unterminated

    def arithmetic_command(self):
        """At `((`: arithmetic up to the matching `))`, reading $( ), ${ }
        and backticks inside (review: read only as two subshells, a `#`
        inside became a comment that hid the rest of the line)."""
        self.i += 2
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
                self.backtick()
                continue
            if c == "(":
                level += 1
            elif c == ")":
                level -= 1
            self.i += 1
        if level:
            self.unterminated = True

    def heredoc_bodies(self):
        """After the line that opened them: skip each pending heredoc body
        and keep its text to read again as commands of its own (review: read
        as shell text of the outer command, a `${` or `'` in a body swallowed
        the real lines after it)."""
        s = self.s
        for delim, strip_tabs in self.heredocs:
            body = []
            while self.i < len(s):
                end = s.find("\n", self.i)
                line = s[self.i:] if end < 0 else s[self.i:end]
                self.i = len(s) if end < 0 else end + 1
                if (line.lstrip("\t") if strip_tabs else line) == delim:
                    break
                body.append(line)
            self.strings.append("\n".join(body))
        self.heredocs = []

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
                self.backtick()
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
                self.backtick()
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
            if c == "'" and not self.zsh:
                self.single_quoted()
                continue
            if c == '"' and not self.zsh:
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
                self.backtick()
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
            if c == "$" and self.simple_expansion():
                out.append(PLACEHOLDER)
                continue
            if c == "`":
                self.backtick()
                out.append(PLACEHOLDER)
                continue
            out.append(c)
            self.i += 1
        self.unterminated = True
        return "".join(out)

    def simple_expansion(self):
        """At `$`: consume $NAME, $1 or a special parameter and say so. Its
        value is unknown; a word built from it holds a PLACEHOLDER, and a
        command is also checked as if every such value were empty (review:
        `$x:main` is `:main`, `--ha${x}rd` is `--hard`)."""
        m = re.match(r"\$([A-Za-z_][A-Za-z0-9_]*|[0-9@*#?!$-])", self.s[self.i:self.i + 256])
        if not m:
            return False
        self.i += len(m.group(0))
        return True

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
                    if target in ("<<", "<<-"):
                        # a heredoc: its body follows the end of this line
                        self.heredocs.append((text, target == "<<-"))
                    else:
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
            if c in " \t":            # \r is an ordinary character to bash (review)
                end_word()
                self.i += 1
            elif c == "\n":
                end_command()
                self.i += 1
                if self.heredocs:
                    self.heredoc_bodies()
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
            elif c == "$" and self.simple_expansion():
                add(PLACEHOLDER)
            elif c == "(" and word is not None and word[-1][-1:] in ("@", "!", "*", "+", "?"):
                self.extglob(add)          # @(a|b) etc.: part of the word
            elif c == "`":
                self.backtick()
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
                target = m.group(0) if m.group(0) in ("<<", "<<-") else True
            elif c in ";&|":
                end_command()
                while self.i < len(s) and s[self.i] in ";&|":
                    self.i += 1
            elif c == "(" and nxt == "(" and word is None:
                # `((` / `for ((`: arithmetic to bash; read it that way AND
                # as two subshells (the older reading), keeping both.
                end_command()
                start, saved = self.i, self.unterminated
                self.i += 1
                self.nested(")")
                self.i, self.unterminated = start, saved
                self.arithmetic_command()
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
    if "${" in text:
        # zsh (the shell some agents run) closes ${ at the first } even
        # inside quotes; read that way too and keep both readings (review).
        z = Reader(text, depth, zsh=True)
        z.parse()
        commands = commands + z.commands
        strings = strings + z.strings
        top = top + [n == depth for n in z.nesting]
    if r.unterminated:
        # bash would refuse to run this; read it once more with the quotes
        # removed so flags inside the unclosed quote still count (fail safe).
        q = Reader(re.sub(r"[\"']", " ", text), depth)
        q.parse()
        commands = commands + q.commands
        strings = strings + q.strings
        top = top + [False] * len(q.commands)
    return commands, strings, top


def sequence(m):
    """The items of {a..b} / {a..b..step} (numbers or single letters), or None."""
    a, b, step = m.group(1), m.group(2), int(m.group(3) or 1) or 1
    if re.fullmatch(r"-?\d+", a) and re.fullmatch(r"-?\d+", b):
        lo, hi = int(a), int(b)
        rng = range(lo, hi + 1, abs(step)) if lo <= hi else range(lo, hi - 1, -abs(step))
        if len(rng) > BRACE_LIMIT:
            raise TooComplex("brace sequence too large")
        return [str(n) for n in rng]
    if len(a) == 1 and len(b) == 1:
        lo, hi = ord(a), ord(b)
        rng = range(lo, hi + 1, abs(step)) if lo <= hi else range(lo, hi - 1, -abs(step))
        return [chr(n) for n in rng]
    return None


def braces(word):
    """Brace expansion, in order: {-r,-f} -> ['-r', '-f'], {r,}m -> ['rm', 'm'],
    and sequences: --{d..d}elete -> ['--delete'] (review, v1.69.0)."""
    words = [word]
    while True:
        changed, out = False, []
        for w in words:
            m = re.search(r"\{([^{}]*,[^{}]*)\}", w)
            q = re.search(r"\{([^{}.]+)\.\.([^{}.]+)(?:\.\.(-?\d+))?\}", w)
            items = sequence(q) if q else None
            if m:
                changed = True
                out.extend(w[:m.start()] + part + w[m.end():] for part in m.group(1).split(","))
            elif items is not None:
                changed = True
                out.extend(w[:q.start()] + part + w[q.end():] for part in items)
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


GLOB_CHARS = re.compile(r"[*?\[]")


def is_cmd(word, target):
    """Is `word`, as a command word, the program `target`? Case-insensitive
    (macOS file systems: `GIT reset` runs git), a glob (`gi[t]`, `r?`), zsh's
    `=git`, and an empty expansion glued on (`${x}git`) all count (review)."""
    b = os.path.basename(word.replace(PLACEHOLDER, "")).lower()
    if b.startswith("="):
        b = b[1:]
    if b == target:
        return True
    return bool(GLOB_CHARS.search(b)) and fnmatch.fnmatchcase(target, b)


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
    prog = name(cmd[k]).lower()
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
TRUE_VALUES = {"", "1", "true", "yes", "on"}
FALSE_VALUES = {"0", "false", "no", "off"}


def git_push(args):
    """A reason to block, "DELETE" for a remote branch delete, or None.
    Long options count from a 1-letter prefix: git accepts any unique prefix
    (`--m` is --mirror), and an ambiguous one is refused by git anyway."""
    opts, pos, rest = split_args(args, PUSH_VALUES, "o")
    refs = pos + rest
    delete = False
    for a in opts:
        if (is_long(a, "force", 1) or is_long(a, "force-with-lease", 1)
                or "f" in letters(a, "o")):
            return "force push (--force / -f / --force-with-lease) — overwrites remote history"
        if is_long(a, "mirror", 1):
            return "git push --mirror — deletes remote branches that are not local"
        if is_long(a, "prune", 2):
            return "git push --prune — deletes remote branches that are not local"
        if is_long(a, "delete", 1) or "d" in letters(a, "o"):
            delete = True
    for r in refs:
        if r.startswith("+") and not r.startswith("+:"):
            return "force push of a +refspec — overwrites remote history"
        if (r.startswith(":") and len(r) > 1) or (r.startswith("+:") and len(r) > 2):
            delete = True       # `:` alone pushes matching branches
    return "DELETE" if delete else None


def git_reset(args):
    if any(is_long(a, "hard", 1) for a in args):
        return "hard reset (git reset --hard) — discards uncommitted work"
    return None


CHECKOUT_PATH_ONLY = ("ours", "theirs", "conflict", "patch", "pathspec-from-file")


def looks_like_path(p, cwd):
    """A checkout argument that is a path, not a branch: . .. ./x ../x :/x
    :(magic)x, a glob, or a file or folder that exists in the session folder."""
    if p in (".", "..", "*") or p.startswith(("./", "../", ":/", ":(")) or GLOB_CHARS.search(p):
        return True
    return bool(p) and bool(cwd) and os.path.lexists(os.path.join(cwd, p))


def git_checkout(args, cwd=""):
    opts, pos, rest = split_args(args, {"orphan"}, "bB")
    if any(is_long(a, "force", 1) or "f" in letters(a, "bB") for a in opts):
        return "git checkout --force / -f — discards uncommitted changes"
    path_mode = any(any(is_long(a, o, 2) for o in CHECKOUT_PATH_ONLY) for a in opts) or any(
        "p" in letters(a, "bB") for a in opts)
    creates = any(a in ("-b", "-B") or is_long(a, "orphan", 2) or letters(a, "bB")[-1:] in (["b"], ["B"])
                  for a in opts)
    if (rest or len(pos) >= 2 or (pos and path_mode)
            or (len(pos) == 1 and not creates and looks_like_path(pos[0], cwd))):
        return "git checkout <paths> — overwrites uncommitted changes in those files"
    return None


def git_switch(args):
    opts, _, _ = split_args(args, {"create", "force-create", "orphan"}, "cC")
    for a in opts:
        if is_long(a, "force", 1) and not is_long(a, "force-create", 7) or "f" in letters(a, "cC"):
            return "git switch --force / -f — discards uncommitted changes"
        if is_long(a, "discard-changes", 2):
            return "git switch --discard-changes — discards uncommitted changes"
    return None


def git_restore(args):
    """Any restore that touches the working tree. `--staged` alone only
    unstages (what `git status` suggests), so it is allowed."""
    opts, _, _ = split_args(args, {"source"}, "s")
    staged = any(is_long(a, "staged", 2) or "S" in letters(a, "s") for a in opts)
    worktree = any(is_long(a, "worktree", 1) or "W" in letters(a, "s") for a in opts)
    if staged and not worktree:
        return None
    return "git restore — discards uncommitted changes (modern 'checkout -- <file>')"


def git_clean(args):
    opts, _, _ = split_args(args, {"exclude"}, "e")
    if any(is_long(a, "force", 1) or "f" in letters(a, "e") for a in opts):
        return "git clean force (-f / --force) — removes untracked files, cannot be undone"
    return None


def git_worktree(args):
    if args[:1] == ["remove"] and any(is_long(a, "force", 1) or "f" in letters(a) for a in args[1:]):
        return "git worktree remove force (--force / -f) — discards uncommitted worktree changes"
    return None


def git_stash(args):
    if args[:1] in (["drop"], ["clear"]):
        return "git stash drop/clear — discards stashed work"
    return None


def git_branch_move(args):
    opts, _, _ = split_args(args)
    forced = any(is_long(a, "force", 1) or "f" in letters(a) for a in opts)
    for a in opts:
        ls = letters(a)
        if "M" in ls or "C" in ls:
            return "git branch -M / -C — overwrites an existing branch"
        if forced and ("m" in ls or "c" in ls or is_long(a, "move", 1) or is_long(a, "copy", 1)):
            return "git branch --move/--copy --force — overwrites an existing branch"
    return None


def git_update_ref(args):
    if any(a == "-d" or is_long(a, "delete", 1) for a in args):
        return "git update-ref -d — deletes a ref (a branch, the stash) without any check"
    return None


def git_read_tree(args):
    if any(is_long(a, "reset", 1) for a in args) and any(a == "-u" or "u" in letters(a) for a in args):
        return "git read-tree --reset -u — overwrites the working tree (like reset --hard)"
    return None


def git_checkout_index(args):
    if any(is_long(a, "force", 1) or "f" in letters(a) for a in args):
        return "git checkout-index --force — overwrites files in the working tree"
    return None


def git_send_pack(args):
    if any(is_long(a, "force", 1) or "f" in letters(a) for a in args) or any(
            a.startswith("+") for a in args if not a.startswith("-")):
        return "git send-pack --force — overwrites remote history"
    return None


def git_reflog(args):
    if args[:1] in (["delete"], ["expire"]):
        return "git reflog delete/expire — removes the history that recovers lost work"
    return None


def git_submodule(args):
    if args[:1] in (["update"], ["deinit"]) and any(is_long(a, "force", 1) or "f" in letters(a) for a in args[1:]):
        return "git submodule update/deinit --force — discards changes in submodules"
    return None


GIT_RULES = {"push": git_push, "reset": git_reset, "switch": git_switch, "restore": git_restore,
             "clean": git_clean, "worktree": git_worktree, "stash": git_stash, "branch": git_branch_move,
             "update-ref": git_update_ref, "read-tree": git_read_tree,
             "checkout-index": git_checkout_index, "send-pack": git_send_pack,
             "reflog": git_reflog, "submodule": git_submodule}


def config_danger(key, value):
    """A config setting that makes a plain git command destructive."""
    key, value = key.strip().lower(), value.strip().lower()
    if re.fullmatch(r"remote\..+\.mirror", key) and value not in FALSE_VALUES:
        return f"git config {key}={value} — a plain push then mirrors (deletes remote branches)"
    if re.fullmatch(r"remote\..+\.push", key) and value.startswith("+"):
        return f"git config {key}={value} — a plain push then force-pushes"
    if key == "clean.requireforce" and value in FALSE_VALUES:
        return "git config clean.requireForce=false — git clean then deletes without -f"
    return None


def git_globals(cmd, i, j):
    """(key, value) config pairs set for this git invocation: -c k=v,
    --config-env=k=ENV (value unknown), and GIT_CONFIG_KEY_n / VALUE_n
    environment words before git."""
    pairs = []
    k = i + 1
    while k < j:
        w = cmd[k]
        if w == "-c" and k + 1 < j:
            key, _, val = cmd[k + 1].partition("=")
            pairs.append((key, val))
            k += 2
            continue
        if w.startswith("-c") and len(w) > 2:
            key, _, val = w[2:].partition("=")
            pairs.append((key, val))
        if w.startswith("--config-env"):
            spec = w.split("=", 1)[1] if "=" in w else (cmd[k + 1] if k + 1 < j else "")
            key = spec.rsplit("=", 1)[0]
            pairs.append((key, "\x01"))         # value from the environment: unknown
        k += 1
    env = {w.split("=", 1)[0]: w.split("=", 1)[1] for w in cmd[:i] if re.match(r"^[A-Z_][A-Z0-9_]*=", w)}
    for name_, key in env.items():
        m = re.fullmatch(r"GIT_CONFIG_KEY_(\d+)", name_)
        if m:
            pairs.append((key, env.get(f"GIT_CONFIG_VALUE_{m.group(1)}", "\x01")))
    params = env.get("GIT_CONFIG_PARAMETERS", "")
    for key, val in re.findall(r"'?([A-Za-z0-9._-]+\.[A-Za-z0-9._-]+)=([^']*)'?", params):
        pairs.append((key, val))
    return pairs


def git_destructive(cmd, i, aliases, cwd="", depth=0):
    """A reason to block, "DELETE", or None, for the git at cmd[i]."""
    j = git_subcommand(cmd, i)
    pairs = git_globals(cmd, i, min(j, len(cmd)))
    local_aliases = dict(aliases)
    for key, val in pairs:
        found = config_danger(key, val) if val != "\x01" else None
        if found:
            return found
        if key.lower().startswith("alias."):
            local_aliases[key[6:]] = val
    if j >= len(cmd):
        return None
    sub, args = cmd[j], cmd[j + 1:]
    if sub in local_aliases and depth < 3:
        val = local_aliases[sub]
        if val == "\x01" or val.startswith("!"):
            return "a git alias defined in this command that runs a shell or an unseen value — run the command itself"
        expanded = cmd[:j] + val.split() + args
        if git_branch_force_delete(expanded, i):
            return "force branch delete through a git alias — discards unmerged work"
        return git_destructive(expanded, i, {}, cwd, depth + 1)
    if sub == "config":
        return git_config(args)
    if sub == "checkout":
        return git_checkout(args, cwd)
    rule = GIT_RULES.get(sub)
    return rule(args) if rule else None


def git_config(args):
    """`git config` that stores a destructive alias or setting, used by a
    later command this hook will not see as such."""
    opts, pos, _ = split_args(args, {"file", "blob", "type", "default", "comment"}, "f")
    pos = [p for p in pos if p not in ("set", "--add")]
    if len(pos) >= 2:
        key, value = pos[0], pos[1]
    elif len(pos) == 1 and "=" in pos[0]:
        key, value = pos[0].split("=", 1)
    else:
        return None
    found = config_danger(key, value)
    if found:
        return found
    if key.lower().startswith("alias."):
        if value.startswith("!"):
            return f"git config {key} — stores a shell alias; run the command itself"
        inner = ["git"] + value.split()
        found = git_destructive(inner, 0, {}, "", 3)
        if found or git_branch_force_delete(inner, 0):
            return f"git config {key} — stores an alias for a destructive git command"
    return None


REMOVERS = {"rm", "unlink", "shred", "srm"}
SHELLS = {"sh", "bash", "zsh", "dash", "ksh", "fish", "busybox"}


def runs_remover(words, depth=0):
    """Do `words` (what -exec / fd -x runs) start a remover, after any
    wrappers? For a shell (`sh -c '...'`), does its script run one?"""
    k = 0
    while k < len(words) and (name(words[k]) in WRAPPERS or re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", words[k])):
        k += 1
    if k >= len(words):
        return False
    if any(is_cmd(words[k], t) for t in REMOVERS):
        return True
    if any(is_cmd(words[k], t) for t in SHELLS) and depth < 3:
        script = next((words[n + 1] for n in range(k + 1, len(words) - 1) if words[n] == "-c"), None)
        if script is None:
            return True             # a shell reading commands from elsewhere
        inner = Reader(script.replace(PLACEHOLDER, " "))
        inner.parse()
        return any(runs_remover(c, depth + 1) for c in inner.commands)
    return False


def find_destructive(args):
    for k, a in enumerate(args):
        if a == "-delete":
            return True
        if a in ("-exec", "-execdir", "-ok", "-okdir") and runs_remover(args[k + 1:]):
            return True
    return False


def fd_destructive(args):
    for k, a in enumerate(args):
        if a in ("-x", "-X", "--exec", "--exec-batch") and runs_remover(args[k + 1:]):
            return True
        if (a.startswith("--exec=") or a.startswith("--exec-batch=")) and runs_remover([a.split("=", 1)[1]]):
            return True
    return False


GH_API_LONG_VALUE_OPTS = {"--method", "--raw-field", "--field", "--header", "--input", "--jq",
                          "--template", "--cache", "--hostname", "--preview"}
GH_API_SHORT_VALUE = "XfFHqtp"    # short flags that take a value
GH_SHORT_TO_LONG = {"X": "-X", "f": "-f", "F": "-F", "H": "-H", "q": "-q", "t": "-t", "p": "-p"}
READ_METHODS = {"GET", "HEAD"}
GRAPHQL_VAR_DECL = re.compile(r"\$([A-Za-z_][A-Za-z0-9_]*)\s*:")
# A $ reference as bash reads it: a name, one digit, or one special parameter.
DOLLAR_REF = re.compile(r"\$([A-Za-z_][A-Za-z0-9_]*|[0-9@*#?!$-])")
GH_DELETE_ACTIONS = {"delete", "delete-asset", "remove"}
GH_HARMLESS_GROUPS = {"alias", "extension"}     # local gh config only


def gh_subcommand(cmd, i):
    """Index of gh's first non-flag word (gh's own flags come first)."""
    k = i + 1
    while k < len(cmd) and cmd[k].startswith("-"):
        k += 1
    return k


def gh_check(cmd, i, raw):
    """A reason to block a gh command, or None. `raw`: (expansions, globs)
    of the raw command text."""
    k = gh_subcommand(cmd, i)
    if k >= len(cmd):
        return None
    group = cmd[k]
    if group != "api":
        rest = [w for w in cmd[k + 1:] if not w.startswith("-")]
        if rest and rest[0] in GH_DELETE_ACTIONS and group not in GH_HARMLESS_GROUPS:
            return f"gh {group} {rest[0]} — deletes on GitHub"
        return None
    return gh_api(cmd, k, raw)


def gh_api(cmd, a_idx, raw):
    expansions, globs = raw
    method, fields, has_input, endpoint = None, [], False, None
    k = a_idx + 1
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
            # --include plus -X DELETE; -X=DELETE is -X DELETE.
            opt, val, step = a, None, 1
            for pos_, ch in enumerate(a[1:], start=1):
                if ch in GH_API_SHORT_VALUE:
                    opt = GH_SHORT_TO_LONG[ch]
                    if pos_ + 1 < len(a):
                        val = a[pos_ + 1:]
                        if val.startswith("="):
                            val = val[1:]
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
            method = (val or "").strip()
        elif opt in ("-f", "--raw-field"):
            fields.append(("raw", val or ""))
        elif opt in ("-F", "--field"):
            fields.append(("typed", val or ""))
        elif opt == "--input":
            has_input = True
    if endpoint is not None and endpoint.lstrip("/").lower() == "graphql":
        if has_input:
            return "gh api graphql --input — the hook cannot see the query (it may be a mutation)"
        queries = [(kind, v.split("=", 1)[1]) for kind, v in fields if v.split("=", 1)[0] == "query" and "=" in v]
        if not queries:
            return "gh api graphql with no inline query — the hook cannot see what runs"
        for kind, q in queries:
            if kind == "typed" and q.startswith("@"):
                return "gh api graphql -F query=@file — the hook cannot see the query (it may be a mutation)"
            if PLACEHOLDER in q:
                return "gh api graphql query built by a shell expansion — the hook cannot see the final query"
            if re.search(r"\bmutation\b", q):
                return "gh api graphql mutation — writes to GitHub"
            if globs:
                return "gh api graphql with an unquoted glob in the command — the shell may rewrite the query"
            # A GraphQL $variable in single quotes is literal; one bash would
            # expand, or one the query does not declare, is not.
            refs = set(DOLLAR_REF.findall(q))
            if refs & expansions or refs - set(GRAPHQL_VAR_DECL.findall(q)):
                return "gh api graphql query with a $ the shell may expand — the hook cannot see the final query"
        return None
    if method is not None:
        if method.upper() not in READ_METHODS:
            # Anything but a literal GET / HEAD: a write, or a method the
            # hook cannot see ("$M", $(...)). Fail closed (review).
            return (f"gh api -X {method.replace(PLACEHOLDER, '<expansion>') or '?'} — only a literal GET or "
                    "HEAD is a read; this can delete repos or post content")
        return None
    if fields or has_input:
        return "gh api POST — -f/-F/--field/--raw-field/--input imply POST without -X"
    return None


def shell_scan(text):
    """(expansions, globs) of the raw command: the $ references bash expands
    (outside single quotes, not escaped) and whether an unquoted glob
    character (* ? [) appears."""
    found, globs = set(), False
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
        elif c in "*?[" and not double:
            globs = True
        i += 1
    return found, globs


def collect_aliases(commands):
    """git aliases this text defines: -c alias.x=v / git config alias.x v
    (and alias.x=v) anywhere in it; their invocations are checked as git."""
    aliases = {}
    for cmd in commands:
        for k, w in enumerate(cmd):
            m = re.match(r"^(?:-c)?alias\.([^=\s]+)=(.*)\Z", w, re.S)
            if m:
                aliases[m.group(1)] = m.group(2)
            elif re.match(r"^alias\.[^=\s]+\Z", w) and k + 1 < len(cmd) and "config" in cmd[:k]:
                aliases[w[6:]] = cmd[k + 1]
    return aliases


def git_names(words):
    """Indexes of words that run git: `git`, a path to it, a glob that
    matches it, or a dashed builtin (`git-reset`, `$(git --exec-path)/git-reset`)."""
    return [k for k, w in enumerate(words) if is_cmd(w, "git")]


def dashed(words):
    """Rewrite a dashed builtin word (git-reset) to `git reset`."""
    out = []
    for w in words:
        b = os.path.basename(w.replace(PLACEHOLDER, "")).lower()
        m = re.fullmatch(r"git-([a-z][a-z-]*)", b)
        if m and m.group(1) not in ("lfs", "credential", "upload-pack", "receive-pack", "shell"):
            out += ["git", m.group(1)]
        else:
            out.append(w)
    return out


def check_words(words, top, raw, aliases, cwd):
    rms = [i for i, w in enumerate(words) if is_cmd(w, "rm")]
    if len(rms) > MAX_RM_WORDS:
        raise TooComplex("too many rm words")
    for i in rms:           # every rm: `env -u rm -- rm -rf y` runs the second
        if rm_forced_recursive(words[i + 1:]):
            return "BLOCK recursive force delete (rm with recursive + force flags) — cannot be undone"
    delete = False
    for i in git_names(words):
        if git_branch_force_delete(words, i):
            return "BLOCK force branch delete (git branch delete + force, any spelling) — discards unmerged work"
        found = git_destructive(words, i, aliases, cwd)
        if found == "DELETE":
            if not top:
                return ("BLOCK-REMOTE remote branch delete inside $( ), backticks, ( ), bash -c, eval or"
                        " similar — nothing can ask about a command it cannot see; run it as a plain command")
            delete = True
        elif found:
            return "BLOCK " + found
    for i, w in enumerate(words):
        if is_cmd(w, "find") and find_destructive(words[i + 1:]):
            return "BLOCK find with -delete / -exec rm — bulk delete"
        if (is_cmd(w, "fd") or is_cmd(w, "fdfind")) and fd_destructive(words[i + 1:]):
            return "BLOCK fd --exec rm — bulk delete"
        if is_cmd(w, "gh"):
            found = gh_check(words, i, raw)
            if found:
                return "BLOCK " + found
    return "DELETE" if delete else None


def check_command(cmd, top=False, raw=(frozenset(), False), aliases=None, cwd=""):
    """A "BLOCK <reason>" / "BLOCK-REMOTE <reason>" for `cmd`, "DELETE" for
    a top-level remote branch delete (the hook's own verdict decides it), or
    None. The command is checked as written AND as if every expansion whose
    value is unknown were empty (bash drops an empty unquoted word, and glues
    an empty one into its neighbours: `$x:main` is `:main`)."""
    aliases = aliases or {}
    words = dashed(expand(cmd))     # {rm,-rf,y} and {r,}m are commands too
    variants = [words]
    empty = [w.replace(PLACEHOLDER, "") for w in words]
    empty = [w for w in empty if w != ""]
    if empty != words:
        variants.append(dashed(expand(empty)))
    result = None
    for v in variants:
        found = check_words(v, top, raw, aliases, cwd)
        if found and found != "DELETE":
            return found
        result = result or found
    return result


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


SESSION_CWD = ""            # from the hook (SAFETY_CWD): where relative paths point
_PERSISTED = None


def persisted_aliases():
    """git aliases already stored in the session's repo config: `git x` may
    be one (an alias stored by an earlier command runs here)."""
    global _PERSISTED
    if _PERSISTED is None:
        _PERSISTED = {}
        try:
            import subprocess
            out = subprocess.run(["git", "-C", SESSION_CWD or os.getcwd(), "config", "--get-regexp", r"^alias\."],
                                 capture_output=True, text=True, timeout=2).stdout
            for line in out.splitlines():
                key, _, val = line.partition(" ")
                _PERSISTED[key[6:]] = val
        except Exception:
            pass
    return _PERSISTED


def verdict(text, depth=0):
    commands, strings, top = read(text, depth)
    raw = shell_scan(text)
    aliases = dict(persisted_aliases()) if any(is_cmd(w, "git") for c in commands for w in c) else {}
    aliases.update(collect_aliases(commands))
    deletes = 0
    for cmd, is_top in zip(commands, top):
        found = check_command(cmd, top=is_top and depth == 0, raw=raw, aliases=aliases, cwd=SESSION_CWD)
        if found == "DELETE":
            deletes += 1
        elif found:
            return found
    # A definition (function, alias, git alias) can make grep / git / gh
    # mean anything: no search-pattern or message exemptions then.
    definitions = bool(DEFINITION.search(text)) or bool(collect_aliases(commands)) or "alias." in text
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
        k = next((n for n, w in enumerate(cmd) if is_cmd(w, "gh")), None)
        if k is not None and cmd[k + 1:k + 3] == ["alias", "set"] and len(cmd) > k + 4:
            again.append("gh " + cmd[k + 4])      # gh alias set NAME 'api -X DELETE ...'
    # zsh glob qualifiers run code: *(e:'cmd':) / /tmp(e:'cmd':)
    for m in re.finditer(r"\(e([:'\"/|!+])(.*?)\1\)", text, re.S):
        again.append(m.group(2))
    if again and depth >= REREAD_DEPTH:
        # Out of depth with text still to read: do not guess. The hook then
        # blocks any destructive word in the command (fail closed).
        raise TooComplex("quoted text nested too deep")
    for text_again in again:
        text_again = text_again.replace(PLACEHOLDER, " ")
        if text_again == text:
            continue        # reading it again would only repeat this level
        found = verdict(text_again, depth + 1)
        if not found.startswith("ALLOW"):
            return found
    return f"ALLOW DELETE {deletes}" if deletes else "ALLOW"

def on_timeout(signum, frame):
    raise TooComplex("took too long")


if __name__ == "__main__":
    SESSION_CWD = os.environ.get("SAFETY_CWD", "")
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
