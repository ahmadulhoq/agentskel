#!/usr/bin/env bash
# Tests for pre-commit-check.sh (all four tool variants) and the shared
# check-skill-descriptions.py.
#
# Each variant is installed into a temp hooks dir the way setup-skeleton
# installs it (hook + checker side by side), then fed that tool's hook JSON
# (the hook runs in the session's folder, given as "cwd") against a throwaway
# repo. Superset of MCU-Watchlist PR #159's 25-case suite (TD-011).
#
# Usage: ./pre-commit-check.test.sh [claude|gemini|cursor|windsurf ...]
#        (no args = all four; exit 0 = all pass)
# Faults this guards against were reproduced on bash 5.2 / git 2.43 — run it
# there too (e.g. docker run --rm -v "$PWD":/w -w /w ubuntu:24.04 ...).
set -uo pipefail

CORE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$CORE/claude-hooks/check-skill-descriptions.py"
VARIANTS=("$@")
[ ${#VARIANTS[@]} -eq 0 ] && VARIANTS=(claude gemini cursor windsurf)

TMP=$(mktemp -d)
trap 'rm -r "$TMP"' EXIT
MAIN="$TMP/main"
WT="$TMP/other"
MEM="$MAIN/.memory"
PASS=0
FAIL=0

LONG=$(printf 'x%.0s' $(seq 1100))
L1024=$(printf 'x%.0s' $(seq 1024))
L600=$(printf 'x%.0s' $(seq 600))

g() { git -C "$1" "${@:2}" >/dev/null 2>&1; }
skill() { # dir relpath description-line(s)
    mkdir -p "$(dirname "$1/$2")"
    printf -- '---\nname: probe\ndescription: %s\n---\nbody\n' "$3" > "$1/$2"
}
clean() { # dir
    g "$1" reset -q --hard
    g "$1" clean -qfd
}

# Install each variant the way setup-skeleton does: hook + checker in one dir.
for v in "${VARIANTS[@]}"; do
    mkdir -p "$TMP/hooks-$v"
    cp "$CORE/$v-hooks/pre-commit-check.sh" "$TMP/hooks-$v/"
    [ -f "$CHECKER" ] && cp "$CHECKER" "$TMP/hooks-$v/"
done

# Tool-specific hook input. Mirrors each tool's documented stdin contract.
hook_json() { # variant cwd command
    python3 - "$1" "$2" "$3" <<'PY'
import json, sys
v, cwd, cmd = sys.argv[1:4]
if v == "cursor":
    d = {"command": cmd, "cwd": cwd}
elif v == "windsurf":
    d = {"agent_action_name": "pre_run_command", "tool_info": {"command_line": cmd, "cwd": cwd}}
elif v == "gemini":
    d = {"tool_name": "run_shell_command", "cwd": cwd, "tool_input": {"command": cmd}}
else:
    d = {"tool_name": "Bash", "cwd": cwd, "tool_input": {"command": cmd}}
print(json.dumps(d))
PY
}

# expect <BLOCK|ALLOW> <label> <session cwd> <command>
expect() {
    local want=$1 label=$2 cwd=$3 cmd=$4 v json out rc got
    for v in "${VARIANTS[@]}"; do
        json=$(hook_json "$v" "$cwd" "$cmd")
        out=$(cd "$cwd" && printf '%s' "$json" | bash "$TMP/hooks-$v/pre-commit-check.sh" 2>&1)
        rc=$?
        # Cursor blocks via exit 0 + {"permission":"deny"}; the others via exit 2.
        if [ "$rc" = 2 ] || { [ "$v" = cursor ] && printf '%s' "$out" | grep -q '"permission": *"deny"'; }; then
            got=BLOCK
        else
            got=ALLOW
        fi
        if [ "$got" = "$want" ]; then
            PASS=$((PASS + 1))
        else
            FAIL=$((FAIL + 1)); echo "FAIL [$v: $got, want $want] $label ${out:+-> ${out:0:200}}"
        fi
    done
}

git init -q -b main "$MAIN"
g "$MAIN" config user.email t@example.com
g "$MAIN" config user.name t
printf '.memory\n' > "$MAIN/.gitignore"
skill "$MAIN" .agents/skills/tracked/SKILL.md "short"
echo readme > "$MAIN/notes.txt"
g "$MAIN" add -A
g "$MAIN" commit -q -m init
g "$MAIN" worktree add -q "$WT" -b other
# A real downstream main checkout: .memory/ mounted as a worktree on ai-memory.
g "$MAIN" worktree add -q "$MEM" -b ai-memory

S=.agents/skills/probe/SKILL.md

echo "== staged commits read the staged version"
echo x >> "$MAIN/notes.txt"; g "$MAIN" add notes.txt
expect ALLOW "harmless staged change" "$MAIN" 'git commit -m "probe"'
clean "$MAIN"
skill "$MAIN" $S "$LONG"; g "$MAIN" add $S
expect BLOCK "1100-char description staged" "$MAIN" 'git commit -m "probe"'
skill "$MAIN" $S "short"
expect BLOCK "long staged, shortened on disk only (commit records long)" "$MAIN" 'git commit -m "probe"'
clean "$MAIN"
skill "$MAIN" $S "short"; g "$MAIN" add $S; skill "$MAIN" $S "$LONG"
expect ALLOW "short staged, long on disk only (commit records short)" "$MAIN" 'git commit -m "probe"'
clean "$MAIN"
skill "$MAIN" $S "$(printf '>\n  %s\n  %s' "$L600" "$L600")"; g "$MAIN" add $S
expect BLOCK "folded > description, 1201 chars" "$MAIN" 'git commit -m "probe"'
clean "$MAIN"
skill "$MAIN" $S "$(printf '>\n  %s' "short folded text")"; g "$MAIN" add $S
expect ALLOW "short folded > description is valid (not a multi-line error)" "$MAIN" 'git commit -m "probe"'
clean "$MAIN"
skill "$MAIN" $S "$L1024"; g "$MAIN" add $S
expect ALLOW "exactly 1024 chars" "$MAIN" 'git commit -m "probe"'
clean "$MAIN"
skill "$MAIN" ".agents/skills/café/SKILL.md" "$LONG"; g "$MAIN" add -A
expect BLOCK "non-ASCII folder name" "$MAIN" 'git commit -m "probe"'
clean "$MAIN"
skill "$MAIN" $S "$LONG"; mkdir -p "$MAIN/.agents/skills/bad"
printf -- '---\nname: q\ndescription: \xff\xfe\n---\n' > "$MAIN/.agents/skills/bad/SKILL.md"
g "$MAIN" add -A
expect BLOCK "an unreadable (non-UTF-8) skill does not switch the check off" "$MAIN" 'git commit -m "probe"'
clean "$MAIN"
skill "$MAIN" ".agents/workflows/long.md" "$LONG"; g "$MAIN" add -A
expect BLOCK "workflow file, not just SKILL.md" "$MAIN" 'git commit -m "probe"'
clean "$MAIN"

echo "== commit forms that take files from disk"
skill "$MAIN" .agents/skills/tracked/SKILL.md "$LONG"
expect BLOCK "git commit -a, change never staged" "$MAIN" 'git commit -a -m "probe"'
expect BLOCK "git commit -am" "$MAIN" 'git commit -am "probe"'
expect BLOCK "git commit -m x <path>" "$MAIN" 'git commit -m "probe" .agents/skills/tracked/SKILL.md'
expect ALLOW "git commit -m x <other path> (skill not in the commit)" "$MAIN" 'git commit -m "probe" -- notes.txt'
clean "$MAIN"
skill "$MAIN" $S "$LONG"; g "$MAIN" add -N $S
expect BLOCK "add -N + commit -- <path>" "$MAIN" "git commit -m \"probe\" -- $S"
clean "$MAIN"
skill "$MAIN" $S "$LONG"; g "$MAIN" add $S
expect ALLOW "--only <other path> leaves the staged skill out" "$MAIN" 'git commit -m "probe" -- notes.txt'
expect BLOCK "--include <other path> keeps the staged skill in" "$MAIN" 'git commit -i -m "probe" -- notes.txt'
expect BLOCK "--amend still gets the description check" "$MAIN" 'git commit --amend --no-edit'
clean "$MAIN"

echo "== the commit runs in another checkout than the session's folder"
skill "$WT" $S "$LONG"; g "$WT" add $S
expect BLOCK "cd <other> && git commit" "$MAIN" "cd $WT && git commit -m \"probe\""
expect BLOCK "git -C <other> commit" "$MAIN" "git -C $WT commit -m \"probe\""
expect BLOCK "session already in <other>" "$WT" 'git commit -m "probe"'
expect ALLOW "session in <other>, cd <main> && git commit (main is clean)" "$WT" "cd $MAIN && git commit -m \"probe\""
clean "$WT"

echo "== memory branch (fault 7: skip is about the target checkout, not .memory existing)"
skill "$MAIN" $S "$LONG"; g "$MAIN" add $S
expect BLOCK "main checkout with .memory mounted on ai-memory is still checked" "$MAIN" 'git commit -m "probe"'
clean "$MAIN"
skill "$MEM" $S "$LONG"; g "$MEM" add $S
expect ALLOW "commit in the ai-memory checkout (cd .memory) is skipped" "$MAIN" 'cd .memory && git commit -m "agent: x"'
expect ALLOW "commit in the ai-memory checkout (git -C .memory) is skipped" "$MAIN" 'git -C .memory commit -m "agent: x"'
clean "$MEM"

echo "== CHANGELOG/TIME_LOG gate removed (v1.68.0)"
echo x >> "$MAIN/notes.txt"; g "$MAIN" add notes.txt
expect ALLOW "first code commit of a task, logs not yet written" "$MAIN" 'git commit -m "feat: code first"'
clean "$MAIN"

echo "== shell parsing"
skill "$MAIN" $S "$LONG"; g "$MAIN" add $S
expect BLOCK "output redirected and piped (2>&1 | tail)" "$MAIN" 'git commit -m "probe" 2>&1 | tail -1'
expect BLOCK "heredoc message with quotes and &&" "$MAIN" "$(printf 'git commit -F - <<%sEOF%s\nit%ss done && cd /tmp\nEOF' "'" "'" "'")"
expect BLOCK "unparseable shell falls back to the session folder" "$MAIN" "git commit -m \"unbalanced"
expect BLOCK "message text mentioning .memory does not skip the check" "$MAIN" 'git commit -m "fix .memory mount"'
expect ALLOW "git log --grep commit is not a commit" "$MAIN" 'git log --grep commit'
expect ALLOW "git status is not a commit" "$MAIN" 'git status'
expect ALLOW "git commit-tree is not git commit" "$MAIN" 'git commit-tree HEAD^{tree} -m x'
clean "$MAIN"

echo "== fail-open"
skill "$MAIN" $S "$LONG"; g "$MAIN" add $S
for v in "${VARIANTS[@]}"; do mv "$TMP/hooks-$v/check-skill-descriptions.py" "$TMP/hooks-$v/.x" 2>/dev/null || true; done
expect ALLOW "checker missing lets the commit through" "$MAIN" 'git commit -m "probe"'
for v in "${VARIANTS[@]}"; do mv "$TMP/hooks-$v/.x" "$TMP/hooks-$v/check-skill-descriptions.py" 2>/dev/null || true; done
clean "$MAIN"

echo "== triggers: each tool's config must route these commands to the hook"
# A hook that is never called fails silently: pre-v1.68.0 `Bash(git commit*)`
# never matched `git -C <dir> commit`. Claude's `if` is a glob over the Bash
# command (approximated with fnmatch); Cursor's and Windsurf's are regexes.
TRIG_OUT=$(python3 - "$CORE" <<'PY'
import fnmatch, json, re, sys
core = sys.argv[1]
cmds = ['git commit -m "x"', 'git -C /some/dir commit -m "x"', 'git -c user.name=a commit -am "x"']
regex_only = ['cd /some/dir && git commit -m "x"']
bad = []
claude = json.load(open(f"{core}/claude-hooks/settings.json"))
pats = [h["if"][5:-1] for e in claude["hooks"]["PreToolUse"] for h in e["hooks"]
        if h["command"].endswith("pre-commit-check.sh") and "if" in h]
for c in cmds:
    if pats and not any(fnmatch.fnmatchcase(c, p) for p in pats):
        bad.append(f"claude if={pats} misses: {c}")
for tool, event in (("cursor", "beforeShellExecution"), ("windsurf", "pre_run_command")):
    cfg = json.load(open(f"{core}/{tool}-hooks/hooks.json"))
    m = [h.get("matcher") for h in cfg["hooks"][event] if h["command"].endswith("pre-commit-check.sh")][0]
    for c in cmds + regex_only:
        if not re.search(m.replace("[[:space:]]", r"\s").replace("[:space:]", r"\s"), c):
            bad.append(f"{tool} matcher {m!r} misses: {c}")
print("\n".join(bad))
PY
)
if [ -z "$TRIG_OUT" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL triggers:"; echo "$TRIG_OUT"; fi

echo
echo "${VARIANTS[*]}: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
