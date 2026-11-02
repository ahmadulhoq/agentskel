#!/usr/bin/env python3
"""Block a `git commit` whose skill/workflow descriptions exceed 1024 chars.

Called by every tool's pre-commit-check.sh with that tool's hook JSON in
$HOOK_INPUT. Exit 2 + message on stderr = block; exit 0 = allow. The hooks
treat any other exit (python missing, a crash) as allow: fail-open.

Accepted input shapes (command, session folder):
- Claude Code, Codex, Gemini CLI: tool_input.command, cwd
- Cursor:                         command, cwd
- Windsurf:                       tool_info.command_line, tool_info.cwd

It checks the content the commit will actually record, in the checkout the
commit actually runs in (agentskel v1.68.0; first fixed downstream in
MCU-Watchlist PR #159, TD-011):

- Target checkout: the hook runs in the session's folder, so the command is
  parsed for `cd X` and `git -C X`, starting from the JSON's `cwd`.
- Content: staged commits read the staged version (`git show :path`), not
  the file on disk. `git commit -a` and `git commit [--only|-o] <paths>`
  read the working tree, because that is what those forms commit.
  `--include/-i <paths>` reads both. Intent-to-add files (`git add -N`)
  are covered by the path forms.
- Commits whose checkout is on the ai-memory branch are skipped.

agentskills.io spec limit: 1024 chars. Multi-line YAML block scalars
(`description: >`) are joined into one string before measuring.
"""
import json
import os
import re
import shlex
import subprocess
import sys

LIMIT = 1024
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
SEPARATORS = {"&&", "||", ";", "|", "&", "\n", "(", ")", ";;", "|&"}
# git global options that take a value as the next token.
GIT_GLOBAL_WITH_VALUE = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--exec-path"}
# `git commit` options that take a value as the next token (when not `--opt=value`).
COMMIT_LONG_WITH_VALUE = {
    "--message", "--file", "--reuse-message", "--reedit-message", "--template",
    "--author", "--date", "--cleanup", "--fixup", "--squash", "--trailer",
    "--pathspec-from-file", "--untracked-files",
}
COMMIT_SHORT_WITH_VALUE = set("mFCct")


def extract_desc(fm_block):
    m = re.search(r"^description:[ \t]*(.*)", fm_block, re.MULTILINE)
    if not m:
        return None
    first = m.group(1).rstrip()
    if first in (">", "|", ">-", "|-", ">+", "|+", ""):
        content = []
        # [1:] skips the rest of the `description: >` line itself (always empty).
        for line in fm_block[m.end():].split("\n")[1:]:
            if line and line[:1] in (" ", "\t"):
                content.append(line.strip())
            else:
                break
        joined = " ".join(content).strip()
        return joined or None
    return first.strip() or None


def is_skill_file(path):
    return path.endswith(".md") and (path.endswith("/SKILL.md") or "/workflows/" in path)


def git(args, cwd):
    return subprocess.run(["git", "-C", cwd, *args], capture_output=True)


