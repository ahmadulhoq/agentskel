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

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
