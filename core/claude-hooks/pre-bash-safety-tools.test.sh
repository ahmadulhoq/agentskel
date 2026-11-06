#!/usr/bin/env bash
# Tests for the other tools' pre-bash-safety wrappers (v1.69.0):
# core/{gemini,cursor,windsurf,codex}-hooks/pre-bash-safety.sh.
#
# The rules themselves are tested by pre-bash-safety.test.sh. This suite
# tests what each wrapper adds: it is installed the way setup-skeleton
# installs it (wrapper + pre-bash-safety-engine.sh + the two helpers in one
# folder), fed that tool's own hook JSON, and its answer is read in that
# tool's own output contract. A wrapper that mangles the input, prints the
# wrong JSON, or turns a merged-branch "ask" into an allow fails here.
#
# Usage: bash pre-bash-safety-tools.test.sh [tool ...]   (exit 0 = all pass)
#   The full rule suite also runs through the Gemini / Codex wrappers, which
#   take Claude-shaped JSON:
#   EXPECT_NO_ASK=1 bash pre-bash-safety.test.sh <installed wrapper>
set -uo pipefail

CORE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS=("$@")
[ ${#TOOLS[@]} -eq 0 ] && TOOLS=(gemini cursor windsurf codex)
TMP=$(mktemp -d)
trap 'rm -r "$TMP"' EXIT
pass=0; fail=0

for t in "${TOOLS[@]}"; do
    mkdir -p "$TMP/$t"
    cp "$CORE/$t-hooks/pre-bash-safety.sh" "$TMP/$t/pre-bash-safety.sh"
    cp "$CORE/claude-hooks/pre-bash-safety.sh" "$TMP/$t/pre-bash-safety-engine.sh"
    cp "$CORE/claude-hooks/pre-bash-heredocs.py" "$CORE/claude-hooks/pre-bash-commands.py" "$TMP/$t/"
done

hook_json() { # tool cwd command
    python3 - "$1" "$2" "$3" <<'PY'
import json, sys
t, cwd, cmd = sys.argv[1:4]
if t == "cursor":
    d = {"command": cmd, "cwd": cwd}
elif t == "windsurf":
    d = {"agent_action_name": "pre_run_command", "tool_info": {"command_line": cmd, "cwd": cwd}}
elif t == "gemini":
    d = {"tool_name": "run_shell_command", "cwd": cwd, "tool_input": {"command": cmd}}
else:
    d = {"tool_name": "Bash", "cwd": cwd, "tool_input": {"command": cmd}}
print(json.dumps(d))
PY
}

# Classify one run in the tool's own contract. Anything outside the contract
# (stray stdout for Gemini, invalid JSON for Cursor) is BAD, never ALLOW.
classify() { # tool rc stdout
    local t=$1 rc=$2 out=$3
    case "$t" in
        cursor)
            python3 -c '
import json, sys
try:
    d = json.loads(sys.argv[1])
except Exception:
    print("BAD"); raise SystemExit
p = d.get("permission")
print({"deny": "BLOCK", "allow": "ALLOW"}.get(p, "BAD"))' "$out" ;;
        gemini)
            if [ "$rc" = 2 ] && [ -z "$out" ]; then echo BLOCK
            elif [ "$rc" = 0 ] && [ "$out" = '{"decision":"allow"}' ]; then echo ALLOW
            else echo BAD; fi ;;
        *)
            if [ "$rc" = 2 ] && [ -z "$out" ]; then echo BLOCK
            elif [ "$rc" = 0 ] && [ -z "$out" ]; then echo ALLOW
            else echo BAD; fi ;;
    esac
}

expect() { # <BLOCK|ALLOW> <label> <cwd> <command> [hooks dir override]
    local want=$1 label=$2 cwd=$3 cmd=$4 t out rc got dir
    for t in "${TOOLS[@]}"; do
        dir=${5:-$TMP/$t}
        out=$(cd "$cwd" && hook_json "$t" "$cwd" "$cmd" | bash "$dir/pre-bash-safety.sh" 2>/dev/null)
        rc=$?
        got=$(classify "$t" "$rc" "$out")
        if [ "$got" = "$want" ]; then pass=$((pass + 1))
        else fail=$((fail + 1)); echo "FAIL [$t: $got, want $want] $label ${out:+-> ${out:0:160}}"; fi
    done
}

