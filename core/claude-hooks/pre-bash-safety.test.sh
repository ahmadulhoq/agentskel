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
# Usage: bash pre-bash-safety.test.sh [path/to/pre-bash-safety.sh]
#        (exit 0 = all pass). With no argument it tests the copy next to this
#        file. sync-skeleton passes the INSTALLED hook: a suite that only
#        tests the skeleton's own copy passes after a bad overwrite and cannot
#        catch one (MCU-Watchlist repo rules, 2026-11-02).
#
# v1.69.0: upstreamed from MCU-Watchlist (PRs #164, #165), where these cases
# were developed over five rounds of independent adversarial review. Every
# case below closed a real bug; do not delete one to make a change pass.
set -uo pipefail
HOOK="${1:-$(dirname "${BASH_SOURCE[0]}")/pre-bash-safety.sh}"
# Absolute, so the remote-delete cases (which cd into a temp repo) still find
# it when a relative path is passed.
HOOK="$(cd "$(dirname "$HOOK")" && pwd)/$(basename "$HOOK")"
[ -x "$HOOK" ] || { echo "not an executable hook: $HOOK" >&2; exit 2; }
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
# a quoted method is the same method (second review of PR #164)
check BLOCKED 'gh api --method GET /repos/o/r --method "DELETE"'
check BLOCKED "gh api -X 'DELETE' /repos/o/r"
check BLOCKED 'gh api --method="PATCH" /repos/o/r'
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
# --- v1.69.0: gaps the MCU-Watchlist reviews noted, fixed at regex level ---
# a path-qualified git binary is still git
check BLOCKED '/usr/bin/git push --force origin main'
check BLOCKED '/usr/local/bin/git reset --hard HEAD'
check BLOCKED './git checkout -- src/x'
check BLOCKED '/usr/bin/git branch -D x'
# any global option before the subcommand, not just -C / -c
check BLOCKED 'git --no-pager push --force origin main'
check BLOCKED 'git --no-pager -C /other/repo reset --hard'
check BLOCKED 'git -c core.pager=cat --no-pager checkout -- src/x'
check BLOCKED 'git --no-pager restore src/x'
check BLOCKED 'git --no-pager clean -fd'
check BLOCKED 'git --git-dir=.git --work-tree=. stash drop'
check BLOCKED 'git --no-pager worktree remove --force wt'
check BLOCKED 'git -P checkout -f'
# a +refspec is a force push of that ref
check BLOCKED 'git push origin +main'
check BLOCKED 'git push origin +HEAD:main'
check BLOCKED 'git push origin "+feature"'
check BLOCKED 'git push --no-verify origin +refs/heads/x:refs/heads/x'
check BLOCKED 'git --no-pager push origin +main'
# ... and ordinary work still runs
check ALLOWED '/usr/bin/git status'
check ALLOWED 'git --no-pager log --oneline -5'
check ALLOWED 'git --no-pager diff'
check ALLOWED 'git --no-pager show HEAD'
check ALLOWED 'git -c color.ui=never push origin main'
check ALLOWED 'git push origin feat+x'
check ALLOWED 'git push origin main && echo +5'
check ALLOWED 'git --no-pager branch -d merged-x'
# only real value-taking global options consume the next word
check ALLOWED 'git --no-pager log --grep restore'
check ALLOWED 'git -P log --oneline --grep stash drop'
check ALLOWED 'git --no-pager log -S clean -- x'
check BLOCKED 'git --git-dir .git --no-pager reset --hard'
check BLOCKED 'git --work-tree /w -C /r clean -f'

# --- rules first added in MCU-Watchlist (2026-08-16; upstream since v1.69.0) ---
# Each was a real gap: the operation was blocked under one spelling and walked
# through under another.
check BLOCKED 'git restore src/file.ts'
check BLOCKED 'git restore --staged --worktree .'
check BLOCKED 'git -C /other/repo restore .'
check BLOCKED 'git branch --delete --force feature/x'
check BLOCKED 'git branch --force --delete feature/x'
check BLOCKED 'git branch -f --delete feature/x'
check BLOCKED 'git clean --force -d'
check BLOCKED 'git worktree remove -f wt'
check BLOCKED 'rm --recursive -f /tmp/x'
check BLOCKED 'rm /tmp/x -rf'
# the override is explicit, on the same command, and visible in the transcript
check ALLOWED 'AGENTSKEL_UNSAFE=i-understand git reset --hard HEAD~1'
check BLOCKED 'echo AGENTSKEL_UNSAFE=i-understand; git reset --hard HEAD~1'
# heredoc bodies are content, not commands
check ALLOWED "$(printf 'cat > notes.md <<'"'"'EOF'"'"'\nnever run git reset --hard here\nEOF')"
check BLOCKED "$(printf 'cat > notes.md <<'"'"'EOF'"'"'\nprose\nEOF\ngit reset --hard')"
check ALLOWED 'git branch --delete merged-feature'
check ALLOWED 'git restore-mtime --help'
check ALLOWED 'git clean -n'

