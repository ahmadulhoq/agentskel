#!/usr/bin/env bash
# Tests for pre-bash-safety.sh.
#
# This hook is the ONLY thing standing between a broad permissions.allow glob
# and an irreversible command. `Bash(git push *)` matches `git push --force`;
# `Bash(gh api *)` used to match `gh api -X DELETE /repos/:owner/:repo`, which
# deletes the repository. The rules are regexes, which rot silently and fail
# OPEN — a broken pattern does not error, it just stops blocking.
#
# So both halves are asserted: destructive commands are blocked, AND everyday
# commands still run. A hook that blocks everything is as useless as one that
# blocks nothing, and only the first kind gets noticed.
#
# Usage: ./pre-bash-safety.test.sh    (exit 0 = all pass)
set -uo pipefail
HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/pre-bash-safety.sh"
pass=0; fail=0

check() { # check <BLOCKED|ALLOWED> <command>
  local want="$1" cmd="$2" got code
  printf '%s' "$cmd" | python3 -c \
    'import json,sys; print(json.dumps({"tool_input":{"command":sys.stdin.read()}}))' \
    | "$HOOK" >/dev/null 2>&1
  code=$?
  [ "$code" = "2" ] && got=BLOCKED || got=ALLOWED
  if [ "$got" = "$want" ]; then pass=$((pass+1));
  else fail=$((fail+1)); printf 'FAIL  expected %-7s got %-7s : %s\n' "$want" "$got" "$cmd"; fi
}

# --- must block: irreversible ---
check BLOCKED 'git push --force origin main'
check BLOCKED 'git push -f'
check BLOCKED 'git push --force-with-lease origin main'
check BLOCKED 'git reset --hard HEAD~1'
check BLOCKED 'git branch -D feature/x'
check BLOCKED 'git checkout -- src/file.ts'
check BLOCKED 'git checkout .'
check BLOCKED 'git clean -fd'
check BLOCKED 'rm -rf /tmp/x'
check BLOCKED 'git worktree remove --force wt'
# regression: destruction the allowlist permitted but nothing checked
check BLOCKED 'gh api -X DELETE /repos/o/r'
check BLOCKED 'gh api --method DELETE /repos/o/r/branches/main/protection'
check BLOCKED 'gh api -X POST /repos/o/r/issues'
check BLOCKED 'git push origin :main'
check BLOCKED 'git push --delete origin main'
check BLOCKED 'git checkout -f'
check BLOCKED 'git stash drop'
check BLOCKED 'git stash clear'
check BLOCKED 'find . -name "*.kt" -delete'
check BLOCKED 'find . -type f -exec rm {} \;'
# regression: prefixes and flag spellings that bypassed every rule
check BLOCKED 'git -C /other/repo push --force origin main'
check BLOCKED 'git -C /other/repo reset --hard'
check BLOCKED 'rm -r -f /tmp/x'
check BLOCKED 'rm --recursive --force /tmp/x'
# compound commands must not hide the payload
check BLOCKED 'echo hi && rm -rf /tmp/x'
check BLOCKED 'cd /tmp; git reset --hard'

# --- must allow: ordinary work. A hook nobody can work alongside gets removed. ---
check ALLOWED 'git push origin main'
check ALLOWED 'git checkout -b feature/new'
check ALLOWED 'git checkout main'
check ALLOWED 'git stash'
check ALLOWED 'git stash pop'
check ALLOWED 'git stash list'
check ALLOWED 'gh api /repos/o/r/pulls/52'
check ALLOWED 'gh api --method GET /repos/o/r'
check ALLOWED 'find . -name "*.kt"'
check ALLOWED 'rm /tmp/one-file.txt'
check ALLOWED 'git log --oneline -5'
check ALLOWED 'git commit -m "mention reset --hard and rm -rf in the message"'
check ALLOWED 'git commit -m "force push was avoided"'