R0="$TMP"
echo "== rules reach every tool"
expect BLOCK "rm -rf"                                  "$R0" 'rm -rf build'
expect ALLOW "hyphenated filename (the bug MCU-Watchlist fixed)" "$R0" 'rm src/data/the-fantastic-four-first-steps.json'
expect BLOCK "git reset --hard"                        "$R0" 'git reset --hard HEAD~1'
expect BLOCK "global option before the subcommand"     "$R0" 'git --no-pager reset --hard'
expect BLOCK "force push"                              "$R0" 'git push --force origin main'
expect BLOCK "+refspec force push"                     "$R0" 'git push origin +main'
expect BLOCK "gh api DELETE"                           "$R0" 'gh api -X DELETE /repos/o/r'
expect BLOCK "rm inside bash -c"                       "$R0" 'bash -c "rm -rf x"'
expect ALLOW "git status"                              "$R0" 'git status'
expect ALLOW "plain push"                              "$R0" 'git push origin main'
expect ALLOW "non-ASCII message"                       "$R0" 'git commit -m "café — ok"'
expect ALLOW "commit -F - heredoc mentioning a blocked command" "$R0" "$(printf 'git commit -F - <<'"'"'EOF'"'"'\nnever run git reset --hard\nEOF')"
echo "== the override, and the block message survives each contract"
expect ALLOW "AGENTSKEL_UNSAFE as the first word"      "$R0" 'AGENTSKEL_UNSAFE=i-understand git reset --hard HEAD~1'
expect BLOCK "AGENTSKEL_UNSAFE not first"              "$R0" 'echo AGENTSKEL_UNSAFE=i-understand; git reset --hard'
expect BLOCK "quotes and a backslash in the command"   "$R0" "git reset --hard \"it's \\\"quoted\\\"\" \\\\x"

echo "== remote branch deletes: merged is BLOCKED here (no ask outside Claude Code)"
gq() { git -C "$1" "${@:2}" >/dev/null 2>&1; }
git init -q --bare -b main "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/repo" 2>/dev/null
R="$TMP/repo"
gq "$R" config user.email t@example.com; gq "$R" config user.name t
echo a > "$R/a"; gq "$R" add a; gq "$R" commit -m init; gq "$R" push origin main
gq "$R" checkout -b merged main; echo m > "$R/m"; gq "$R" add -A; gq "$R" commit -m m
gq "$R" push origin merged; gq "$R" checkout main; gq "$R" merge --no-ff merged -m "merge"
gq "$R" push origin main
expect BLOCK "merged remote delete (Claude would ask)"  "$R" 'git push origin --delete merged'
expect BLOCK "merged delete + override (never for remote deletes)" "$R" 'AGENTSKEL_UNSAFE=i-understand git push origin --delete merged'
expect BLOCK "protected remote delete"                 "$R" 'git push origin --delete main'
expect ALLOW "plain push in the repo"                  "$R" 'git push origin main'

echo "== a broken install blocks loudly instead of turning off"
for t in "${TOOLS[@]}"; do
    mkdir -p "$TMP/broken-$t"; cp "$CORE/$t-hooks/pre-bash-safety.sh" "$TMP/broken-$t/"
done
for t in "${TOOLS[@]}"; do
    out=$(cd "$R0" && hook_json "$t" "$R0" 'git status' | bash "$TMP/broken-$t/pre-bash-safety.sh" 2>/dev/null); rc=$?
    got=$(classify "$t" "$rc" "$out")
    if [ "$got" = BLOCK ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL [$t: $got, want BLOCK] engine missing"; fi
done

echo "== each tool's config runs the wrapper first on every shell command"
WIRE=$(python3 - "$CORE" "${TOOLS[@]}" <<'PY'
import json, sys
core, tools = sys.argv[1], sys.argv[2:]
bad = []
for t in tools:
    if t == "gemini":
        d = json.load(open(f"{core}/gemini-hooks/settings.json"))
        hooks = [h for e in d["hooks"]["BeforeTool"] if e.get("matcher") == "run_shell_command" for h in e["hooks"]]
    elif t == "codex":
        d = json.load(open(f"{core}/codex-hooks/hooks.json"))
        hooks = [h for e in d["hooks"]["PreToolUse"] if e.get("matcher") == "Bash" for h in e["hooks"]]
    else:
        event = {"cursor": "beforeShellExecution", "windsurf": "pre_run_command"}[t]
        hooks = json.load(open(f"{core}/{t}-hooks/hooks.json"))["hooks"][event]
    first = hooks[0] if hooks else {}
    if not first.get("command", "").endswith(f".{t}/hooks/pre-bash-safety.sh"):
        bad.append(f"{t}: first shell hook is {first.get('command')!r}")
    if first.get("matcher"):
        bad.append(f"{t}: pre-bash-safety.sh has a matcher ({first['matcher']!r}); it must see every command")
print("\n".join(bad))
PY
)
if [ -z "$WIRE" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL wiring:"; echo "$WIRE"; fi

echo
echo "${TOOLS[*]}: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
