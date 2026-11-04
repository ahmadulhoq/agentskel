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

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