# --- rm: only the flags of the same rm invocation count (MCU-Watchlist, v1.69.0) ---
# The old rule let `.*` run across the whole command line, so any hyphenated
# word after `rm` with an r and an f in it read as -rf. Both commands from
# 2026-11-02 that it blocked are here, with the 2026-09-12 path.
check ALLOWED 'git rm -q docs/social/scripts/6-month/day-139-confirmed-or-rumour-open-week-of.md'
check ALLOWED 'grep -n -i "recursive force\|rm " pre-bash-safety.sh; sed -n 1,40p stop-verify.sh'
check ALLOWED 'rm src/data/connections/drafts/the-fantastic-four-first-steps.json'
check ALLOWED 'rm -f tmp.js; grep -n the-fantastic-four-first-steps src/data/mcu.ts'
check ALLOWED 'rm --force notes.txt'
check ALLOWED 'rm -f notes.txt'
check ALLOWED 'rm -r empty-dir'
check ALLOWED 'rm -r old-dir; ls -f notes'
check ALLOWED 'rm -r old-dir && grep -f patterns.txt notes'
check ALLOWED 'rm -r old-dir | tee -f log'
# blocked by the floor rule, as before v1.69.0: a bundled -rf after `rm ` anywhere on
# the line (the price of never being weaker than the pre-v1.69.0 hook; third review)
check BLOCKED 'rm -- -rf'
# blocked by the floor rule, as before v1.69.0: a bundled -rf after `rm ` anywhere on
# the line (the price of never being weaker than the pre-v1.69.0 hook; third review)
check BLOCKED 'rm -i -- -rf -fr'
check ALLOWED 'rm -r a && rm -f b'
check ALLOWED "$(printf 'rm -r old-dir\nls -f notes')"
check ALLOWED 'git log -S rm -- src/x.ts'
check ALLOWED 'echo "rm is a command"'
# every spelling of the operation, wherever rm sits
check BLOCKED 'rm -fr build'
check BLOCKED 'rm -Rf build'
check BLOCKED 'rm -rfv build'
check BLOCKED 'rm -R -f build'
check BLOCKED 'rm -f -r build'
check BLOCKED 'rm --force --recursive build'
check BLOCKED 'rm -r --force build'
check BLOCKED 'rm --recursive=yes --force build'
check BLOCKED 'rm --rec --forc build'
check BLOCKED 'rm build -rf'
check BLOCKED 'rm "-rf" build'
check BLOCKED "rm '-r' '-f' build"
check BLOCKED 'rm -rf -- build'
check BLOCKED 'ls; rm -rf build'
check BLOCKED 'ls || rm -rf build'
check BLOCKED 'ls | xargs rm -rf'
check BLOCKED 'ls & rm -rf build'
check BLOCKED "$(printf 'ls\nrm -rf build')"
check BLOCKED 'sudo rm -rf build'
check BLOCKED 'env X=1 rm -rf build'
check BLOCKED '/bin/rm -rf build'
check BLOCKED '\rm -rf build'
check BLOCKED '"rm" -rf build'
check BLOCKED 'git rm -r -f src/old'
check BLOCKED 'git -C /other/repo rm -rf src/old'
check BLOCKED 'echo $(rm -rf build)'
check BLOCKED 'echo `rm -rf build`'
check BLOCKED 'echo "$(rm -rf build)"'
check BLOCKED 'bash -c "rm -rf build"'
check BLOCKED "sh -c 'cd /tmp && rm -r -f build'"
check BLOCKED 'rm -r "unterminated -f'
# --- review of PR #165: a substitution does not end rm's arguments ---
check BLOCKED 'rm -r $(cat list) -f'
check BLOCKED 'rm -r `cat list` -f'
check BLOCKED 'rm -r <(true) x -f'
check BLOCKED 'rm -r x >(tee l) -f'
check BLOCKED 'rm -r x $((1)) -f'
check BLOCKED 'rm -r x ${a:-$(echo)} -f'
check BLOCKED 'rm -r $(git rev-parse --show-toplevel)/dist --force'
# a quoted or escaped separator is a word, not a separator
check BLOCKED "rm -r build ';' -f"
check BLOCKED 'rm -r build \; -f'
check BLOCKED "rm -r build '&&' -f"
check BLOCKED 'rm -r build "|" -f'
check BLOCKED 'rm -r a\`b -f'
# brace expansion and ANSI-C quoting are still the same flags
check BLOCKED 'rm {-rf,} x'
check BLOCKED 'rm {-r,-f} x'
check BLOCKED "rm \$'-rf' x"
check BLOCKED "rm \$'\\x2drf' x"
check BLOCKED "\$'rm' -rf x"
# a comment with an apostrophe does not change how the next line is read
check BLOCKED "$(printf 'ls # what'"'"'s this\nrm -r x &>/dev/null -f')"
# a command substitution inside a commit message runs; plain message text does not
check BLOCKED 'git commit -m "$(rm -rf y)"'
check BLOCKED 'git commit -m "x `rm -rf y`"'
check BLOCKED 'git commit --message "$(rm -rf y)"'
check BLOCKED "echo '-m \"' ; rm -rf y ; echo '\"'"
check BLOCKED "$(printf 'cat <<<'"'"'x'"'"'\nrm -rf build')"
# strings handed to something that runs commands are commands
check BLOCKED 'ssh host "rm -rf /srv/app"'
check BLOCKED 'sudo bash -c "rm -rf x"'
check BLOCKED 'bash -c rm\ -rf\ x'
check BLOCKED "xargs -I{} sh -c 'rm -r -f {}'"
# --- review of PR #165: text that only mentions the flags is not a delete ---
check ALLOWED "grep -rn 'rm -rf' .claude/"
check ALLOWED 'git log -S "rm -rf" --oneline'
check BLOCKED "sed -n '/rm -rf/p' notes.md"
# blocked by the floor rule, as before v1.69.0: a bundled -rf after `rm ` anywhere on
# the line (the price of never being weaker than the pre-v1.69.0 hook; third review)
check BLOCKED 'gh pr create --title "hook" --body "Blocks rm path -rf now"'
# blocked by the floor rule, as before v1.69.0: a bundled -rf after `rm ` anywhere on
# the line (the price of never being weaker than the pre-v1.69.0 hook; third review)
check BLOCKED 'git commit -am "drop rm -rf usage from script"'
# blocked by the floor rule, as before v1.69.0: a bundled -rf after `rm ` anywhere on
# the line (the price of never being weaker than the pre-v1.69.0 hook; third review)
check BLOCKED "$(printf 'git commit -m \"Fix hook\n\nNow blocks rm path -rf\"')"
check ALLOWED 'rm -r dist 2>/dev/null; npm ci -f'
check ALLOWED 'docker run --rm img ls -rf'
# blocked by the floor rule, as before v1.69.0: a bundled -rf after `rm ` anywhere on
# the line (the price of never being weaker than the pre-v1.69.0 hook; third review)
check BLOCKED "$(printf 'ls # rm -rf x\necho done')"
# --- review of PR #165: every spelling of a force branch delete ---
check BLOCKED 'git branch -d -f x'
check BLOCKED 'git branch -df x'
check BLOCKED 'git branch -fd x'
check BLOCKED 'git branch --force -d x'
check BLOCKED 'git branch -d --force x'
check BLOCKED 'git branch --del --forc x'
check BLOCKED 'git -C /other/repo branch -d -f x'
check ALLOWED 'git branch -d merged-x && ls -f'
check ALLOWED 'git branch -f main origin/main'
# --- review of PR #165: a long command is checked in full ---
# `echo "$CMD" | grep -q` under pipefail failed OPEN once the command was long
# enough for grep's early exit to break the pipe (blocked at 74 KB, allowed at
# 115 KB).
BIG=$(printf 'git reset --hard\n'; for i in $(seq 2000); do echo "echo filler line $i with some padding text here"; done)
check BLOCKED "$BIG"
BIGRM=$(printf 'rm -rf build\n'; for i in $(seq 4000); do echo "echo filler line $i with some padding text here"; done)
check BLOCKED "$BIGRM"