def strip_heredoc_bodies(command):
    """Drop heredoc bodies so commit-message text is never parsed as shell."""
    lines = command.split("\n")
    out, i = [], 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        delims = re.findall(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", line)
        i += 1
        for _, delim in delims:
            while i < len(lines) and lines[i].strip() != delim:
                i += 1
            i += 1  # skip the delimiter line
    return "\n".join(out)


def simple_commands(command):
    lex = shlex.shlex(strip_heredoc_bodies(command), posix=True, punctuation_chars=True)
    lex.whitespace_split = True
    lex.commenters = ""
    tokens = list(lex)
    cmds, cur = [], []
    skip_next = False
    for tok in tokens:
        if skip_next:
            skip_next = False
            continue
        if tok in SEPARATORS:
            if cur:
                cmds.append(cur)
            cur = []
            continue
        if re.fullmatch(r"[<>]+&?|&>>?|>\|", tok):  # redirection: drop it, its target and an fd number
            if cur and cur[-1].isdigit():
                cur.pop()
            skip_next = True
            continue
        cur.append(tok)
    if cur:
        cmds.append(cur)
    return cmds


def resolve(base, path):
    path = os.path.expanduser(path)
    return os.path.normpath(path if os.path.isabs(path) else os.path.join(base, path))


def find_commits(command, start_dir):
    """Yield (directory, commit_args) for every `git commit` in the command."""
    cwd = start_dir
    for words in simple_commands(command):
        while words and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*=.*", words[0]):
            words = words[1:]  # VAR=value prefixes
        if not words:
            continue
        if words[0] == "cd":
            target = next((w for w in words[1:] if not w.startswith("-")), "~")
            cwd = resolve(cwd, target)
            continue
        if words[0] != "git":
            continue
        gdir, i = cwd, 1
        while i < len(words) and words[i].startswith("-"):
            opt = words[i]
            if opt == "-C" and i + 1 < len(words):
                gdir = resolve(gdir, words[i + 1])
            if opt in GIT_GLOBAL_WITH_VALUE:
                i += 2
            else:
                i += 1
        if i < len(words) and words[i] == "commit":
            yield gdir, words[i + 1:]


def parse_commit_args(args):
    mode = {"all": False, "include": False, "pathspec_file": False, "paths": []}
    i, after_dashdash = 0, False
    while i < len(args):
        a = args[i]
        if after_dashdash or not a.startswith("-") or a == "-":
            mode["paths"].append(a)
        elif a == "--":
            after_dashdash = True
        elif a.startswith("--"):
            name = a.split("=", 1)[0]
            if name == "--all":
                mode["all"] = True
            elif name == "--include":
                mode["include"] = True
            elif name == "--pathspec-from-file":
                mode["pathspec_file"] = True
            if name in COMMIT_LONG_WITH_VALUE and "=" not in a:
                i += 1
        else:  # short option cluster, e.g. -am "msg"
            for j, ch in enumerate(a[1:], start=1):
                if ch == "a":
                    mode["all"] = True
                elif ch == "i":
                    mode["include"] = True
                if ch in COMMIT_SHORT_WITH_VALUE:
                    if j == len(a) - 1:
                        i += 1  # value is the next token
                    break  # rest of the token is the value
        i += 1
    return mode


def names(result):
    return [n.decode("utf-8", "replace") for n in result.stdout.split(b"\0") if n]


def check_commit(directory, args, session_dir):
    if not os.path.isdir(directory):
        return []
    top = git(["rev-parse", "--show-toplevel"], directory)
    if top.returncode != 0:
        return []
    top = top.stdout.decode().strip()
    if git(["branch", "--show-current"], top).stdout.decode().strip() == "ai-memory":
        return []
    base = "HEAD" if git(["rev-parse", "--verify", "-q", "HEAD"], top).returncode == 0 else EMPTY_TREE
    mode = parse_commit_args(args)
    st = git(["rev-parse", "--show-toplevel"], session_dir) if os.path.isdir(session_dir) else None
    session_top = st.stdout.decode().strip() if st is not None and st.returncode == 0 else session_dir

    # (path relative to top, read from "index" or "worktree")
    targets = {}
    if mode["paths"] and not mode["include"]:
        # --only (the default with paths): those paths, as they are on disk.
        for n in names(git(["diff", "--name-only", "-z", base, "--", *mode["paths"]], directory)):
            targets[n] = "worktree"
    elif mode["all"] or mode["pathspec_file"]:
        for n in names(git(["diff", "--name-only", "-z", base], top)):
            targets[n] = "worktree"
    else:
        for n in names(git(["diff", "--cached", "--name-only", "-z", base], top)):
            targets[n] = "index"
        if mode["include"] and mode["paths"]:
            for n in names(git(["diff", "--name-only", "-z", base, "--", *mode["paths"]], directory)):
                targets[n] = "worktree"

    bad = []
    for path, source in sorted(targets.items()):
        if not is_skill_file(path):
            continue
        if source == "index":
            blob = git(["show", f":{path}"], top)
            if blob.returncode != 0:
                continue  # deleted in the index
            raw = blob.stdout
        else:
            full = os.path.join(top, path)
            if not os.path.isfile(full):
                continue
            with open(full, "rb") as f:
                raw = f.read()
        fm = FM_RE.match(raw.decode("utf-8", "replace"))
        if not fm:
            continue
        desc = extract_desc(fm.group(1))
        if desc and len(desc) > LIMIT:
            # Full path when the commit is in another checkout than the session's.
            same = os.path.realpath(top) == os.path.realpath(session_top)
            shown = path if same else os.path.join(top, path)
            bad.append(f"{shown} ({len(desc)} chars)")
    return bad


def hook_fields(data):
    """(command, session folder) from any supported tool's hook JSON."""
    tool_input = data.get("tool_input") or {}
    tool_info = data.get("tool_info") or {}
    command = tool_input.get("command") or data.get("command") or tool_info.get("command_line") or ""
    cwd = data.get("cwd") or tool_info.get("cwd") or os.getcwd()
    return command, os.path.normpath(cwd)


def main():
    data = json.loads(os.environ.get("HOOK_INPUT") or "{}")
    command, start = hook_fields(data)
    try:
        commits = list(find_commits(command, start))
    except ValueError:
        # Unparseable shell (e.g. unbalanced quotes): check a plain commit here.
        commits = [(start, [])]
    bad = []
    for directory, args in commits:
        for b in check_commit(directory, args, start):
            if b not in bad:
                bad.append(b)
    if bad:
        print(
            f"Description exceeds {LIMIT}-char limit in: {'; '.join(bad)}. "
            "Shorten or split the skill scope. Fix before committing.",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