# --- remote branch delete: ASK only for fully merged branches (v1.68.0) ---
# "ask" hands the decision to Claude Code's own approval prompt, which only the
# user can answer. Everything that could lose commits stays BLOCKED.
check_in() { # check_in <BLOCKED|ALLOWED|ASKED> <session cwd> <command>
  local want="$1" cwd="$2" cmd="$3" got out code
  out=$(cd "$cwd" && python3 -c \
    'import json,sys; print(json.dumps({"cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' \
    "$cwd" "$cmd" | "$HOOK" 2>/dev/null)
  code=$?
  if [ "$code" = 2 ]; then got=BLOCKED
  elif printf '%s' "$out" | grep -q '"permissionDecision": "ask"'; then got=ASKED
  else got=ALLOWED; fi
  if [ "$got" = "$want" ]; then pass=$((pass+1));
  else fail=$((fail+1)); printf 'FAIL  expected %-7s got %-7s : %s\n' "$want" "$got" "$cmd"; fi
}

TMP=$(mktemp -d); trap 'rm -r "$TMP"' EXIT
gq() { git -C "$1" "${@:2}" >/dev/null 2>&1; }
git init -q --bare -b main "$TMP/origin.git"
git clone -q "$TMP/origin.git" "$TMP/repo" 2>/dev/null
R="$TMP/repo"
gq "$R" config user.email t@example.com; gq "$R" config user.name t
echo a > "$R/a"; gq "$R" add a; gq "$R" commit -m init; gq "$R" push origin main
for b in merged-a merged-b; do                       # merged via a real merge
  gq "$R" checkout -b "$b" main; echo "$b" > "$R/$b"; gq "$R" add -A; gq "$R" commit -m "$b"
  gq "$R" push origin "$b"; gq "$R" checkout main; gq "$R" merge --no-ff "$b" -m "merge $b"
done
gq "$R" checkout -b unmerged main; echo u > "$R/u"; gq "$R" add -A; gq "$R" commit -m u
gq "$R" push origin unmerged; gq "$R" checkout main
gq "$R" checkout -b squashed main; echo s > "$R/s"; gq "$R" add -A; gq "$R" commit -m s
gq "$R" push origin squashed; gq "$R" checkout main
gq "$R" merge --squash squashed; gq "$R" commit -m "squash squashed"
gq "$R" push origin main; gq "$R" push origin main:ai-memory

check_in ASKED   "$R" 'git push origin --delete merged-a'
check_in ASKED   "$R" 'git push --delete origin merged-a merged-b'
check_in ASKED   "$R" 'git push origin -d merged-b'
check_in ASKED   "$R" 'git push origin --delete merged-a && git remote prune origin'
check_in BLOCKED "$R" 'git push origin --delete unmerged'
check_in BLOCKED "$R" 'git push origin --delete merged-a unmerged'
check_in BLOCKED "$R" 'git push origin --delete squashed'
check_in BLOCKED "$R" 'git push origin --delete main'
check_in BLOCKED "$R" 'git push origin --delete ai-memory'
check_in BLOCKED "$R" 'git push origin --delete no-such-branch'
check_in BLOCKED "$R" 'git push origin :merged-a'
check_in BLOCKED "$R" "git -C $R push origin --delete merged-a"
check_in BLOCKED "$R" "cd $R && git push origin --delete merged-a"
check_in BLOCKED "$R" 'git push --force origin --delete merged-a'
check_in BLOCKED "$R" 'git push nowhere --delete merged-a'
# a block rule elsewhere in the command still wins over the ask
check_in BLOCKED "$R" 'git push origin --delete merged-a && rm -rf /tmp/x'
check_in BLOCKED "$R" 'git push origin --delete merged-a; git reset --hard'
# message text mentioning --delete is not a delete
check_in ALLOWED "$R" 'git commit -m "push --delete was considered"'
# a plain push chained with an unrelated -d / --delete flag is not a delete
check_in ALLOWED "$R" 'git push origin main && date -d tomorrow'
check_in ALLOWED "$R" 'git push origin main && ls -d */'
check_in ALLOWED "$R" 'git push -u origin main 2>&1 | grep -d skip x'
# quoting the flag does not hide the delete (pre-v1.68.0 regex missed this)
check_in ASKED   "$R" 'git push origin "--delete" merged-a'
check_in BLOCKED "$R" "git push origin '-d' unmerged"
# a delete inside a nested command string cannot be inspected: blocked
check_in BLOCKED "$R" 'echo x && git push origin main; sh -c "git push origin --delete merged-a"'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