# --- second review of PR #165: quoted text is commands unless it is a search
# pattern or a message. Runner lists cannot be complete: trap, pipes into a
# shell, here-strings, flock, GIT_SSH_COMMAND, git rebase -x, tmux, $SHELL ...
check BLOCKED "trap 'cd /tmp; rm -rf x' EXIT"
check BLOCKED 'trap "cd /tmp && rm -rf x" EXIT'
check BLOCKED "trap 'rm -rf \"\$tmp\"' EXIT"
check BLOCKED 'echo "cd x; rm -rf y" | bash'
check BLOCKED "echo 'rm -rf y' | bash"
check BLOCKED 'bash <<< "cd x; rm -rf y"'
check BLOCKED 'flock /tmp/l -c "cd x; rm -rf y"'
check BLOCKED 'GIT_SSH_COMMAND="true; rm -rf x" git fetch'
check BLOCKED 'git rebase -x "make; rm -rf build" main'
check BLOCKED 'tmux new -d "sleep 1; rm -rf x"'
check BLOCKED '$SHELL -c "cd x; rm -rf y"'
check BLOCKED "env -S 'rm -rf x'"
check BLOCKED "python3 -c \"import os; os.system('rm -rf y')\""
# eval, ssh and watch join their arguments before running them
check BLOCKED 'eval "cd x; rm -r " -f y'
check BLOCKED "eval 'rm -r' -f x"
check BLOCKED "ssh host 'rm -r' '-f x'"
# search patterns and messages only mention the flags
check ALLOWED 'rg -n "rm -rf" src'
check ALLOWED 'git grep -n "rm -rf"'
check ALLOWED "git log --grep='rm -rf' --oneline"
check ALLOWED 'grep -E "rm -(rf|fr)" notes.md'
check ALLOWED 'git commit -m "x" -m "rm -rf is now caught"'
check ALLOWED 'git tag -a v1 -m "drop rm -rf"'
check ALLOWED 'gh issue create --title "rm -rf" --body "rm -rf path"'
check BLOCKED 'grep x "$(rm -rf y)"'
check BLOCKED 'echo "rm -rf is dangerous"'
# --- second review of PR #165: places the reader lost step with bash ---
check BLOCKED "echo \${x:-'}'} ; rm -rf y ; echo \"'\" # \""
check BLOCKED 'echo `echo #` ; rm -rf x'
check BLOCKED 'echo $((echo hi) ; rm -rf x)'
check BLOCKED 'echo `echo \`rm -rf x\``'
check BLOCKED 'echo $(( `rm -rf x` + 1 ))'
check BLOCKED 'git --attr-source HEAD branch -D x'
# input that used to crash the reader, with a name the fallback missed
check BLOCKED "echo \$'\\x'; r\\m -rf x"
check BLOCKED "echo \$'\\UFFFFFFFF'; r\\m -rf x"
check BLOCKED "echo \$'\\x'; git branch \"-\"df x"
check BLOCKED "rm -rf x; echo \$'\\c"
NEST='rm -rf x'; for i in $(seq 60); do NEST="echo \$($NEST)"; done
check BLOCKED "$NEST"
# --- third review of PR #165: the reader can only ADD blocks. the pre-v1.69.0 rm rule
# (anchored so a flag must start a word) and a one-command split-flag rule
# always apply too, so a misread can no longer let through what they catch.
check BLOCKED 'echo ${x:-{} ; rm -rf y ; echo }'
check BLOCKED 'echo "${x:-{}" ; rm -rf y ; echo "}"'
check BLOCKED ': ${x:-$(case a in a) rm -rf y;; esac)}'
check BLOCKED ': ${x:-<( rm -rf y)}'
check BLOCKED 'rm ${HOME:+-rf} y'
check BLOCKED 'rm ${u:--rf} y'
check BLOCKED 'env -u rm -- rm -rf y'
check BLOCKED 'echo y | xargs -E rm -- rm -rf'
check BLOCKED "git grep -O' rm -rf y' -e x"
check BLOCKED "git grep -O'rm -rf y' -e x"
check BLOCKED "echo a | rg a -r ' rm -rf y' | sh"
check BLOCKED "echo a | rg a -r 'rm -rf y' | sh"
check BLOCKED "echo a | grep -H --label=' rm -rf y;' a | sh"
check BLOCKED "ag --pager='rm -rf y' x"
check BLOCKED "grep(){ sh -c \"\$*\"; }; grep 'rm -rf y'"
check BLOCKED "bash -c -m \$'rm -rf y'"
check BLOCKED "parallel -m 'rm -rf {}' ::: y"
check BLOCKED 'echo ${x:-{} ; git branch -d -f x ; echo }'
check BLOCKED ': ${x:-$(case a in a) git branch -df x;; esac)}'
# found in the same review, already missed before v1.69.0
check BLOCKED 'git commit -m "$(case a in a) rm -rf y;; esac)"'
check BLOCKED "GIT_SSH_COMMAND='rm -rf y' git fetch origin"
check BLOCKED "c='rm -rf y'; \$c"
check BLOCKED "alias z='rm -rf y'"
check BLOCKED "git -c core.sshCommand='rm -rf y' fetch origin"
check BLOCKED "git -c alias.z='!rm -rf y' z"
check BLOCKED "git config alias.z '!rm -rf y' && git z"
check BLOCKED '{rm,-rf,y}'
check BLOCKED '{r,}m -rf y'
check BLOCKED '{git,branch,-D,x}'
check BLOCKED 'rm${IFS}-rf${IFS}y'
check BLOCKED "printf 'cd /tmp\nrm -rf y\n' | sh"
check BLOCKED 'echo -e "cd /tmp\nrm -rf y" | sh'
# fourth review: a flag glued after an expansion that comes out empty is a
# flag to bash; the pre-v1.69.0 rule caught these and the floor must too
check BLOCKED 'rm $x-rf /tmp/zz'
check BLOCKED 'rm $9-rf y'
check BLOCKED 'rm $@-rf y'
check BLOCKED 'rm $x$y-rf y'
check BLOCKED 'rm $(:)-rf y'
check BLOCKED 'rm `:`-rf y'
check BLOCKED 'rm `true`-fr y'
check BLOCKED 'rm $x--force -r y'
check BLOCKED 'rm *-rf y'
# $[ ] arithmetic and extglob patterns are one word, not a command break
check BLOCKED 'rm -r $[1|0] -f /tmp/zz'
check BLOCKED 'rm -r $[1&1] -f /tmp/zz'
check BLOCKED "$(printf 'shopt -s extglob\nrm -r @(a|b) -f /tmp/zz')"
check BLOCKED 'git branch -d $[1|0] -f foo'
# fifth review (1a): a quoted or escaped brace char inside a brace list makes
# the comma split -rf into its own word; the comma is a boundary, not part of
# a filename, so a hyphen right after it must be read as a possible flag
check BLOCKED 'rm {"}",-rf} ./junk'
check BLOCKED 'rm {"{",-rf} ./junk'
check BLOCKED "rm {'}',-rf} ./junk"
check BLOCKED 'rm {\},-rf} ./junk'
check BLOCKED 'rm {a,-rf} ./junk'
# a comma inside a real filename (not a brace list) is still fine: the hyphen
# has literal text before it in the same word
check ALLOWED 'rm a,b-rf.txt ./junk'
check ALLOWED 'rm draft,final-reviewed.md'
# hyphenated words still never read as flags (the owner's two commands, 2026-11-02)
check ALLOWED 'git rm -q docs/social/scripts/6-month/day-139-confirmed-or-rumour-open-week-of.md'
check ALLOWED 'rm notes-confirmed-four.txt; ls out/run-confirmed-final'
# a hyphen after literal text in a path that starts with a variable is not a flag
check ALLOWED 'rm -f $SP/r4-165-after.txt; grep -c . $SP/r4-165-after.txt'
check ALLOWED 'rm -f "$TMP/run-after.txt" ${DIR}/x-for-real.txt'
# shells inside shells: past the reader's depth it does not guess, it blocks
SHN='rm -rf x'; for i in $(seq 7); do SHN="bash -c $(printf %q "$SHN")"; done
check BLOCKED "$SHN"
# a non-breaking space is an ordinary character to bash, not a word break
check ALLOWED "$(printf 'ls\xc2\xa0-rf rm')"
check BLOCKED "$(printf 'rm -rf\xc2\xa0x')"
# --- second review of PR #165: long or explosive input is checked quickly ---
quick() { # quick <BLOCKED|ALLOWED> <max seconds> <command>
  local t=$SECONDS
  check "$1" "$3"
  if [ $((SECONDS - t)) -gt "$2" ]; then
    fail=$((fail+1)); printf 'FAIL  took %ss (limit %ss): %.60s\n' "$((SECONDS - t))" "$2" "$3"
  fi
}
quick BLOCKED 15 "$(printf 'x%.0s' $(seq 200000)) ; rm -rf x"
quick BLOCKED 15 "echo rm $(printf '{a,b}%.0s' $(seq 23)) ; rm -rf x"
quick BLOCKED 15 "echo $(printf 'rm %.0s' $(seq 30000)) ; rm -rf x"
quick ALLOWED 15 "echo $(printf 'word %.0s' $(seq 30000))"
# a long run of rm commands is checked quickly (fourth review: 110 s)
quick BLOCKED 15 "$(printf 'rm a;%.0s' $(seq 30000)) git worktree remove --force /tmp/wt"

