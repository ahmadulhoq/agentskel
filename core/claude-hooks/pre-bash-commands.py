#!/usr/bin/env python3
"""Per-command checks for pre-bash-safety.sh: recursive force rm, force
branch delete, and (2026-11-03) the other git rules: force push (-f, --force,
--force-with-lease, a +refspec), remote deletes (push --mirror / --prune, a
-d / --delete the hook's merged-branch check cannot read, :branch; no
override), clean -f, worktree remove -f, checkout -f, checkout of paths from a
commit (`checkout <commit> [--] <path>`, or one name only a path can have),
switch -f / --discard-changes, reset --hard, checkout-index -f, read-tree
--reset -u, send-pack (:branch / --force / +refspec), update-ref -d, branch
move/copy force (-M / -C), and stash drop/clear. Also configuration given to
the one command (`-c`, `--config-env`, GIT_CONFIG_*: remote.<name>.mirror /
.push, clean.requireForce, non-`!` aliases), `git config [set] ...` writing the
same for the next plain command, and git under another name (git-push, gi[t],
or behind a wrapper such as setsid / sudo / timeout).

agentskel v1.69.0: this is MCU-Watchlist's reader as of PR #179 (main
6aed1746), with agentskel's own v1.69.0 rules ported in, each with its
cases in pre-bash-safety.test.sh:
- find -delete / -exec|-execdir|-ok|-okdir <remover>, fd -x/-X <remover>
  (also through env / command / sh -c), and gh: api with a writing method,
  with fields or --input (an implied POST), graphql unless an inline query
  that is not a mutation; `gh <group> delete|delete-asset|remove` except
  alias / extension (local gh config); `gh alias set` text is read again.
- Command names: any case (`GIT`, `RM`: macOS file systems ignore case),
  zsh's `=git`, an expansion glued in front (`${x}git`), {a..b} sequences,
  zsh glob qualifiers that run code (`*(e:'cmd':)`), `\\r` as an ordinary
  character, backtick bodies also read de-escaped (`\\\\git`), a subcommand
  or action with an empty substitution inside (`re$()set`, `dr$()op`).
- git restore unless `--staged` alone; reflog delete / expire; submodule
  update / deinit --force; checkout --ours / --theirs / --conflict / --patch
  <path> (owner, 2026-11-17: MCU-Watchlist allows it), and a lone name that is
  a file and not a branch; branch -M / -C only when the target branch exists
  or cannot be checked (owner, 2026-11-17); `:` alone is a matching push.
- Aliases defined by any command in the line (`git config alias.x reset &&
  git x --hard`) or stored in the repo's config, a `!` alias read with the
  arguments git hands it, and GIT_CONFIG_PARAMETERS's older 'key=value' form.
- A plain remote delete is counted for the hook's ask only as a top-level
  command; inside $( ), backticks, ( ), bash -c, eval or quoted text it is
  BLOCK-REMOTE (MCU-Watchlist asks for one in quoted text).

Not seen (no static check can): settings already in a config file other than
aliases (`remote.origin.mirror`), and anything exported in an earlier command
(`export GIT_CONFIG_COUNT=…`).

The command arrives on stdin (heredoc bodies already removed, commit messages
NOT removed: a `$( )` inside a message runs). Prints one line:
    BLOCK-REMOTE <reason>    a remote branch delete: AGENTSKEL_UNSAFE does not apply
    BLOCK <reason>           the override applies
    ASK-DELETE <n>           n plain `git push <remote> --delete <branch>`
                             commands and nothing else: the hook's merged-branch
                             check must read exactly n, or it blocks
    ALLOW
    CRASH [GIT] [RM]         gave up (too complex, too slow); GIT / RM: the
                             text names git / rm once $'...' escapes are decoded
Anything else (a timeout, missing python) makes the hook fall back to blocking
every rm and every git command these rules cover: fail closed.

Where something bash may pass is not known from the text (a variable, a
$( ), a glob), the reader assumes the dangerous reading but the block can be
overridden: `git push origin "$SRC:$DST"` deletes the branch when SRC is
empty (owner, 2026-11-03: blocked, overridable); `-u$x` may hide -d. A
literal :branch, --mirror or --prune is never overridable.

The git rules read only the words of that one git command, up to `--`
(git_options). Until 2026-11-03 they were regexes whose `.*` ran to the end of
the line: `git push origin x && tail -f log` was a force push and `git clean
-n docs/foo-file` a forced clean, while `git push -uf`, a quoted "-f",
`--forc`, `+main`, `git --no-pager push -f` and `git switch -f` got through.
main's patterns stay in the hook as a floor, narrowed to one command.

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

Read since 2026-11-09 (owner: "Fix the gaps"): what the text itself says. A
$( ) or ` ` that is one echo or printf of plain words is replaced by what it
prints, and a variable given a plain value earlier in the command (NAME=value,
export / declare / local / readonly / typeset, `for NAME in words`) by that
value; the command is then read again (`rm -r $(echo -f) x`, `x=-f; rm -r $x
y` are recursive force deletes, and so is `x=rm; $x -rf y`). A value that is
not written out stays unknown, so `rm -f "$f"` and `rm -f $(git ls-files -d)`
are not refused.

Not seen (no static check can): a command name or flags built at run time
(`$(which rm) -rf x`, `bash -c 'rm -r "$@"' _ -f x`). This
includes a flag assembled from the OUTPUT of a substitution or from word
splitting, e.g. `rm $(echo x-rf | cut -c2-) y` or `IFS=a; rm $(echo a-rf) y`:
the `-rf` does not exist in the command text, only after bash runs it. main's
coarse substring rule blocks some of these by accident (it also blocks real
hyphenated filenames, which is the bug this PR fixes); allowing the filenames
necessarily allows these, so they are an accepted limit (owner, 2026-11-03).
Also not seen (agentskel BL-013, documented): a command name from a variable
(`${GIT:-git} reset --hard`, `$(command -v git) ...`), an array (`git
"${x[@]}"`), arguments read from stdin (`xargs`, `parallel`), a shell function
or shell alias wrapping a command, and interpreters (`python3 -c
'subprocess.run([...])'`). Since MCU-Watchlist #179 a flag written in a
variable or an echo in the same command IS seen (`x=--hard; git reset $x`).
The environment's own delete-safety check is a second layer underneath.
"""
import fnmatch
import shlex
import os
import re
import signal
import sys