# --- review of PR #164: the override is a deliberate first word, nothing else ---
# It used to fire on the phrase anywhere (a commit message, a heredoc, an echo)
# and then switch off every rule in the whole compound command.
check BLOCKED 'git commit -m "doc: AGENTSKEL_UNSAFE=i-understand prefix" && git reset --hard'
check BLOCKED 'echo AGENTSKEL_UNSAFE=i-understand ; git reset --hard'
check BLOCKED "$(printf 'cat > n.md <<'"'"'EOF'"'"'\nUse AGENTSKEL_UNSAFE=i-understand <cmd>\nEOF\ngit reset --hard')"
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git branch -D x && git reset --hard'
check BLOCKED "$(printf 'AGENTSKEL_UNSAFE=i-understand git branch -D x\ngit reset --hard')"
check ALLOWED '  AGENTSKEL_UNSAFE=i-understand git branch -D feature/x'
# second review: no second command hidden in a substitution; redirections are fine
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git branch -D x $(git push --force origin main)'
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git branch -D x `git push --force origin main`'
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git branch -D x <(git reset --hard)'
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push --force origin x 2>&1 | tail -1'
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push --force origin x &'
check ALLOWED 'AGENTSKEL_UNSAFE=i-understand git push --force origin x 2>&1'
check ALLOWED 'AGENTSKEL_UNSAFE=i-understand git branch -D x > /tmp/out.txt 2>&1'
check ALLOWED 'AGENTSKEL_UNSAFE=i-understand git branch -D x &>/dev/null'
# a fake -m "..." inside quotes does not hide a second command from the override
check BLOCKED "AGENTSKEL_UNSAFE=i-understand git branch -D x '-m \"'; git reset --hard; echo '\"'"
# --- review of PR #164: only real heredocs are stripped ---
# A here-string, a quoted "<<EOF", an arithmetic shift or a tag with a hyphen
# used to start a "body" that hid every line after it from every rule.
check BLOCKED "$(printf 'grep foo <<<bar\ngit reset --hard')"
check BLOCKED "$(printf 'grep foo <<<\"$x\"\ngit reset --hard')"
check BLOCKED "$(printf 'echo $((1<<x))\ngit reset --hard')"
check BLOCKED "$(printf 'echo \"see <<EOF in the docs\"\ngit reset --hard')"
check BLOCKED "$(printf 'cat <<END-OF\nprose\nEND-OF\ngit reset --hard')"
check BLOCKED "$(printf 'cat <<EOF-1\nprose\nEOF-1\ngit reset --hard')"
# a heredoc fed to a shell is commands, not content
check BLOCKED "$(printf 'bash <<'"'"'EOF'"'"'\ngit reset --hard\nEOF')"
check BLOCKED "$(printf 'cat <<EOF | sh\ngit reset --hard\nEOF')"
check BLOCKED "$(printf 'ssh host <<EOF\ngit reset --hard\nEOF')"
# real heredocs of prose stay content
# outside the known shapes (third review): checked in full
check BLOCKED "$(printf 'cat > a.md <<-EOF\n\tgit reset --hard is dangerous\n\tEOF')"
check ALLOWED "$(printf 'git commit -F - <<'"'"'EOF'"'"'\nnever run git reset --hard\nEOF')"
# outside the known shapes (third review): checked in full
check BLOCKED "$(printf 'cat > a.md <<\"END-OF\"\ngit reset --hard\nEND-OF\necho done')"
# outside the known shapes (third review): checked in full
check BLOCKED "$(printf 'cat <<A > a.md; cat <<B > b.md\ngit reset --hard\nA\ngit reset --hard\nB')"
# the usual commit / PR body form: a heredoc inside "$( )" is a real heredoc
# "$(cat <<'EOF' ...)" is checked in full (fourth review): bash ends a heredoc
# inside "$( )" at a line that only starts with the marker. Use -F - instead.
check BLOCKED "$(printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\nnever run git reset --hard\nEOF\n)"')"
# "$(cat <<'EOF' ...)" is checked in full (fourth review): bash ends a heredoc
# inside "$( )" at a line that only starts with the marker. Use -F - instead.
check BLOCKED "$(printf 'gh pr create --title t --body "$(cat <<'"'"'EOF'"'"'\ngit reset --hard is blocked\nEOF\n)"')"
check BLOCKED "$(printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\nmsg\nEOF\n)" && git reset --hard')"
# the end line must match exactly, as in bash: "  EOF" does not end a <<EOF body
# outside the known shapes (third review): checked in full
check BLOCKED "$(printf 'cat > a.md <<EOF\nx\n  EOF\ngit reset --hard\nEOF')"
check BLOCKED "$(printf 'cat > a.md <<EOF\nx\nEOF\ngit reset --hard')"
# a "<<EOF" inside a string that spans lines is text, not a heredoc
check BLOCKED "$(printf 'echo "first line\nsee <<EOF here"\ngit reset --hard')"
# --- second review of PR #164: a body is skipped only when bash will not run it ---
# Skipped: the body is inert (quoted end marker, or nothing to expand), it ends
# on an exact end line, and only a text sink reads it (cat, tee, git/gh -F -).
# Everything else is checked, so an accidental "<<" can no longer hide lines.
check BLOCKED "$(printf '(( x = 1 << 2 ))\ngit reset --hard')"
check BLOCKED "$(printf 'for (( i=1; i < 8; i = i << 1 )); do :; done\ngit reset --hard')"
check BLOCKED "$(printf 'echo $[ 1 << 2 ]\ngit reset --hard')"
check BLOCKED "$(printf 'echo $(( (1+(2)) << x ))\ngit reset --hard')"
check BLOCKED "$(printf 'cat <<EOF\r\nbody\r\nEOF\r\ngit reset --hard\r\n')"
check BLOCKED "$(printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\nmsg\nEOF)" && git reset --hard')"
check BLOCKED "$(printf 'x=$(cat <<EOF\nhi\nEOF)\ngit reset --hard')"
check BLOCKED "$(printf 'cat <<EOF |\ngit reset --hard\nEOF\nbash')"
check BLOCKED "$(printf 'while read -r l; do $l; done <<EOF\ngit reset --hard\nEOF')"
check BLOCKED "$(printf 'source /dev/stdin <<EOF\ngit reset --hard\nEOF')"
check BLOCKED "$(printf '. /dev/stdin <<'"'"'EOF'"'"'\ngit reset --hard\nEOF')"
check BLOCKED "$(printf 'fish <<EOF\ngit reset --hard\nEOF')"
check BLOCKED "$(printf 'python3 - <<'"'"'EOF'"'"'\nx = 1; git reset --hard\nEOF')"
check BLOCKED "$(printf 'echo $'"'"'a\\'"'"'b <<EOF'"'"'\ngit reset --hard')"
check BLOCKED "$(printf 'echo ${x:-<<EOF}\ngit reset --hard')"
check BLOCKED "$(printf '(echo a)#<<EOF\ngit reset --hard')"
check BLOCKED "$(printf 'cat > f.txt <<EOF\n$(date); git reset --hard\nEOF')"
check BLOCKED "$(printf 'cat > f.txt <<EOF\n`date`; git reset --hard\nEOF')"
# real text heredocs still pass
# outside the known shapes (third review): checked in full
check BLOCKED "$(printf 'cat > a.md <<'"'"'EOF'"'"'\r\ngit reset --hard\r\nEOF\r\n')"
# outside the known shapes (third review): checked in full
check BLOCKED "$(printf 'bash .claude/hooks/tests/x.sh && git commit -m "$(cat <<'"'"'EOF'"'"'\nblock git reset --hard\nEOF\n)"')"
# outside the known shapes (third review): checked in full
check BLOCKED "$(printf 'sudo tee /etc/x > /dev/null <<'"'"'EOF'"'"'\ngit reset --hard\nEOF')"
# outside the known shapes (third review): checked in full
check BLOCKED "$(printf 'git commit -F - <<'"'"'EOF'"'"' # bash\ngit reset --hard\nEOF')"
check ALLOWED "$(printf 'gh pr create --title t --body-file - <<'"'"'EOF'"'"'\ngit reset --hard\nEOF')"
# outside the known shapes (third review): checked in full
check BLOCKED "$(printf 'cat > notes.txt <<EOF\nplain text, git reset --hard\nEOF')"
# a heredoc inside "$( )" is text only when the $( ) feeds git or gh (the
# commit / PR body form); fed to eval, bash -c or a variable, it may be run
check BLOCKED "$(printf 'eval "$(cat <<'"'"'EOF'"'"'\ngit reset --hard\nEOF\n)"')"
check BLOCKED "$(printf 'bash -c "$(cat <<'"'"'EOF'"'"'\ngit reset --hard\nEOF\n)"')"
check BLOCKED "$(printf 'x=$(cat <<'"'"'EOF'"'"'\ngit reset --hard\nEOF\n)\neval "$x"')"
# --- third review of PR #164: a body is skipped only for a few whole-command
# shapes (git commit -m "$(cat <<'EOF' ...)" / -F -, gh pr|issue --body ...,
# cat > FILE, tee FILE > /dev/null), behind at most cd / git add. Everything
# else is checked, so these, which the scanner used to hide, are seen:
check BLOCKED "$(printf 'bash <(cat << '"'"'EOF'"'"'\ngit reset --hard\nEOF\n)')"
check BLOCKED "$(printf 'source <(cat <<'"'"'EOF'"'"'\ngit reset --hard\nEOF\n)')"
check BLOCKED "$(printf 'cat << '"'"'EOF'"'"' > >(bash)\ngit reset --hard\nEOF')"
check BLOCKED "$(printf 'tee << '"'"'EOF'"'"' >(sh) >/dev/null\ngit reset --hard\nEOF')"
check BLOCKED "$(printf '( cat << '"'"'EOF'"'"'\ngit reset --hard\nEOF\n) | bash')"
check BLOCKED "$(printf 'git rebase -x "$(cat << '"'"'EOF'"'"'\ngit reset --hard\nEOF\n)" HEAD~1')"
check BLOCKED "$(printf 'git -c alias.x='"'"'!sh -c'"'"' x "$(cat << '"'"'EOF'"'"'\ngit reset --hard\nEOF\n)"')"
check BLOCKED "$(printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\ngit reset --hard\nEOF\n)" && eval "$(git log -1 --format=%%B)"')"
check BLOCKED "$(printf 'cat > /tmp/fix.sh <<'"'"'EOF'"'"'\ngit reset --hard\nEOF\nchmod +x /tmp/fix.sh && /tmp/fix.sh')"
check BLOCKED "$(printf 'env -u cat bash << '"'"'EOF'"'"'\ngit reset --hard\nEOF')"
check BLOCKED "$(printf '(bash; cat ) << '"'"'EOF'"'"'\ngit reset --hard\nEOF')"
check BLOCKED "$(printf 'cat() { bash; }; cat << '"'"'EOF'"'"'\ngit reset --hard\nEOF')"
check BLOCKED "$(printf 'sh -s \\\ncat << '"'"'EOF'"'"'\ngit reset --hard\nEOF')"
check BLOCKED "$(printf 'git commit -m "$(cat <<EOF\ngit reset --hard\nEOF\n)"')"
check BLOCKED "$(printf 'cat << '"'"'EOF'"'"'\nEOF\r\ncat << '"'"'true'"'"'\nEOF\ngit reset --hard\ntrue')"
check BLOCKED "$(printf 'AGENTSKEL_UNSAFE=i-understand git push --force origin x$[ a[0] + (cat << 2) ]\ngit reset --hard\n2')"
# fourth review: the body ends at the FIRST end line, as in bash; lines after
# it are commands even if a later line repeats the marker
check BLOCKED "$(printf 'cat > /tmp/a <<'"'"'EOF'"'"'\nx\nEOF\ngit reset --hard\ncat > /tmp/b <<'"'"'EOF'"'"'\ny\nEOF')"
check BLOCKED "$(printf 'cat > /tmp/a <<'"'"'EOF'"'"'\nx\nEOF\ngit reset --hard\nEOF')"
check BLOCKED "$(printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\nmsg\nEOF\ngit reset --hard\ncat <<'"'"'EOF'"'"'\ntail\nEOF\n)"')"
check BLOCKED "$(printf 'git commit -F - <<'"'"'EOF'"'"'\nmsg\nEOF\ngit reset --hard\ncat <<'"'"'EOF'"'"'\ntail\nEOF')"
check BLOCKED "$(printf 'gh pr create --title t --body "$(cat <<'"'"'EOF'"'"'\nmsg\nEOF\ngit reset --hard\ncat <<'"'"'EOF'"'"'\ntail\nEOF\n)"')"
check BLOCKED "$(printf 'gh pr comment 5 --body-file - <<'"'"'EOF'"'"'\nmsg\nEOF\ngit reset --hard\ncat <<'"'"'EOF'"'"'\ntail\nEOF')"
# fourth review, second pass: a line that only starts with the marker ends
# a heredoc inside "$( )" in bash 5.2, and the lines after it run
check BLOCKED "$(printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\nmsg\nEOF)"\n EOF\ngit reset --hard; : "$(cat <<'"'"'EOF'"'"'\nEOF\n)"')"
check BLOCKED "$(printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\nmsg\nEOF)"\nEOF \ngit reset --hard; : "$(cat <<'"'"'EOF'"'"'\nEOF\n)"')"
check BLOCKED "$(printf 'gh pr create --title t --body "$(cat <<'"'"'EOF'"'"'\nmsg\nEOF)"\n EOF\ngit reset --hard; : "$(cat <<'"'"'EOF'"'"'\nEOF\n)"')"
# the -F - form is the way to write a message that mentions a blocked command
check ALLOWED "$(printf 'git add -A && git commit -F - <<'"'"'EOF'"'"'\nnever run git reset --hard\n\nCo-Authored-By: x\nEOF')"
check ALLOWED "$(printf 'gh pr create --title "Fix hook" --base main --body-file - <<'"'"'EOF'"'"'\ngit reset --hard is now blocked\nEOF')"
# and a "$(cat <<'EOF' ...)" message that mentions nothing blocked still passes
check ALLOWED "$(printf 'git commit -m "$(cat <<'"'"'EOF'"'"'\nfix: pages keep still\n\nCo-Authored-By: x\nEOF\n)"')"
# the shapes agents use every day still pass
# "$(cat <<'EOF' ...)" is checked in full (fourth review): bash ends a heredoc
# inside "$( )" at a line that only starts with the marker. Use -F - instead.
check BLOCKED "$(printf 'git add -A && git commit -m "$(cat <<'"'"'EOF'"'"'\nnever run git reset --hard\nEOF\n)"')"
# "$(cat <<'EOF' ...)" is checked in full (fourth review): bash ends a heredoc
# inside "$( )" at a line that only starts with the marker. Use -F - instead.
check BLOCKED "$(printf 'cd /home/user/repo && git add a.md b.md && git commit -m "$(cat <<'"'"'EOF'"'"'\ngit reset --hard\n\nCo-Authored-By: x\nEOF\n)"')"
# "$(cat <<'EOF' ...)" is checked in full (fourth review): bash ends a heredoc
# inside "$( )" at a line that only starts with the marker. Use -F - instead.
check BLOCKED "$(printf 'git commit --amend -m "$(cat <<'"'"'EOF'"'"'\ngit reset --hard\nEOF\n)"')"
check ALLOWED "$(printf 'git commit -F- <<'"'"'EOF'"'"'\ngit reset --hard\nEOF')"
# "$(cat <<'EOF' ...)" is checked in full (fourth review): bash ends a heredoc
# inside "$( )" at a line that only starts with the marker. Use -F - instead.
check BLOCKED "$(printf 'gh pr create --title "Fix hook" --base main --body "$(cat <<'"'"'EOF'"'"'\ngit reset --hard is now blocked\nEOF\n)"')"
check ALLOWED "$(printf 'gh pr comment 165 --body-file - <<'"'"'EOF'"'"'\ngit reset --hard\nEOF')"
check ALLOWED "$(printf 'tee -a notes.md > /dev/null <<'"'"'EOF'"'"'\ngit reset --hard\nEOF')"
check ALLOWED "$(printf 'cat >> notes.md << "EOF"\ngit reset --hard\nEOF\n')"

# --- v1.69.0: every rule is decided per command (BL-007, BL-008, BL-009, BL-010) ---
# The git, find and gh api rules used to be regexes over the whole line: blind
# to text bash runs later (bash -c, eval, $( )), and firing across && on a
# flag that belongs to the next command. They now go through the same
# per-command reader as rm and git branch, with the regexes kept as a floor.
#
# BL-007: a destructive git / find / gh command inside a nested shell
check BLOCKED 'bash -c "git reset --hard"'
check BLOCKED "sh -c 'cd /tmp && git clean -fd'"
check BLOCKED 'eval "git push --force origin main"'
check BLOCKED "ssh host 'git checkout -- .'"
check BLOCKED 'echo $(git reset --hard)'
check BLOCKED 'echo `git stash drop`'
check BLOCKED "xargs -I{} sh -c 'git worktree remove --force {}'"
check BLOCKED 'trap "git reset --hard" EXIT'
check BLOCKED 'bash -c "find . -name x -delete"'
check BLOCKED "bash -c 'gh api -X DELETE /repos/o/r'"
check BLOCKED "sudo bash -c 'git restore .'"
check BLOCKED 'bash -c "git push origin +main"'
SHG='git reset --hard'; for i in $(seq 7); do SHG="bash -c $(printf %q "$SHG")"; done
check BLOCKED "$SHG"
# BL-008: a flag that belongs to the NEXT command is not this command's flag
check ALLOWED 'git push origin main && rm -f tmp.txt'
check ALLOWED 'git push origin main; ls -f'
check ALLOWED 'git checkout main && git update-ref refs/heads/x HEAD'
check ALLOWED 'git checkout -b feat && npm ci -f'
check ALLOWED 'git clean -n && ls -f'
check ALLOWED 'git reset --soft HEAD~1 && grep -c -- --hard notes.txt'
check ALLOWED 'git worktree remove wt && ls -f'
check ALLOWED 'find . -name "*.log" && git branch --delete merged-x'
check ALLOWED 'git stash list && git log -1 --format=%B | grep -c drop'
# ... but a quoted separator is part of the word, not the end of the command
check BLOCKED 'git push origin "a;b" -f'
check BLOCKED "git push origin 'x&&y' --force"
check BLOCKED 'git reset "a|b" --hard'
check BLOCKED "git clean 'a;b' -fd"
# BL-009: gh api fields and --input make a POST even without -X
check BLOCKED 'gh api repos/o/r/issues -f title=x'
check BLOCKED 'gh api -F x=1 /repos/o/r/labels'
check BLOCKED 'gh api --field name=x repos/o/r/labels'
check BLOCKED 'gh api --raw-field body=x repos/o/r/issues/1/comments'
check BLOCKED 'gh api --input body.json repos/o/r/pulls'
check BLOCKED 'gh api -XPOST repos/o/r/issues'
check BLOCKED 'gh api --method=delete /repos/o/r'
check BLOCKED 'gh api -X delete /repos/o/r'
# gh's flag parser lets short flags be bundled: -iX DELETE is --include + -X DELETE
check BLOCKED 'gh api -iX DELETE /repos/o/r'
check BLOCKED 'gh api -iXDELETE /repos/o/r'
check BLOCKED 'gh api --include -XPATCH /repos/o/r'
check BLOCKED 'gh api -if title=x repos/o/r/issues'
check ALLOWED 'gh api -i repos/o/r'
check ALLOWED 'gh api --paginate -i repos/o/r/issues'
check ALLOWED 'gh api -X GET search/issues -f q=repo:o/r'
check ALLOWED 'gh api --method GET repos/o/r/issues -F per_page=100'
check ALLOWED 'gh api --paginate repos/o/r/issues'
check ALLOWED 'gh api -H "Accept: application/vnd.github.raw" repos/o/r/contents/f'
# GraphQL: an inline query is a read; a mutation, or a query the hook cannot see, is not
check ALLOWED "gh api graphql -f query='query { viewer { login } }'"
check ALLOWED "gh api graphql -f query='{ viewer { login } }'"
check ALLOWED "gh api graphql -F owner=o -f query='query(\$owner: String!) { repositoryOwner(login: \$owner) { id } }'"
check ALLOWED "gh api graphql --raw-field query='{ repository(owner: \"o\", name: \"r\") { id } }'"
check ALLOWED "gh api graphql -X POST -f query='{ viewer { login } }'"
check BLOCKED "gh api graphql -f query='mutation { addStar(input: {starrableId: \"x\"}) { clientMutationId } }'"
check BLOCKED "gh api graphql -f query='mutation X { deleteRef(input: {refId: \"x\"}) { clientMutationId } }'"
check BLOCKED "gh api graphql -f 'query=mutation{deleteRef(input:{refId:\"x\"}){clientMutationId}}'"
# only a $ INSIDE the query that bash expands matters (differential review):
# a shell variable elsewhere in the command is the normal way to pass values
check ALLOWED "gh api graphql -f query='query(\$o: String!) { repositoryOwner(login: \$o) { id } }' -F o=\"\$OWNER\""
check ALLOWED "echo \$(gh api graphql -F owner=o -f query='query(\$owner: String!) { repositoryOwner(login: \$owner) { id } }')"
check BLOCKED 'gh api graphql -f query="query A(\$M: String) { viewer { login } } $M"'
check BLOCKED "bash -c 'gh api graphql -f query=\"{ viewer { login } } \$1\"' _ 'mutation { x }'"
check BLOCKED 'gh api graphql -f query="{ viewer { login } } ${M}"'
check BLOCKED 'gh api graphql -F query=@q.graphql'
check BLOCKED 'gh api graphql --input q.json'
check BLOCKED 'gh api graphql -f owner=o'
# BL-010: destructive forms no rule covered before
check BLOCKED 'git push --mirror origin'
check BLOCKED 'git push --prune origin'
check BLOCKED 'git push -uf origin main'
check BLOCKED 'git push origin main -fu'
check BLOCKED 'git switch -f main'
check BLOCKED 'git switch --force main'
check BLOCKED 'git switch --discard-changes main'
check BLOCKED 'git checkout -qf main'
check ALLOWED 'git switch main'
check ALLOWED 'git switch -c feat'
check ALLOWED 'git switch -'
check ALLOWED 'git push -u origin main'
check ALLOWED 'git push --tags origin'
check ALLOWED 'git reset --soft HEAD~1'
check ALLOWED 'git reset HEAD src/file.ts'
check ALLOWED 'git checkout -b feat origin/main'
check ALLOWED 'git clean -n'
check ALLOWED 'find . -name "*.ts" -newer x'