PLACEHOLDER = "\x00"
MAX_DEPTH = 40          # nesting of $( ) / backticks / ( ) before giving up
REREAD_DEPTH = 6        # quoted text inside quoted text inside ...
BRACE_LIMIT = 256       # expansions per word before giving up
TIME_LIMIT = 8          # seconds; then CRASH, and the hook blocks rm and the git commands checked here
WRAPPERS = {"sudo", "doas", "env", "command", "builtin", "exec", "nohup", "nice",
            "time", "timeout", "stdbuf", "xargs", "!",
            # other programs that run the command named after them, so a git
            # helper behind one still counts (second review of PR #167)
            "setsid", "flock", "chrt", "ionice", "taskset", "proxychains",
            "proxychains4", "catchsegv", "unbuffer"}
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
        self.known = []         # (start, end, printed text, inside "...") of a $( ) / ` `
        self.refs = []          # (start, end, variable, inside "...", depth) of a $NAME / ${NAME}
        self.cmd_spans = []     # (start, depth, words) of every simple command, in order
        self._cstart = None     # where the current command's first word began

    def peek(self, k=0):
        j = self.i + k
        return self.s[j] if j < len(self.s) else ""

    def nested(self, stop):
        self.depth += 1
        if self.depth > MAX_DEPTH:
            raise TooComplex("nested too deep")
        self.parse(stop)
        self.depth -= 1

    def substitution(self, start, stop, quoted):
        """Read a $( ) or ` ` body (self.i just past its opener). When the body
        is one echo or printf of plain words, note what it prints, so verdict()
        can read the command again with that text in its place (2026-11-09)."""
        n0, s0, u0 = len(self.commands), len(self.strings), self.unterminated
        self.nested(stop)
        if len(self.commands) == n0 + 1 and len(self.strings) == s0 and self.unterminated == u0:
            out = printed(self.commands[n0])
            if out is not None:
                self.known.append((start, self.i, out, quoted))
        if stop == "`" and "\\" in self.s[start + 1:self.i]:
            self.backtick_again(start)

    def backtick_again(self, start):
        """Inside backticks bash removes one backslash before \\, ` and $ and
        then reads the body: `\\git push` runs git (agentskel v1.69.0 review).
        Read that de-escaped body too, as commands of their own; reading it
        both ways only adds blocks."""
        body = re.sub(r"\\([\\`$])", r"\1", self.s[start + 1:max(start + 1, self.i - 1)])
        if self.depth + 1 > MAX_DEPTH:
            raise TooComplex("nested too deep")
        inner = Reader(body, self.depth + 1)
        inner.parse()
        self.commands += inner.commands
        self.strings += inner.strings
        self.cmd_spans += [(start, self.depth + 1, c, False) for c in inner.commands]
        self.unterminated = self.unterminated or inner.unterminated

    def variable(self, quoted):
        """At `$` + a name: note where $NAME stands and return it."""
        m = re.match(r"\$([A-Za-z_][A-Za-z0-9_]*)", self.s[self.i:])
        self.refs.append((self.i, self.i + m.end(), m.group(1), quoted, self.depth))
        self.i += m.end()
        return m.group(0)

    def braced(self, quoted):
        """At `${`: parameter_text(), noting a plain ${NAME}."""
        start = self.i
        text = self.parameter_text()
        m = re.fullmatch(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", self.s[start:self.i])
        if m:
            self.refs.append((start, self.i, m.group(1), quoted, self.depth))
        return text

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

    def parameter_text(self):
        """At `${`: what the word holds there. A placeholder (the value is not
        known), followed by the fallback word of ${x:-W} / ${x-W} / ${x:=W} /
        ${x:+W} and friends (x may be an array element or $1, $@ ...): bash
        uses W when x is unset or empty, so `git push origin ${x:--f}` reads
        as -f (reviews of PR #167). W is read as bash reads it: quotes,
        backslashes, $'...' and a nested ${y:-W2} all decoded. bare() drops the
        placeholder when it checks for an option."""
        start = self.i
        self.parameter()
        m = re.match(r"\$\{(?:[A-Za-z_][A-Za-z0-9_]*(?:\[[^\]]*\])?|[0-9@*#?$!-])(:?[-=+])(.*)\}\Z",
                     self.s[start:self.i], re.S)
        if not m:
            return PLACEHOLDER
        if self.depth + 1 > MAX_DEPTH:
            raise TooComplex("nested too deep")
        raw = m.group(2)
        fallback = Reader(raw, self.depth + 1)
        fallback.parse()
        # Every word of the fallback, across ALL its sub-commands: after
        # unquoted expansion a newline (and `;` / `&`, which parse() also ends a
        # command on) is just IFS whitespace that bash word-splits, so a flag
        # after a newline must still be seen — `git push origin${x:- main
        # <nl>--delete}` deletes main (fourth review of PR #167). Joining with
        # spaces over-blocks a literal `;`/`&` in a default, which is fail-safe.
        text = " ".join(w for cmd in fallback.commands for w in cmd)
        # A leading/trailing IFS space in the fallback is a word boundary bash
        # splits on (`git reset${x:- --hard}` runs `git reset --hard`): keep it
        # so parse() breaks the word there (third review of PR #167).
        if raw[:1].isspace():
            text = " " + text
        if text and raw[-1:].isspace():
            text = text + " "
        return PLACEHOLDER + text

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
                    start = self.i
                    self.i += 2
                    self.substitution(start, ")", True)
                out.append(PLACEHOLDER)
                continue
            if c == "$" and self.peek(1) == "{":
                out.append(self.braced(True))
                continue
            if c == "$" and re.match(r"[A-Za-z_]", self.peek(1)):
                out.append(self.variable(True))
                continue
            if c == "`":
                start = self.i
                self.i += 1
                self.substitution(start, "`", True)
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
        piped = False           # the pending command was reached through a `|`
        guard = False           # the pending command was reached through `&&` / `||`
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
                self.cmd_spans.append((self._cstart if self._cstart is not None else 0,
                                       self.depth, cmd, guard))
            cmd = []
            self._cstart = None

        def add(text):
            nonlocal word
            if word is None:
                word = []
            word.append(text)

        while self.i < len(s):
            c = s[self.i]
            nxt = self.peek(1)
            if word is None and not cmd and self._cstart is None and c not in " \t\n;&|#()":
                self._cstart = self.i      # first word of a new simple command
            if stop and s.startswith(stop, self.i):
                if (stop == ")" and word is not None and not cmd and not piped
                        and "".join(word) == "esac"):
                    # `esac)`: esac closes the case, so this `)` closes the $( )
                    # (2026-11-09: it was read as one more pattern, and the rest
                    # of the line as part of the substitution). `not piped`: a
                    # pattern word `esac` after a `|` the reader took for a pipe
                    # (`case esac in a|esac) ...`) is not the closing keyword —
                    # `cmd | esac` is a bash syntax error, so a real closer never
                    # follows a pipe (second review of the gap fix, 2026-11-10).
                    end_word()
                if stop == ")" and (cases or (cmd and cmd[0] == "case") or
                                    (word is not None and cmd and cmd[0] == "case")):
                    # a case pattern's `)`, not the end of $( ) (third review)
                    end_command()
                    self.i += 1
                    continue
                self.i += len(stop)
                end_command()
                return
            if c in " \t":            # \r is an ordinary character to bash (agentskel review)
                end_word()
                self.i += 1
            elif c == "\n":
                end_command()
                piped = False
                guard = False
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
                    start = self.i
                    self.i += 2
                    self.substitution(start, ")", False)
                add(PLACEHOLDER)
            elif c == "$" and nxt == "{":
                # Unquoted, bash word-splits the result, so the fallback of
                # ${x:-main -f} becomes two words and the -f is an option
                # (second review of PR #167). Inside double quotes it stays one
                # word (double_quoted keeps parameter_text joined).
                first = True
                for piece in self.braced(False).split(" "):
                    if not first:
                        end_word()          # the space is a word boundary
                    if piece:
                        add(piece)
                    first = False
            elif c == "$" and nxt == "[":
                self.old_arithmetic()      # $[ ... ]: one word (fourth review)
                add(PLACEHOLDER)
            elif c == "$" and re.match(r"[A-Za-z_]", nxt):
                add(self.variable(False))
            elif c == "(" and word is not None and word[-1][-1:] in ("@", "!", "*", "+", "?"):
                self.extglob(add)          # @(a|b) etc.: part of the word
            elif c == "`":
                start = self.i
                self.i += 1
                self.substitution(start, "`", False)
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
                piped = False
                run = ""
                while self.i < len(s) and s[self.i] in ";&|":
                    run += s[self.i]
                    if s[self.i] == "|":
                        piped = True
                    self.i += 1
                # `&&` / `||` guard the next command (it may not run); a plain
                # `;`, `&` (background) or `|` (pipe) does not (2026-11-10).
                guard = "&&" in run or "||" in run
            elif c == "(":
                end_command()
                guard = False
                self.i += 1
                self.nested(")")
            elif c == ")":
                end_command()
                guard = False
                self.i += 1
            else:
                add(c)
                self.i += 1
        end_command()


def read(text, depth=0):
    """(commands, strings, known substitutions, variable references, command
    spans) of `text`."""
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
    return commands, strings, r.known, r.refs, r.cmd_spans


ESCAPES = {"n": "\n", "t": "\t", "r": "\r", "a": "\a", "b": "\b", "e": "\x1b", "E": "\x1b",
           "f": "\f", "v": "\v", "\\": "\\", '"': '"', "'": "'"}
MAX_PRINTED = 10000


def unescape(text):
    r"""printf's format escapes / echo -e: \n \t \\ \0NNN \NNN \xHH; \c ends
    the output."""
    out, i = [], 0
    while i < len(text):
        c = text[i]
        if c != "\\" or i + 1 >= len(text):
            out.append(c)
            i += 1
            continue
        m = re.match(r"\\(x[0-9a-fA-F]{1,2}|0?[0-7]{1,3}|c|.)", text[i:i + 6], re.S)
        esc = m.group(1)
        i += len(m.group(0))
        if esc == "c":
            break
        try:
            if esc[:1] == "x" and len(esc) > 1:
                out.append(chr(int(esc[1:], 16)))
            elif esc[:1] in "01234567":        # octal only; \8 \9 are literal
                out.append(chr(int(esc, 8) & 0xFF))
            else:
                out.append(ESCAPES.get(esc, "\\" + esc))
        except ValueError:                     # a stray \8 / \9 that slipped the class
            out.append("\\" + esc)
    return "".join(out)


def printed(cmd):
    """What one `echo` or `printf` of plain words prints, without trailing
    newlines (a substitution drops them); None for anything else. Plain: no
    expansion, glob or substitution left in a word after quote removal
    (2026-11-09: `rm -r $(echo -f) x` is a recursive force delete written in
    the text)."""
    words = expand(cmd)
    if not words or any(re.search(r"[\x00$*?\[`]", w) for w in words):
        return None
    if words[0] == "echo":
        args, interpret = words[1:], False
        while args and re.fullmatch(r"-[neE]+", args[0]):
            if "e" in args[0] or "E" in args[0]:
                interpret = args[0].rfind("e") > args[0].rfind("E")
            args = args[1:]
        out = " ".join(args)
        out = unescape(out) if interpret else out
    elif words[0] == "printf":
        args, dashes = words[1:], False
        if args[:1] == ["--"]:
            args, dashes = args[1:], True
        if not args or (args[0].startswith("-") and not dashes):
            return None             # printf -v var ...: prints nothing here, or no format
        fmt, args, parts = args[0], args[1:], []
        while True:
            used = 0
            for tok in re.split(r"(%.)", fmt):
                if tok == "%%":
                    parts.append("%")
                elif tok in ("%s", "%b"):
                    a = args.pop(0) if args else ""
                    used += 1
                    parts.append(unescape(a) if tok == "%b" else a)
                elif re.fullmatch(r"%.", tok):
                    return None     # %d, %5s ...: not followed here
                else:
                    parts.append(unescape(tok))
            if not args or not used or sum(map(len, parts)) > MAX_PRINTED:
                break
        out = "".join(parts)
    else:
        return None
    return None if len(out) > MAX_PRINTED else out.rstrip("\n")


def requote(value, quoted):
    """`value` written so bash reads it back as the text an expansion gives:
    inside "..." as one word; unquoted split on blanks (2026-11-09)."""
    if quoted:
        return re.sub(r'(["\\$`])', r"\\\1", value)
    value = re.sub(r"[ \t\n]+", " ", value)
    return re.sub(r"([^A-Za-z0-9_\-.,/:=+@%^ ])", r"\\\1", value)


ASSIGNMENT = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\+?=(.*)\Z", re.S)
DECLARERS = {"export", "declare", "local", "readonly", "typeset"}
MAX_FILL_ROUNDS = 20    # chain A=…; B=$A; … resolves one link per round
MAX_VARIANTS = 32       # filled texts produced by branching on a loop variable


def var_events(cmd_spans):
    """variable -> its assignment/unset events in command order, each
    (pos, depth, kind, values). kind 'set' carries the plain values (a `for`
    gives several); 'opaque' is an assignment whose value is not plain yet
    (a $( ), another variable) and 'unset' an unset — both shadow earlier
    values so a later use is not filled. Only an all-assignment command
    (`A=1 B=2`), a declarer, a `for`, or `unset` sets the shell (an env prefix
    `A=1 cmd` does not persist, so it is skipped). Depth is the nesting of the
    command, so an assignment inside `( )` or `$( )` does not reach a use
    outside it (2026-11-10)."""
    def plain(v):
        return None if re.search(r"[\x00$`]", v) else v

    events = {}

    def add(var, pos, depth, kind, values=None, guard=False):
        events.setdefault(var, []).append((pos, depth, kind, values, guard))

    for start, depth, cmd, guard in cmd_spans:
        if not cmd:
            continue
        if cmd[0] == "unset":
            for w in cmd[1:]:
                if re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", w):
                    add(w, start, depth, "unset", guard=guard)
            continue
        if (cmd[0] == "for" and len(cmd) > 3 and cmd[2] == "in"
                and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", cmd[1])):
            vals = [p for w in expand(cmd[3:]) for p in [plain(w)] if p is not None]
            add(cmd[1], start, depth, "set" if vals else "opaque", vals, guard=guard)
            continue
        if all(ASSIGNMENT.match(w) for w in cmd):
            pairs = cmd
        elif cmd[0] in DECLARERS:
            pairs = [w for w in cmd[1:] if ASSIGNMENT.match(w)]
        else:
            continue
        for w in pairs:
            m = ASSIGNMENT.match(w)
            v = plain(m.group(2))
            add(m.group(1), start, depth, "set" if v is not None else "opaque",
                [v] if v is not None else None, guard=guard)
    return events


def value_of(events, var, pos, depth):
    """The values `var` could hold at a use at (pos, depth). bash inherits a
    variable into a subshell / substitution, so an assignment at the SAME OR AN
    OUTER nesting (`e[1] <= depth`) is visible (2026-11-10: a use inside `( )`
    or `$( )` must see an outer `x=…`). Events are folded in order: an
    unguarded `set` replaces the possible values; a `set` guarded by `&&` / `||`
    (it may not run) ADDS its value, keeping what came before; an unguarded
    `unset` / opaque (value not plain) makes it unknown; a guarded unset /
    opaque leaves the earlier values standing (one branch is unknown, which just
    stays unfilled). None = do not fill; else the list of values to try (several
    means branch)."""
    evs = sorted((e for e in events.get(var, ()) if e[1] <= depth and e[0] < pos),
                 key=lambda e: e[0])
    possible = None
    for _, _, kind, values, guard in evs:
        if kind == "set":
            possible = list(values) if not guard else list(dict.fromkeys((possible or []) + values))
        elif not guard:                 # definite unset / opaque -> unknown
            possible = None
    return possible


def apply_edits(text, edits):
    """`text` with each (start, end, replacement) applied; overlapping edits
    (a $( ) that contains a $NAME) keep the outer one."""
    out, pos = [], 0
    for start, end, value in sorted(edits):
        if start < pos:
            continue
        out.append(text[pos:start])
        out.append(value)
        pos = end
    out.append(text[pos:])
    return "".join(out)


def danger_values(values):
    """The values worth branching on: only one that contributes a token
    starting `-`/`+` or holding `:` can turn `rm $x` / `git push $x` into a
    recursive-force or refspec danger; a plain word (a filename, a branch)
    cannot, so all the plain ones collapse to one representative. This keeps a
    late option value from being dropped when a long `for` list would exceed
    MAX_VARIANTS (2026-11-10). A value is tested on its blank-split tokens, not
    whole: used unquoted, `foo -rf` splits into a `-rf` option (fifth review,
    2026-11-10), so it must be kept, not collapsed."""
    def optionish(v):
        return any(t.startswith(("-", "+")) or ":" in t for t in v.split())
    keep = [v for v in dict.fromkeys(values) if optionish(v)]
    plain = next((v for v in values if not optionish(v)), None)
    if plain is not None:
        keep.append(plain)
    return keep or [values[0]]


def resolve(text):
    """`text` with what it itself spells out filled in and read to a fixed
    point: known substitutions, and each $NAME / ${NAME} whose value the
    command gives earlier. A variable with several values (a `for`, or a value
    that may or may not have been reassigned) branches, so the result is a list
    of texts; a use that stays unknown is left alone (`rm -f "$f"`).
    Single-valued fills repeat to a fixed point at one depth, so a chain
    `A=…; B=$A; …` does not cost a re-read level each (2026-11-10)."""
    multi = []
    for _ in range(MAX_FILL_ROUNDS):
        _, _, known, refs, spans = read(text)
        events = var_events(spans)
        singles = [(s, e, requote(out, q)) for s, e, out, q in known]
        multi = []
        for s, e, var, q, d in refs:
            vals = value_of(events, var, s, d)
            if not vals:
                continue
            vals = danger_values(vals)
            if len(vals) == 1:
                singles.append((s, e, requote(vals[0], q)))
            else:
                multi.append((s, e, q, vals))
        nxt = apply_edits(text, singles)
        if nxt == text:
            break
        text = nxt
    else:
        return [text]                   # never settled: do not branch stale refs
    out = [text]
    if multi:
        import itertools
        for combo in itertools.islice(
                itertools.product(*[range(len(m[3])) for m in multi]), MAX_VARIANTS):
            out.append(apply_edits(text, [(m[0], m[1], requote(m[3][combo[k]], m[2]))
                                          for k, m in enumerate(multi)]))
    return out


def sequence(m):
    """The items of {a..b} / {a..b..step} (numbers or single letters), or None
    (also when there are too many: the word is then kept unexpanded)."""
    a, b, step = m.group(1), m.group(2), int(m.group(3) or 1) or 1
    if re.fullmatch(r"-?\d+", a) and re.fullmatch(r"-?\d+", b):
        lo, hi = int(a), int(b)
        rng = range(lo, hi + 1, abs(step)) if lo <= hi else range(lo, hi - 1, -abs(step))
        return [str(n) for n in rng] if len(rng) <= BRACE_LIMIT else None
    if len(a) == 1 and len(b) == 1:
        lo, hi = ord(a), ord(b)
        rng = range(lo, hi + 1, abs(step)) if lo <= hi else range(lo, hi - 1, -abs(step))
        return [chr(n) for n in rng]
    return None


def braces(word):
    """Brace expansion, in order: {-r,-f} -> ['-r', '-f'], {r,}m -> ['rm', 'm'],
    and sequences: --{d..d}elete -> ['--delete'] (agentskel v1.69.0 review)."""
    words = [word]
    while True:
        changed, out = False, []
        for w in words:
            m = re.search(r"\{([^{}]*,[^{}]*)\}", w)
            q = None if m else re.search(r"\{([^{}.]+)\.\.([^{}.]+)(?:\.\.(-?\d+))?\}", w)
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
                return [word]       # too big: keep it unexpanded, keep reading
        words = out
        if not changed:
            return words


def expand(args):
    # A brace bomb must not blind the reader: an over-large word is kept
    # unexpanded (braces() above) rather than crashing, so a real
    # `git push --mirror` later in the command is still read (second review of
    # PR #167: a brace bomb made the reader give up and the shell's blunt
    # fallback miss it).
    out = []
    for a in args:
        out.extend(braces(a) if "{" in a else [a])
        if len(out) > 20 * BRACE_LIMIT + len(args):
            return args          # too big overall: leave every word unexpanded
    return out


def name(word):
    """The program a command word runs: its basename, lower-cased (macOS file
    systems ignore case: `GIT reset` runs git), without zsh's `=` (`=git` is
    git) and without expansions glued in front that may be empty (`${x}git`,
    `$(:)git`) (agentskel v1.69.0 review)."""
    b = os.path.basename(bare(word, globs=False).replace(PLACEHOLDER, "")).lower()
    return b[1:] if b.startswith("=") and len(b) > 1 else b


def is_cmd(word, target):
    """Is `word`, as a command word, the program `target` (also as a glob that
    carries a literal letter: `gi[t]`, `/usr/bin/fin[d]`)?"""
    n = name(word)
    return n == target or globbed(n, target)


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


def globbed(word_name, target):
    """A command name written as a glob that matches `target` (`gi[t]`,
    `/bin/r?`): bash expands it to the real command when the file exists.
    The glob must carry at least one literal letter, so a bare `*` argument
    (`cp * dest`) is not read as a command named rm (second review of PR #167)."""
    return (any(c in word_name for c in "*?[")
            and any(c.isalnum() for c in word_name)
            and fnmatch.fnmatchcase(target, word_name))


def command_starts(words):
    """(indexes where a command name can stand, index of the first wrapper or
    None). A command name stands first (after NAME=value words and wrappers),
    and anywhere after a wrapper: wrappers take options with values of their
    own (`timeout 10 x`, `sudo -u bob x`, `nice -n 5 x`), so every later word
    counts (second review of PR #167)."""
    first = next((k for k, w in enumerate(words) if name(w) in WRAPPERS), None)
    return {command_name(words)}, first


# Text bash replaces at run time, possibly with nothing: a $( ) / backtick /
# ${ } placeholder, $NAME, $1, $@ and friends, or a glob character. Review of
# PR #167: `git push origin x $x-f` is a force push when x is unset.
EXPANSION = re.compile(r"\x00|\$(?:[A-Za-z_][A-Za-z0-9_]*|[0-9@*#?$!-])|[*?]")
LEADING_EXPANSIONS = re.compile(r"^(?:" + EXPANSION.pattern + r")+")
LEADING_VARIABLES = re.compile(r"^(?:\x00|\$(?:[A-Za-z_][A-Za-z0-9_]*|[0-9@*#?$!-]))+")
MAYBE_EXPANSION = re.compile(r"[\x00$*?]")
FALSE_WORDS = {"false", "no", "off", "0", ""}


def bare(word, globs=True):
    """`word` with the expansions in front removed: what bash passes when
    they are empty. `$x-f` -> "-f", `${x}--force` -> "--force". With
    globs=False only variables and substitutions count (a refspec's `*` is
    git's, not bash's: `'*:*'`)."""
    if not MAYBE_EXPANSION.search(word):
        return word
    return (LEADING_EXPANSIONS if globs else LEADING_VARIABLES).sub("", word)


def pure_expansion(word):
    """A word that is nothing but expansions: when they are empty bash drops
    an unquoted word altogether (`git $x push`)."""
    return word != "" and bare(word) == ""


def sub_name(word):
    """The subcommand bash passes when the expansions in and around it are
    empty: `push$x` -> push, `${x:-push}` -> push."""
    v = bare(word)
    m = EXPANSION.search(v)
    if not m:
        return v
    whole = EXPANSION.sub("", v)    # git re$()set: reset (agentskel v1.69.0 review)
    return whole if whole in GIT_CHECKED else v[:m.start()]


def action_names(word):
    """The words bash may pass for an action word (`drop`, `delete`): cut at
    the first expansion, and with every expansion empty (`dr$()op` is drop
    when the substitution prints nothing; agentskel v1.69.0 review)."""
    v = bare(word)
    m = EXPANSION.search(v)
    return {v[:m.start()], EXPANSION.sub("", v)} if m else {v}


def git_subcommand(cmd, i):
    """cmd[i] is git: index of its subcommand, after global options and
    words that are only expansions (`git $x push`)."""
    j = i + 1
    while j < len(cmd) and (cmd[j].startswith("-") or pure_expansion(cmd[j])):
        j += 2 if cmd[j] in GIT_OPTS_WITH_VALUE else 1
    return j


def git_helper(word_name):
    """The subcommand of one of git's own helper binaries (`git-push`), also
    written as a glob (`git-p?sh`, `gi[t]-push`), else None."""
    if any(c in word_name for c in "*?["):
        return next((s for s in sorted(GIT_CHECKED) if fnmatch.fnmatchcase("git-" + s, word_name)), None)
    if word_name.startswith("git-") and len(word_name) > 4:
        return word_name[4:]
    return None


def git_config_given(cmd, i, j, env=()):
    """Configuration given to the one git command cmd[i] (subcommand at j):
    [(key, value)] from `-c key=value`, `--config-env=key=VAR`, and the
    GIT_CONFIG_* words in `env` (set in front of it). Keys lowercased (git's
    section and key names are case-insensitive). value None: not in the
    command text."""
    out = []
    k = i + 1
    while k < j:
        w = cmd[k]
        if w == "-c" and k + 1 < j:
            key, eq, value = cmd[k + 1].partition("=")
            out.append((key.lower(), value if eq else "true"))
            k += 2
            continue
        if w == "--config-env" and k + 1 < j:
            out.append((cmd[k + 1].partition("=")[0].lower(), None))
            k += 2
            continue
        if w.startswith("--config-env="):
            out.append((w[len("--config-env="):].partition("=")[0].lower(), None))
        k += 2 if w in GIT_OPTS_WITH_VALUE else 1
    keys, values = {}, {}
    for w in env:
        m = re.match(r"^GIT_CONFIG_(KEY|VALUE)_([0-9]+)=(.*)\Z", w, re.S)
        if m:
            (keys if m.group(1) == "KEY" else values)[m.group(2)] = m.group(3)
        elif w.startswith("GIT_CONFIG_PARAMETERS="):
            text = w[len("GIT_CONFIG_PARAMETERS="):]
            pairs = re.findall(r"'([^']*)'(?:='([^']*)')?", text)
            if pairs:                   # git's own quoting: 'key'='value' ...
                for k2, v2 in pairs:
                    if not v2 and "=" in k2:    # and the older 'key=value' (agentskel)
                        k2, _, v2 = k2.partition("=")
                    out.append((k2.lower(), v2 if v2 else None))
            else:
                for key in re.findall(r"[A-Za-z0-9_-]+(?:\.[^\s'=\"]+)?\.[A-Za-z0-9_-]+", text):
                    out.append((key.lower(), None))
    for n, key in keys.items():
        out.append((key.lower(), values.get(n)))
    return out


def config_risk(sub, config):
    """(reason, kind) when configuration given to this git command makes `sub`
    destructive, else None. kind: "remote" (a remote delete: no override) or
    "block"."""
    for key, value in config:
        falsy = value is not None and value.strip().lower() in FALSE_WORDS
        if sub == "push" and re.fullmatch(r"remote\..+\.mirror", key) and not falsy:
            return ("git push with remote.<name>.mirror set — overwrites or deletes every "
                    "branch on the remote"), "remote"
        if sub == "push" and re.fullmatch(r"remote\..+\.push", key):
            spec = None if value is None else bare(value, globs=False)
            if spec is None or spec.startswith((":", "+:")):
                return "git push with a remote.<name>.push refspec that deletes (:branch)", "remote"
            if spec.startswith("+"):
                return "force push (a +refspec in remote.<name>.push)", "block"
        if sub == "clean" and key == "clean.requireforce" and (value is None or falsy):
            return "git clean with clean.requireForce off — removes untracked files without -f", "block"
    return None


# Short options git accepts for each subcommand checked here. A word that
# only becomes an option once an expansion in front of it is empty
# ("$BRANCH-fix" -> "-fix") counts as one only if git would accept it: with
# the variable empty, git rejects "-fix" ("unknown switch `i'") and does
# nothing (second review of PR #167).
VALID_SHORTS = {
    "push": "vqundf46o", "clean": "dfinqexX", "branch": "dDfmMcClarvqtu",
    "checkout": "bBltqfmp", "switch": "cCdfmqt", "reset": "qpN", "worktree": "f",
    "checkout-index": "uqafnz", "read-tree": "muinv", "config": "lefz",
}


def git_options(args, value_letters="", value_longs=(), valid=None, guess=True):
    """The options of one git command: (long names, short letters, names,
    words after `--`).

    Read up to `--`, as git does. A short cluster stops at a letter that takes
    a value (`-bfix` is -b with the value "fix", not -f), and when that letter
    ends the cluster the next word is its value; a long option in
    `value_longs` given without `=` takes the next word too (`--orphan NAME`).
    Long names keep any prefix given (`--forc`): git accepts an unambiguous
    prefix of a long option, and an ambiguous one is an error, so a prefix is
    read as the option it starts.

    guess=True also reads what bash may pass: expansions in front of a word
    are dropped (`$x-f` is -f when x is empty; a short cluster only if every
    letter is in `valid`), and an expansion inside an option (`-u$x`,
    `--$x`) records "*", which matches every option. guess=False reads only
    what is certainly there. `names` are the other words before `--`;
    `after` is None when there is no `--`."""
    longs, shorts, names, after = [], set(), [], None
    skip = False
    for arg in args:
        if skip:
            skip = False
            continue
        if after is not None:
            after.append(arg)
            continue
        if arg == "--":
            after = []
            continue
        view = bare(arg) if guess else arg
        if view == "-" or not view.startswith("-"):
            names.append(arg)
            continue
        if view.startswith("--"):
            raw = view[2:].split("=", 1)[0]
            m = EXPANSION.search(raw)
            opt = raw[:m.start()] if m else raw
            # `--mirror$x` is that option or a git error, in BOTH passes: the
            # literal prefix before an expansion decides it. Only `--$x` (no
            # literal prefix) is unknown — a wildcard when guessing, ignored
            # when certain (second review of PR #167).
            if opt or not m:
                longs.append(opt)
            elif guess:
                longs.append("*")
            skip = "=" not in view and not m and is_option([opt], *value_longs)
            continue
        if view != arg and valid is not None:
            accepted = True
            for letter in view[1:]:
                if EXPANSION.match(letter):
                    break               # an interior expansion (a second, maybe
                                        # empty, ${ }) could collapse to any flag:
                                        # leave it for the wildcard below, do not
                                        # demote (`${x:--}${y:-f}` is -f) — sixth
                                        # review of PR #167
                if letter not in valid:
                    accepted = False
                    break
                if letter in value_letters:
                    break
            if not accepted:
                names.append(arg)
                continue
        for k, letter in enumerate(view[1:]):
            if EXPANSION.match(view, k + 1):
                if guess:
                    shorts.add("*")     # -u$x: the hidden flag could be any
                break                   # certain: stop; letters so far are sure
            shorts.add(letter)
            if letter in value_letters:
                skip = k == len(view) - 2
                break
    return longs, shorts, names, after


def is_option(longs, *full_names):
    """A long option given in full or as a prefix of one of `full_names`
    ("*": an option hidden in an expansion, which could be any of them)."""
    return any(opt == "*" or (opt and full.startswith(opt)) for opt in longs for full in full_names)


def has(shorts, letter):
    return letter in shorts or "*" in shorts


SESSION_CWD = ""            # from the hook (SAFETY_CWD): where the command runs
ELSEWHERE = False           # the command may run git in another repo (cd, -C, GIT_DIR, ...)
CREATES = False             # a command in the line may create a branch
_REPO = {}


def repo_state():
    """(local branch names lower-cased, current branch) of the session's
    repo, or None when git cannot say. Read once."""
    if "state" not in _REPO:
        _REPO["state"] = None
        try:
            import subprocess
            cwd = SESSION_CWD or os.getcwd()
            heads = subprocess.run(["git", "-C", cwd, "for-each-ref", "--format=%(refname:short)",
                                    "refs/heads/"], capture_output=True, text=True, timeout=2)
            cur = subprocess.run(["git", "-C", cwd, "symbolic-ref", "--short", "-q", "HEAD"],
                                 capture_output=True, text=True, timeout=2)
            if heads.returncode == 0:
                _REPO["state"] = ({h.strip().lower() for h in heads.stdout.splitlines() if h.strip()},
                                  cur.stdout.strip())
        except Exception:
            pass
    return _REPO["state"]


def exists_path(word):
    """`word` names a file or folder in the session's folder (agentskel
    v1.69.0: `git checkout a` overwrites the file a, when there is one)."""
    try:
        return os.path.lexists(os.path.join(SESSION_CWD or os.getcwd(), word))
    except Exception:
        return True


def branch_move_overwrites(names):
    """A forced `git branch -M/-C [<old>] <new>`: may it replace an existing
    branch? agentskel's owner (2026-11-17): blocked only when the target
    exists or cannot be checked."""
    if not names:
        return False
    new = names[-1]
    if ELSEWHERE or CREATES or MAYBE_EXPANSION.search(new) or PLACEHOLDER in new:
        return True
    state = repo_state()
    if state is None:
        return True
    heads, current = state
    old = names[0] if len(names) >= 2 else current
    if new == old:
        return False            # renaming a branch onto itself changes nothing
    return new.lower() in heads  # case-insensitive: refs are files on macOS


def single_path(word):
    """`git checkout <word>` alone overwrites the file <word> when there is
    such a file and no branch of that name (git prefers the branch)."""
    if not exists_path(word):
        return False
    state = repo_state()
    return state is None or word.lower() not in state[0]


def looks_like_path(word):
    """A name no branch, tag or commit can have: `.`, `src/`, `*.ts`, `:/`
    (git refuses ref names with * ? [ or : and ones ending in /)."""
    return word in (".", "..") or word.endswith("/") or word.startswith(":") or \
        any(c in word for c in "*?[")


def alias_words(text):
    """An alias's words as git splits them (quotes removed)."""
    try:
        return shlex.split(text)
    except ValueError:
        return text.split()


# Subcommands checked below: git runs its own command for these whatever an
# alias of the same name says, so an alias is only looked at for other names.
GIT_CHECKED = {"push", "clean", "worktree", "checkout", "switch", "reset", "branch",
               "config", "checkout-index", "read-tree", "send-pack", "update-ref", "stash",
               "restore", "reflog", "submodule"}
PUSH_VALUE_LONGS = ("push-option", "repo", "receive-pack", "exec")
CHECKOUT_VALUE_LONGS = ("orphan", "conflict", "pathspec-from-file")


def is_colon_refspec(word):
    # `:` alone pushes the matching branches; it deletes nothing (agentskel
    # v1.69.0 review). `+:` is a forced matching push, decided as a +refspec.
    return word.startswith((":", "+:")) and word not in (":", "+:")


def git_push_rule(args, plain_ok):
    longs, shorts, names, after = git_options(args, "o", PUSH_VALUE_LONGS, VALID_SHORTS["push"])
    c_longs, c_shorts, _, _ = git_options(args, "o", PUSH_VALUE_LONGS, guess=False)
    refs = names + (after or [])
    # remote deletes first: they must win over an overridable force flag
    for opt, what in (("mirror", "git push --mirror — overwrites or deletes every branch on the remote"),
                      ("prune", "git push --prune — deletes every remote branch with no local "
                                "counterpart, unchecked; delete merged branches by name with "
                                "git push <remote> --delete")):
        if is_option(c_longs, opt):
            return what, "remote"
        if is_option(longs, opt):
            return what + " (an option hidden in an expansion)", "block"
    literal_colon = any(is_colon_refspec(w) for w in refs)
    guessed_colon = any(is_colon_refspec(bare(w, globs=False)) for w in refs)
    has_ref = len(refs) >= 2 or literal_colon       # `push -d <remote>` alone is an error
    if literal_colon or (has_ref and (is_option(c_longs, "delete") or "d" in c_shorts)):
        option_words = [w for w in args if w.startswith("-") and w != "-"]
        plain = (plain_ok and after is None and not literal_colon and option_words and
                 all(w in ("--delete", "-d") for w in option_words))
        if plain:
            return "", "plain"      # the hook's merged-branch check decides (ask or block)
        return ("remote branch delete in a form the merged-branch check does not read "
                "(abbreviated or bundled -d/--delete, :branch, +:branch, git options or another "
                "spelling of git); use git push <remote> --delete <branch>"), "remote"
    if guessed_colon or (has_ref and (is_option(longs, "delete") or has(shorts, "d"))):
        # owner, 2026-11-03 (1b): a source that is a variable deletes the
        # branch when it is empty; blocked, but the override applies
        return ("git push with a refspec or option built from a variable — deletes the "
                "remote branch if it is empty (\"$SRC:$DST\")"), "block"
    if has(shorts, "f") or is_option(longs, "force", "force-with-lease"):
        return "force push (git push --force / -f / --force-with-lease)", "block"
    if any(bare(w, globs=False).startswith("+") for w in refs):
        return "force push (a +refspec, e.g. git push origin +main)", "block"
    return None


def git_rule(sub, args, depth, plain_ok=False, defining=False):
    """(reason, kind) when `git <sub> <args>` discards work, else None.
    defining: `args` is an alias's text, to which more words will be added."""
    if sub == "push":
        return git_push_rule(args, plain_ok)
    if sub == "branch":
        longs, shorts, names, after = git_options(args, valid=VALID_SHORTS["branch"])
        delete = is_option(longs, "delete") or has(shorts, "d") or has(shorts, "D")
        force = (has(shorts, "f") or has(shorts, "D") or "*" in longs or
                 any(len(o) >= 3 and "force".startswith(o) for o in longs))
        if delete and force:
            return "force branch delete (git branch delete + force, any spelling) — discards unmerged work", "block"
        # A forced move/copy overwrites the <newbranch> it names. Force is -M/-C,
        # a separate -f, or --force; move/copy is -M/-C/-m/-c or --move/--copy.
        # Only the two-operand form overwrites a *named* branch — the single
        # operand (`git branch -M main`, the routine post-init rename of the
        # current branch) clobbers nothing new, so it is allowed. Operands after
        # `--` count too (fourth review of PR #167: `git branch -M -- old new`).
        operands = names + (after or [])
        move_copy = (has(shorts, "M") or has(shorts, "C") or has(shorts, "m")
                     or has(shorts, "c") or is_option(longs, "move", "copy"))
        force_mc = (has(shorts, "M") or has(shorts, "C") or has(shorts, "f") or "*" in longs
                    or any(len(o) >= 3 and "force".startswith(o) for o in longs))
        if move_copy and force_mc and ("*" in shorts or defining or branch_move_overwrites(operands)):
            return ("git branch --move/--copy --force (-M / -C) onto a branch that exists (or "
                    "cannot be checked) — replaces it"), "block"
    elif sub == "clean":
        longs, shorts, _, _ = git_options(args, "e", ("exclude",), VALID_SHORTS["clean"])
        if has(shorts, "f") or is_option(longs, "force"):
            return "git clean force (-f / --force) — removes untracked files, cannot be undone", "block"
    elif sub == "worktree" and args[:1] == ["remove"]:
        longs, shorts, _, _ = git_options(args[1:], valid=VALID_SHORTS["worktree"])
        if has(shorts, "f") or is_option(longs, "force"):
            return "git worktree remove force (--force / -f) — discards uncommitted worktree changes", "block"
    elif sub == "checkout":
        longs, shorts, names, after = git_options(args, "bB", CHECKOUT_VALUE_LONGS, VALID_SHORTS["checkout"])
        if has(shorts, "f") or is_option(longs, "force"):
            return "git checkout --force / -f — discards uncommitted changes", "block"
        targets = names + (after or [])
        if targets and ("*" in longs or is_option(longs, "ours", "theirs", "conflict", "patch")):
            # agentskel's owner (2026-11-17): --ours / --theirs <path> overwrites
            # the file, discarding edits or a hand resolution (MCU-Watchlist allows it)
            return "git checkout --ours/--theirs/--conflict/--patch <path> — overwrites those files", "block"
        # `checkout [<commit>] [--] <path>...` overwrites those paths: paths
        # after a `--` (or an alias ending in `--`), two names (a branch switch
        # takes at most one), or one name no ref can have (`*`, `src/`, `:/`).
        # One plain name alone cannot be told from a branch here.
        if (after or (defining and after is not None) or len(names) >= 2
                or is_option(longs, "pathspec-from-file")
                or (len(names) == 1 and (looks_like_path(names[0]) or single_path(names[0])))):
            return "git checkout <commit> [--] <path> — discards those paths' uncommitted changes", "block"
    elif sub == "switch":
        longs, shorts, _, _ = git_options(args, "cC", ("orphan", "conflict"), VALID_SHORTS["switch"])
        if has(shorts, "f") or is_option(longs, "force", "discard-changes"):
            return "git switch --force / -f / --discard-changes — discards uncommitted changes", "block"
    elif sub == "reset":
        longs, _, _, _ = git_options(args, valid=VALID_SHORTS["reset"])
        if is_option(longs, "hard"):
            return "hard reset (git reset --hard) — discards uncommitted work", "block"
    elif sub == "checkout-index":
        longs, shorts, _, _ = git_options(args, valid=VALID_SHORTS["checkout-index"])
        prefix = next((a.split("=", 1)[1] for a in args if a.startswith("--prefix=")), None)
        # A prefix makes -f safe only when it is a plain relative subfolder: not
        # absolute, no `..`, no expansion. `--prefix="$PWD/"` and `--prefix=../`
        # point straight back at the working files (second review of PR #167).
        safe_prefix = (prefix not in (None, "", "/") and not prefix.startswith("/")
                       and ".." not in prefix and not MAYBE_EXPANSION.search(prefix))
        if safe_prefix:
            return None
        if has(shorts, "f") or is_option(longs, "force"):
            return "git checkout-index --force — overwrites uncommitted changes", "block"
    elif sub == "read-tree":
        longs, shorts, _, _ = git_options(args, valid=VALID_SHORTS["read-tree"])
        if is_option(longs, "reset") and has(shorts, "u"):
            return "git read-tree --reset -u — overwrites uncommitted changes", "block"
    elif sub == "send-pack":
        longs, shorts, names, after = git_options(args, valid="fv")
        refs = names + (after or [])
        if any(is_colon_refspec(bare(w, globs=False)) for w in refs):
            return "git send-pack with a :branch refspec — deletes the remote branch", "remote"
        if (has(shorts, "f") or is_option(longs, "force")
                or any(bare(w, globs=False).startswith("+") for w in refs)):
            return "git send-pack --force / +refspec — overwrites the remote branch", "block"
    elif sub == "update-ref":
        longs, shorts, _, _ = git_options(args, valid="dmz")
        if has(shorts, "d") or is_option(longs, "delete"):
            return "git update-ref -d — deletes a ref directly", "block"
    elif sub == "stash":
        if args[:1] and action_names(args[0]) & {"drop", "clear"}:
            return "git stash drop/clear — discards stashed work", "block"
    elif sub == "restore":
        # Anything that touches the working tree. `--staged` alone only
        # unstages (what `git status` suggests): allowed (agentskel v1.69.0).
        longs, shorts, _, _ = git_options(args, "s", ("source", "pathspec-from-file"), "sWSpqm")
        staged = has(shorts, "S") or is_option(longs, "staged")
        worktree = has(shorts, "W") or is_option(longs, "worktree") or "*" in longs or "*" in shorts
        if not staged or worktree:
            return "git restore — discards uncommitted changes (modern 'checkout -- <file>')", "block"
    elif sub == "reflog":
        if args[:1] and action_names(args[0]) & {"delete", "expire"}:
            return "git reflog delete/expire — removes the history that recovers lost work", "block"
    elif sub == "submodule":
        if args[:1] and action_names(args[0]) & {"update", "deinit"}:
            longs, shorts, _, _ = git_options(args[1:], valid="fqNr")
            if has(shorts, "f") or is_option(longs, "force"):
                return "git submodule update/deinit --force — discards changes in submodules", "block"
    elif sub == "config":
        return git_config_write(args, depth)
    return None


CONFIG_READS = ("get", "get-all", "get-regexp", "get-urlmatch", "get-color", "get-colorbool",
                "list", "unset", "unset-all", "remove-section", "rename-section", "edit")
CONFIG_VALUE_OPTS = {"-f", "--file", "--blob", "--type", "--default", "--comment", "--value", "--url"}


def git_config_write(args, depth):
    """`git config` writing a setting that makes a later plain command
    destructive: remote.<name>.mirror / .push (the next `git push`),
    clean.requireForce off, or an alias whose text is a destructive command.
    Options and the mode word (`set` / `get` / ... in git 2.46+) may come in
    any order before the key, so both are consumed before the key/value is read
    (`git config set --local key val`, `git config --local set key val`). From
    the key on, every word is a name or the value, as git reads it
    (`git config alias.p '-c x=y push'` stores the value)."""
    MODES = {"set", "add", "replace-all", "unset", "unset-all", "get", "get-all",
             "get-regexp", "get-urlmatch", "get-color", "get-colorbool", "list",
             "edit", "remove-section", "rename-section", "rename-section"}
    opts, names, mode, k = [], [], None, 0
    while k < len(args):
        w = args[k]
        if w == "--":
            names = args[k + 1:]
            break
        if pure_expansion(w):
            k += 1                  # an empty $x before the key
            continue
        if bare(w).startswith("-"):
            opts.append(w)
            k += 2 if w in CONFIG_VALUE_OPTS else 1
            continue
        if mode is None and w in MODES:
            mode = w
            k += 1
            continue
        names = args[k:]
        break
    longs, shorts, _, _ = git_options(opts, "f", tuple(o[2:] for o in CONFIG_VALUE_OPTS if o.startswith("--")),
                                      VALID_SHORTS["config"])
    unknown = "*" in longs or "*" in shorts
    reading = (mode in CONFIG_READS) or (not unknown and (is_option(longs, *CONFIG_READS)
                                                          or "l" in shorts or "e" in shorts))
    if reading:
        return None
    if len(names) < 2:
        return None             # a read: `git config <key>`
    key, value = names[0].lower(), names[1]
    found = config_risk("push", [(key, value)]) or config_risk("clean", [(key, value)])
    if found:
        return "git config: " + found[0] + " (on the next plain command)", found[1]
    if key.startswith("alias.") and not value.startswith("!") and depth < 5:
        found = git_destructive(["git"] + alias_words(value), 0, depth + 1, defining=True)
        if found:
            return "git config alias that runs: " + found[0], found[1]
    return None


def git_destructive(cmd, i, depth=0, env=(), plain_ok=False, defining=False):
    """cmd[i] is git: (reason its subcommand discards work, kind), or None.
    kind: "remote" (a remote delete, blocked with no override, as `git push
    --delete` is in the hook's own verdict), "block", or "plain" (a plain
    `git push <remote> --delete <branch>` for the hook's merged-branch check).
    plain_ok: cmd[i] is a literal git word (not git-push or a glob)."""
    j = git_subcommand(cmd, i)
    if j >= len(cmd):
        return None
    config = git_config_given(cmd, i, j, env)
    sub = sub_name(cmd[j])
    found = config_risk(sub, config) or git_rule(sub, cmd[j + 1:], depth,
                                                 plain_ok and j == i + 1 and not config, defining)
    if found or sub in GIT_CHECKED or depth >= 5:
        return found
    alias = None
    for key, value in config:
        if key == "alias." + sub.lower():
            alias = (value,)
    if alias is None and sub.lower() in ALIASES:
        # defined by another command in the line (`git config alias.x reset
        # && git x --hard`) or already stored in the repo's config (agentskel)
        alias = (ALIASES[sub.lower()],)
    if alias is None:
        return None
    if alias[0] is None:
        return "git alias whose text is not in the command (--config-env / GIT_CONFIG_PARAMETERS)", "remote"
    if alias[0].startswith("!"):
        # git runs the text in the shell with the arguments after it:
        # `-c alias.x='!sh -c' x -m 'rm -rf y'` and `-c alias.x=!git x reset
        # --hard` run what follows (agentskel v1.69.0 review)
        found = verdict(" ".join([alias[0][1:]] + cmd[j + 1:]).replace(PLACEHOLDER, " "), depth + 1)
        if found.startswith("BLOCK-REMOTE "):
            return found[len("BLOCK-REMOTE "):], "remote"
        if found.startswith("BLOCK "):
            return found[len("BLOCK "):], "block"
        return None
    return git_destructive(["git"] + cmd[i + 1:j] + alias_words(alias[0]) + cmd[j + 1:], 0,
                           depth + 1, env, False, defining)


# Options whose next word is a value, not the search pattern (third review:
# rg -r REPLACEMENT and --pre COMMAND are re-read; a blanket exemption let
# `rg a -r 'rm -rf y' | sh` through).
# --- find / fd / gh (agentskel v1.69.0, BL-009) ---
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
MAX_GIT_CHECKS = 256    # git words with options in one command before giving up (CRASH)
PLAIN_DELETES = [0]     # plain `git push <remote> --delete <branch>` commands seen


def check_command(cmd, depth=0, raw=(frozenset(), False), top=True):
    """BLOCK-REMOTE <reason>, BLOCK <reason> or None for one simple command.
    Plain `git push <remote> --delete <branch>` commands are counted in
    PLAIN_DELETES for the hook's merged-branch check — but only at depth 0, the
    commands bash runs directly. A delete that appears only while re-reading a
    quoted string (an `echo "... --delete ..."` message) must not inflate the
    count, or a legitimate top-level delete gets blocked instead of asked
    (second review of PR #167)."""
    words = expand(cmd)     # {rm,-rf,y} and {r,}m are commands too
    starts, first_wrapper = command_starts(words)

    def is_start(k):
        return k in starts or (first_wrapper is not None and k > first_wrapper)

    rms = [i for i, w in enumerate(words)
           if name(w) == "rm" or (is_start(i) and globbed(name(w), "rm"))]
    if len(rms) > MAX_RM_WORDS:
        raise TooComplex("too many rm words")
    # A remote delete (BLOCK-REMOTE: no override) wins over any other block,
    # so `git push -f --prune` cannot be overridden through its -f.
    plain = None
    for i in rms:           # every rm: `env -u rm -- rm -rf y` runs the second
        if rm_forced_recursive(words[i + 1:]):
            plain = "BLOCK recursive force delete (rm with recursive + force flags) — cannot be undone"
            break
    # tail[k]: some word from k on may be an option or a +/: refspec. Without
    # one, most git rules cannot fire, so a long line that only mentions git
    # (`echo docs: git push git push ...`) is not parsed once per git word
    # (second review of PR #167: 3,500 mentions took the 8 s limit).
    tail = [False] * (len(words) + 1)
    for k in range(len(words) - 1, -1, -1):
        w = words[k]
        b = bare(w)
        tail[k] = tail[k + 1] or (b.startswith("-") and b != "-") or \
            bare(w, globs=False).startswith(("+", ":"))
    env, full_checks = [], 0
    for i, w in enumerate(words):
        if w.startswith("GIT_CONFIG_"):
            env.append(w)
        n = name(w)
        if n == "git" or (is_start(i) and globbed(n, "git")):
            target, at, literal = words, i, n == "git" and w == "git"
        elif is_start(i) and git_helper(n):
            # git's own helper binaries: /usr/lib/git-core/git-push is git push
            target, at, literal = ["git", git_helper(n)] + words[i + 1:], 0, False
        else:
            continue
        j = git_subcommand(target, at)
        if j >= len(target):
            continue
        if target is words and j == at + 1 and not env and not tail[j + 1]:
            sub = sub_name(words[j])
            if sub == "checkout":
                rest = words[j + 1:]
                found = git_rule("checkout", rest, 0) if len(rest) <= 1 else (
                    "git checkout <commit> [--] <path> — discards those paths' uncommitted changes", "block")
            elif sub in ("config", "stash", "restore", "reflog"):
                found = git_rule(sub, words[j + 1:], 0)
            else:
                found = None    # no option and no refspec: nothing here can fire
        else:
            full_checks += 1
            if full_checks > MAX_GIT_CHECKS:
                raise TooComplex("too many git commands with options")
            found = git_destructive(target, at, 0, list(env), plain_ok=literal)
        if not found:
            continue
        reason, kind = found
        if kind == "remote":
            return "BLOCK-REMOTE " + reason
        if kind == "plain":
            if depth > 0 or not top:
                # agentskel v1.69.0: the hook can only ask about a delete it can
                # read as a command of its own. One inside $( ), backticks, ( ),
                # bash -c, eval or quoted text could ride along with an approved
                # top-level delete (`... && bash -c "git push o --delete y"`).
                return ("BLOCK-REMOTE remote branch delete inside $( ), backticks, ( ), bash -c, eval "
                        "or quoted text — nothing can ask about a command it cannot see; run it as a "
                        "plain command")
            PLAIN_DELETES[0] += 1
        else:
            plain = plain or "BLOCK " + reason
    # find / fd removers and gh writes, in any position a command can stand
    # or behind a wrapper (agentskel v1.69.0).
    for i, w in enumerate(words):
        if plain:
            break
        if not (is_start(i) or name(w) in ("find", "fd", "fdfind", "gh")):
            continue
        if is_cmd(w, "find") and find_destructive(words[i + 1:]):
            plain = "BLOCK find with -delete / -exec rm — bulk delete"
        elif (is_cmd(w, "fd") or is_cmd(w, "fdfind")) and fd_destructive(words[i + 1:]):
            plain = "BLOCK fd --exec rm — bulk delete"
        elif is_cmd(w, "gh"):
            found = gh_check(words, i, raw)
            if found:
                plain = "BLOCK " + found
    return plain


ALIASES = {}                # git aliases defined in the text or stored in the repo


def collect_aliases(commands):
    """git aliases this text defines: -c alias.x=v / git config alias.x v
    (and alias.x=v) anywhere in it; their invocations are checked as git."""
    aliases = {}
    for cmd in commands:
        for k, w in enumerate(cmd):
            m = re.match(r"^(?:-c)?alias\.([^=\s]+)=(.*)\Z", w, re.S)
            if m:
                aliases[m.group(1).lower()] = m.group(2)
            elif re.match(r"^alias\.[^=\s]+\Z", w, re.I) and k + 1 < len(cmd) and "config" in cmd[:k]:
                aliases[w[6:].lower()] = cmd[k + 1]
    return aliases


def persisted_aliases():
    """git aliases already stored in the session's repo config: `git x` may
    be one (an alias stored by an earlier command runs here)."""
    out = {}
    try:
        import subprocess
        res = subprocess.run(["git", "-C", SESSION_CWD or os.getcwd(), "config", "--get-regexp", r"^alias\."],
                             capture_output=True, text=True, timeout=2).stdout
        for line in res.splitlines():
            key, _, val = line.partition(" ")
            out[key[6:].lower()] = val
    except Exception:
        pass
    return out


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
    """BLOCK-REMOTE <reason>, BLOCK <reason> or ALLOW. After a BLOCK the rest
    is still read, in case a remote delete (no override) is also there."""
    commands, strings, known, refs, spans = read(text, depth)
    raw = shell_scan(text)
    if depth == 0:
        if any(is_cmd(w, "git") or w.startswith("git-") for c in commands for w in c):
            ALIASES.update(persisted_aliases())
        ALIASES.update(collect_aliases(commands))
    plain = None
    # top[k]: command k is a plain command of `text` itself, not inside $( ),
    # backticks or ( ); commands read again from an unclosed quote are not.
    top = [k < len(spans) and spans[k][1] == depth for k in range(len(commands))]
    for cmd, is_top in zip(commands, top):
        found = check_command(cmd, depth, raw, is_top)
        if found and found.startswith("BLOCK-REMOTE "):
            return found
        plain = plain or found
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
        k = next((n for n, w in enumerate(cmd) if is_cmd(w, "gh")), None)
        if k is not None and cmd[k + 1:k + 3] == ["alias", "set"] and len(cmd) > k + 4:
            again.append("gh " + cmd[k + 4])      # gh alias set NAME 'api -X DELETE ...'
    # zsh glob qualifiers run code: *(e:'cmd':) / /tmp(e:'cmd':) (agentskel)
    for m in re.finditer(r"\(e([:'\"/|!+])(.*?)\1\)", text, re.S):
        again.append(m.group(2))
    if depth < REREAD_DEPTH:
        # What the text itself says a $( ) prints or a variable holds, filled
        # in (to a fixed point, branching on a loop variable) and read again:
        # `x=-f; rm -r $x y` is `rm -r -f y` (2026-11-09, 2026-11-10).
        for filled in resolve(text):
            if filled != text:
                again.append(filled)
    if again and depth >= REREAD_DEPTH:
        # Out of depth with text still to read: do not guess. The hook then
        # blocks any rm or covered git command in it (fail closed).
        raise TooComplex("quoted text nested too deep")
    for text_again in again:
        text_again = text_again.replace(PLACEHOLDER, " ")
        if text_again == text:
            continue        # reading it again would only repeat this level
        found = verdict(text_again, depth + 1)
        if found.startswith("BLOCK-REMOTE "):
            return found
        if found != "ALLOW":
            plain = plain or found
    return plain or "ALLOW"


def on_timeout(signum, frame):
    raise TooComplex("took too long")


def crash_flags(text):
    """After a crash: does the text plausibly name git or rm? Joins line
    continuations, decodes $'...', drops quoting and braces, and treats a
    command word's glob chars as wildcards (`g?t`, `r\\<newline>m`). Fails
    closed on any error (both). Over-flagging here only costs a block on input
    that already defeated the reader (second review of PR #167)."""
    try:
        t = re.sub(r"\\\n", "", text)                       # join line continuations
        t = re.sub(r"\$'(?:[^'\\]|\\.)*'", lambda m: Reader(m.group(0)).ansi_c(), t)
        t = re.sub(r"[\"'${}()`]", "", t).replace("\\", "")
        toks = re.split(r"[\s;&|]+", t)

        def names(tok):                 # the word and, after a wrapper path, its basename
            return (tok, tok.rsplit("/", 1)[-1])

        def found(target):
            for tok in toks:
                for nm in names(tok):
                    if target in nm:
                        return True
                    if any(c in nm for c in "*?[") and fnmatch.fnmatchcase(target, nm):
                        return True
            return False

        return (" GIT" if found("git") else "") + (" RM" if found("rm") else "")
    except Exception:
        return " GIT RM"


if __name__ == "__main__":
    data = sys.stdin.buffer.read().decode("utf-8", "replace")
    SESSION_CWD = os.environ.get("SAFETY_CWD", "")
    ELSEWHERE = bool(re.search(r"(^|[^A-Za-z0-9_])(cd|pushd|popd)([^A-Za-z0-9_]|$)|GIT_(DIR|WORK_TREE|COMMON_DIR)"
                               r"|--git-dir|--work-tree|git\s+(?:-c\s+\S+\s+|-\S+\s+)*-C\s", data, re.I))
    CREATES = bool(re.search(r"(checkout|switch)[^;&|\n]*\s-[A-Za-z]*[bBcC]|update-ref|fetch|pull|worktree"
                             r"|branch\s+(?:--?[A-Za-z-]*[tu][A-Za-z-]*\s+)*[^-\s]", data))
    try:
        signal.signal(signal.SIGALRM, on_timeout)
        signal.alarm(TIME_LIMIT)
        result = verdict(data)
        signal.alarm(0)
    except (TooComplex, RecursionError, Exception):
        signal.alarm(0)
        print("CRASH" + crash_flags(data))
        sys.exit(1)
    if result == "ALLOW" and PLAIN_DELETES[0]:
        # every delete here is the plain form: the hook's merged-branch check
        # must find exactly this many, or it blocks
        result = "ASK-DELETE %d" % PLAIN_DELETES[0]
    print(result)