# --- v1.69.0 adversarial review round (gh / find / floor / override / deletes) ---
# Every case below was ALLOWED (or asked) by the hook when an independent
# reviewer probed it, and is destructive when bash or zsh runs it.
# brace SEQUENCES, not only comma lists
check BLOCKED 'git push origin --{d..d}elete main'
check BLOCKED 'git push --{f..f}orce origin main'
check BLOCKED 'git reset --{h..h}ard'
check BLOCKED 'rm -r --f{o..o}rce /tmp/x'
check BLOCKED 'gh api -X {D..D}ELETE /repos/o/r'
check BLOCKED "gh api graphql -f query={m..m}'utation{deleteRef(input:{refId:\"x\"}){clientMutationId}}'"
check ALLOWED 'echo {1..3}'
check ALLOWED 'mkdir -p out/{a..c}'
# git aliases run as git <value>
check BLOCKED "git -c alias.x='push origin --delete main' x"
check BLOCKED "git -c alias.x='reset --hard' x"
check BLOCKED "git config alias.x 'reset --hard' && git x"
check BLOCKED $'GIT_CONFIG_PARAMETERS="\'alias.x=reset --hard\'" git x'
check BLOCKED "git -c alias.x='!sh -c' x -m 'git push origin --delete main'"
check BLOCKED "git -c alias.x='!sh -c' x -m 'rm -rf /tmp/x'"
check ALLOWED "git -c alias.lg='log --oneline' lg"
check BLOCKED "gh alias set zz 'api -X DELETE /repos/o/r' && gh zz"
# a glob or zsh's =cmd in the command word is still that command
check BLOCKED '/usr/bin/gi[t] push origin --delete main'
check BLOCKED '/bin/r[m] -rf /tmp/x'
check BLOCKED '/opt/homebrew/bin/g[h] api -X DELETE /repos/o/r'
check BLOCKED '/usr/bin/fin[d] . -delete'
check BLOCKED '=git push origin --delete main'
check BLOCKED '=rm -rf /tmp/x'
# zsh: a glob qualifier runs code; ${ } closes at the first }
check BLOCKED "echo a*(e:'git reset --hard':)"
check BLOCKED $'echo "${x:-\'}" ; \\git reset --hard ; echo "\'}"'
# an empty expansion glued to a flag or refspec leaves the flag
check BLOCKED 'git push origin $x:main'
check BLOCKED 'git push origin $x+main'
check BLOCKED 'git push origin $x--delete main'
check BLOCKED 'git push origin $x-d main'
check BLOCKED 'git push $x--mirror origin'
# heredoc bodies are not shell text of the outer command
check BLOCKED $'cat <<\'EOF\'\n${x:-\nEOF\n\\git push origin --delete main\ncat <<\'EOF\'\n}\nEOF'
check BLOCKED $'cat <<EOF\ngrep \'\nEOF\n\\git reset --hard\ncat <<EOF\n\'\nEOF'
# a carriage return is an ordinary character, not a blank
check BLOCKED $'true\r# ; \\git push origin --delete main'
check BLOCKED $'true\r# ; \\rm -rf /tmp/x'
check BLOCKED $'true\r# ; \\gh api -X DELETE /repos/o/r'
# backticks: bash removes one backslash level, and quotes do not stop the closing backtick
check BLOCKED 'echo `\\git push origin --delete main`'
check BLOCKED 'echo `\\rm -rf /tmp/x`'
check BLOCKED "echo \`grep '\`; \\git reset --hard; echo \`'\`"
# gh: a method that is not a literal GET is not a read; root flags before api
check BLOCKED 'gh api -X "$M" /repos/o/r'
check BLOCKED 'gh api -X $(printf DELETE) /repos/o/r'
check BLOCKED 'gh api --method="$M" /repos/o/r'
check BLOCKED 'gh api -X="DE"LETE /repos/o/r'
check BLOCKED 'gh --help=false api -X DELETE /repos/o/r'
check ALLOWED 'gh api -X GET repos/o/r'
check BLOCKED "gh api graphql -f query=mutatio?'{deleteRef(input:{refId:\"x\"}){clientMutationId}}'"
# gh subcommands that delete
check BLOCKED 'gh repo delete o/r --yes'
check BLOCKED 'gh release delete v1 --yes'
check BLOCKED 'gh issue delete 5 --yes'
# a label delete strips it from every issue on GitHub; alias / extension
# deletes only touch local gh config
check BLOCKED 'gh label delete bug --yes'
check ALLOWED 'gh alias delete co'
check ALLOWED 'gh extension remove owner/gh-x'
check ALLOWED 'gh release list'
check ALLOWED 'gh repo view o/r'
# git config that changes what push / clean do
check BLOCKED 'git -c remote.origin.mirror=true push origin'
check BLOCKED 'git -c remote.origin.push=+HEAD:refs/heads/main push origin'
check BLOCKED 'git -c clean.requireForce=false clean -dx'
check ALLOWED 'git -c remote.origin.push=HEAD push origin'
# plumbing that does the same as a blocked command
check BLOCKED 'git update-ref -d refs/heads/x'
check BLOCKED 'git read-tree -u --reset HEAD'
check BLOCKED 'git checkout-index -a -f'
check BLOCKED 'git branch -M feature main'
check ALLOWED 'git update-ref refs/heads/x HEAD'
check ALLOWED 'git branch -m old new'
# find / fd with any remover
check BLOCKED 'find . -type f -exec env rm {} +'
check BLOCKED 'find . -type f -exec command rm {} +'
check BLOCKED "find . -type f -exec sh -c 'rm -- \"\$@\"' sh {} +"
check BLOCKED 'find . -type f -exec unlink {} \;'
check BLOCKED 'fd -t f . -X rm'
check ALLOWED 'find . -name "*.md" -exec grep -l x {} +'
# the override never reaches a remote delete, and covers one command only
check BLOCKED "AGENTSKEL_UNSAFE=i-understand bash -c 'git push origin --delete main'"
check BLOCKED "AGENTSKEL_UNSAFE=i-understand eval 'git push origin :main'"
check BLOCKED "AGENTSKEL_UNSAFE=i-understand bash -c \$'git branch -D x\\ngit reset --hard'"
check BLOCKED "AGENTSKEL_UNSAFE=i-understand eval \$'git branch -D x\\x3b git reset --hard'"
check BLOCKED "AGENTSKEL_UNSAFE=i-understand bash <<< \$'git branch -D x\\ngit reset --hard'"
# false positives the review found
check ALLOWED 'git restore --staged src/a.ts'
check ALLOWED 'git restore -S src/a.ts'
check BLOCKED 'git restore --staged --worktree src/a.ts'
check BLOCKED 'git restore -SW src/a.ts'

# --- v1.69.0 adversarial review round (git rules) ---
# git accepts any unique prefix of a long option
check BLOCKED 'git reset --h'
check BLOCKED 'git checkout --fo main'
check BLOCKED 'git switch --di main'
check BLOCKED 'git push --m origin'
# aliases without ! run a git subcommand
check BLOCKED 'git -c alias.x=reset x --hard'
check BLOCKED 'git -c alias.p=push p --force origin main'
check BLOCKED 'git -c alias.b=branch b -D feature'
check BLOCKED 'git -c alias.s=stash s drop'
check BLOCKED 'git -c alias.r=restore r .'
check BLOCKED 'git -c alias.x=!git x reset --hard'
check BLOCKED 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.x GIT_CONFIG_VALUE_0=reset git x --hard'
check BLOCKED 'V=reset git --config-env=alias.x=V x --hard'
check BLOCKED 'git config alias.x reset && git x --hard'
check BLOCKED "git config alias.nuke '!rm -rf build'"
check BLOCKED "git config alias.wipe 'reset --hard'"
check ALLOWED "git config alias.st status"
check BLOCKED 'git -c remote.origin.push=+HEAD:main push'
check BLOCKED 'git config remote.origin.mirror true'
# checkout with one path
check BLOCKED 'git checkout ./'
check BLOCKED 'git checkout :/'
check BLOCKED "git checkout '*'"
check BLOCKED 'git checkout ..'
check BLOCKED 'git checkout --theirs src/app.ts'
check BLOCKED 'git checkout --ours src/app.ts'
check BLOCKED 'git checkout --conflict=merge src/app.ts'
check ALLOWED 'git checkout -m main'
check ALLOWED 'git checkout feature/login'
# case-insensitive file systems: GIT is git
check BLOCKED 'GIT reset --hard'
check BLOCKED 'Git reset --hard'
check BLOCKED '/usr/bin/GIT reset --hard'
check BLOCKED 'RM -rf /tmp/x'
# --shallow-file takes a value
check BLOCKED 'git --shallow-file /dev/null reset --hard'
check BLOCKED 'git --shallow-file x push --force origin main'
# heredoc bodies cannot swallow the lines after them
check BLOCKED $'cat <<\'EOF\'\n${\nEOF\n\\git reset --hard\n'
check BLOCKED $'cat <<\'EOF\'\n$[\nEOF\n\\git reset --hard\n'
check BLOCKED $'cat <<\'EOF\'\n@(\nEOF\n\\git reset --hard\n'
check BLOCKED $'cat > notes.md <<\'EOF\'\nThe price is ${\nEOF\n(git reset --hard)\n'
check BLOCKED $'cat <<\'EOF\'\ngrep -e \'\nEOF\n\\git reset --hard # \'\n'
# (( )) is arithmetic: a # inside is not a comment
check BLOCKED '(( # )) ; \git reset --hard'
check BLOCKED '(( # )) ; (git reset --hard)'
check BLOCKED 'for (( ; # ; )) ; do :; done ; \git reset --hard'
check ALLOWED '(( x = 1 + 2 )) && echo ok'
# zsh
check BLOCKED '=git reset --hard'
check BLOCKED "ls *(e:'git reset --hard':)"
check BLOCKED "print -l /tmp(e:'git reset --hard':)"
# globs in the command word
check BLOCKED '/usr/bin/gi? reset --hard'
check BLOCKED '/usr/bin/g[i]t reset --hard'
# an always-empty expansion spliced into a word
check BLOCKED 'git reset --ha$()rd'
check BLOCKED 'git reset --ha``rd'
check BLOCKED 'git reset --ha$@rd'
check BLOCKED 'git reset --ha${x}rd'
check BLOCKED 'git re$()set --hard'
check BLOCKED 'git stash dr$()op'
check BLOCKED 'git res$()tore .'
check BLOCKED 'git push --for$()ce origin main'
check BLOCKED 'git branch --delete --for$()ce x'
check BLOCKED 'git checkout --for$()ce main'
check BLOCKED 'git work$()tree remove --force wt'
check BLOCKED '${x}git reset --hard'
check BLOCKED '"$x"git reset --hard'
check BLOCKED '$(:)git reset --hard'
check BLOCKED '`:`git reset --hard'
check ALLOWED 'git checkout $BRANCH'
check ALLOWED 'git push origin $BRANCH'
# dashed builtins
check BLOCKED '"$(git --exec-path)/git-reset" --hard'
check BLOCKED '/Library/Developer/CommandLineTools/usr/libexec/git-core/git-reset --hard'
# more plumbing
check BLOCKED 'git send-pack --force git@github.com:o/r.git main'
check BLOCKED 'git update-ref -d refs/stash'
check BLOCKED 'git reflog delete refs/stash@{0}'
check BLOCKED 'git submodule update --force'
# a long word of hyphens is checked quickly (review: 62 s at 80,000)
quick BLOCKED 15 "git reset --hard ; echo $(printf -- '-%.0s' $(seq 80000))"
quick ALLOWED 15 "echo x$(printf -- '-%.0s' $(seq 80000))"

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
  # EXPECT_NO_ASK=1: testing another tool's wrapper, where a merged delete is
  # blocked instead of asked (AGENTSKEL_NO_ASK, v1.69.0).
  [ "$want" = ASKED ] && [ "${EXPECT_NO_ASK:-}" = 1 ] && want=BLOCKED
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
# the override does not reach remote branch deletes: merged still asks,
# everything else is still blocked (review of PR #164)
check_in BLOCKED "$R" 'AGENTSKEL_UNSAFE=i-understand git push origin --delete unmerged'
check_in BLOCKED "$R" 'AGENTSKEL_UNSAFE=i-understand git push origin --delete main'
check_in ASKED   "$R" 'AGENTSKEL_UNSAFE=i-understand git push origin --delete merged-a'
check_in BLOCKED "$R" 'FOO=1 git push origin --delete main'
check_in BLOCKED "$R" 'X+=1 git push origin --delete main'
# only a :branch / +:branch refspec deletes; src:dst is an ordinary push
check_in BLOCKED "$R" 'git push origin +:merged-a'
check_in ALLOWED "$R" 'nice git push origin HEAD:feature && date -d tomorrow'
check_in ALLOWED "$R" 'git push origin main:main'
check_in ASKED   "$R" 'GIT_TRACE=0 git push origin --delete merged-b'
# a delete on a later line, or behind a wrapper, is still a delete (review of PR #165)
check_in BLOCKED "$R" "$(printf 'echo hi\ngit push origin --delete main')"
check_in BLOCKED "$R" "$(printf 'git status\ngit push origin :unmerged')"
check_in BLOCKED "$R" 'env git push origin --delete unmerged'
check_in BLOCKED "$R" 'command git push origin --delete main'
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
# v1.69.0: path-qualified git and global options reach the remote-delete check
check_in BLOCKED "$R" '/usr/bin/git push origin --delete unmerged'
check_in BLOCKED "$R" '/usr/bin/git push origin --delete merged-a'
check_in BLOCKED "$R" 'git --no-pager push origin --delete merged-a'
check_in ALLOWED "$R" 'git --no-pager push origin main'
# BL-007: a push-delete inside a nested shell cannot be asked about: blocked
check_in BLOCKED "$R" 'bash -c "git push origin --delete merged-a"'
check_in BLOCKED "$R" "eval 'git push origin :merged-a'"
check_in BLOCKED "$R" 'echo $(git push origin --delete merged-a)'
# BL-010: --mirror / --prune delete remote branches without naming them
check_in BLOCKED "$R" 'git push --mirror origin'
check_in BLOCKED "$R" 'git push --prune origin refs/heads/*:refs/heads/*'
# a bare `:` refspec pushes matching branches; it deletes nothing
check_in ALLOWED "$R" 'git push origin :'
# review round: the merged-branch check must run in the repo the delete runs in
check_in BLOCKED "$R" "{ cd $R; git push origin --delete merged-a; }"
check_in BLOCKED "$R" "pushd $R && git push origin --delete merged-a"
check_in BLOCKED "$R" "builtin cd $R && git push origin --delete merged-a"
check_in BLOCKED "$R" "GIT_DIR=$R/.git git push origin --delete merged-a"
check_in BLOCKED "$R" "export GIT_DIR=$R/.git; git push origin --delete merged-a"
check_in BLOCKED "$R" "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=remote.origin.url GIT_CONFIG_VALUE_0=/x git push origin --delete merged-a"
# ... and an ask may not hide a second delete it could not read
check_in BLOCKED "$R" 'git push origin --delete merged-a && git push origin --{d..d}elete merged-b'
# a redirection is not a branch name
check_in ASKED   "$R" 'git push origin --delete merged-a 2>&1'
check_in ASKED   "$R" 'git push origin --delete merged-a 2>&1 | tail -3'
# re-probe: a lone checkout argument is a path when that file exists in the
# session folder (`a` is a tracked file in $R, `unmerged` only a branch)
check_in BLOCKED "$R" 'git checkout a'
check_in BLOCKED "$R" 'git checkout -m a'
check_in BLOCKED "$R" 'git checkout -q a'
check_in ALLOWED "$R" 'git checkout unmerged'
check_in ALLOWED "$R" 'git checkout -m unmerged'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
