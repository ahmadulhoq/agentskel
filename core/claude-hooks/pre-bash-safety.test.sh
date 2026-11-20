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
# Usage: bash .claude/hooks/tests/pre-bash-safety.test.sh    (exit 0 = all pass)
#
# MCU-Watchlist copy of agentskel v1.68.1's suite (core/claude-hooks/), run
# against the installed hook one directory up. The upstream cases are
# unchanged; the section marked MCU-Watchlist covers the project's own rules.
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

# --- MCU-Watchlist local rules (2026-08-16; not in agentskel yet) ---
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

# --- rm: only the flags of the same rm invocation count (MCU-Watchlist) ---
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
# blocked by the floor rule: a bundled -rf among what it reads as this rm's own
# arguments (it cannot tell an rm inside a string or comment, and does not
# stop at --; the price of never being weaker than main, third review)
check BLOCKED 'rm -- -rf'
# blocked by the floor rule: a bundled -rf among what it reads as this rm's own
# arguments (it cannot tell an rm inside a string or comment, and does not
# stop at --; the price of never being weaker than main, third review)
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
# blocked by the floor rule: a bundled -rf among what it reads as this rm's own
# arguments (it cannot tell an rm inside a string or comment, and does not
# stop at --; the price of never being weaker than main, third review)
check BLOCKED 'gh pr create --title "hook" --body "Blocks rm path -rf now"'
# blocked by the floor rule: a bundled -rf among what it reads as this rm's own
# arguments (it cannot tell an rm inside a string or comment, and does not
# stop at --; the price of never being weaker than main, third review)
check BLOCKED 'git commit -am "drop rm -rf usage from script"'
# blocked by the floor rule: a bundled -rf among what it reads as this rm's own
# arguments (it cannot tell an rm inside a string or comment, and does not
# stop at --; the price of never being weaker than main, third review)
check BLOCKED "$(printf 'git commit -m \"Fix hook\n\nNow blocks rm path -rf\"')"
check ALLOWED 'rm -r dist 2>/dev/null; npm ci -f'
check ALLOWED 'docker run --rm img ls -rf'
# blocked by the floor rule: a bundled -rf among what it reads as this rm's own
# arguments (it cannot tell an rm inside a string or comment, and does not
# stop at --; the price of never being weaker than main, third review)
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
# --- third review of PR #165: the reader can only ADD blocks. main's rm rule
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
# found in the same review, already missed on main
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
# flag to bash; main's rule caught these and the floor must too
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
# --- 2026-11-08: the floor reads only that rm's own arguments, and only whole
# option words. It used to read from `rm` to the end of the line, so the next
# command's options counted, and it matched -fr inside a longer word: ffmpeg's
# -frames:v after a one-file delete was refused as a recursive force delete.
check ALLOWED 'rm x.jpg; ffmpeg -i a.mp4 -frames:v 1 b.jpg'
check ALLOWED 'rm -f a.jpg; ffmpeg -i a.mp4 -frames:v 1 b.jpg'
check ALLOWED 'rm x.jpg; echo -fr'
check ALLOWED 'rm -f a.jpg && ffmpeg -i a.mp4 -vframes 1 b.jpg'
check ALLOWED 'rm x.jpg || echo -fr'
check ALLOWED 'rm x.jpg 2>/dev/null; ffmpeg -i a.mp4 -frames:v 1 b.jpg'
check ALLOWED 'rm -f "$SP/a.jpg" && ffmpeg -i a.mp4 -vframes 1 "$SP/b.jpg"'
check ALLOWED 'rm "${OUT}/x.jpg"; ffmpeg -i a.mp4 -frames:v 1 b.jpg'
check ALLOWED 'rm -f "$(pwd)/a.jpg"; ffmpeg -i a.mp4 -vframes 1 b.jpg'
check ALLOWED 'rm x.jpg # then ffmpeg -frames:v 1 b.jpg'
# a word that only contains the letters is not the option
check ALLOWED 'rm -i -- -frames:v'
check ALLOWED 'gh pr create --title "Covers" --body "Delete it with rm first, then ffmpeg -frames:v 1"'
check ALLOWED 'rm x.jpg'
check ALLOWED "$(printf 'rm x.jpg\nffmpeg -i a.mp4 -frames:v 1 b.jpg')"
check ALLOWED 'ffmpeg -i a.mp4 -frames:v 1 b.jpg; rm x.jpg'
# still refused: every spelling of a real one, wherever it sits
check BLOCKED 'rm -rf cut3'
check BLOCKED 'rm -rf x'
check BLOCKED 'rm -fr x'
check BLOCKED 'rm -r -f x'
check BLOCKED 'rm --recursive --force x'
check BLOCKED 'cd d && rm -rf x; ls'
check BLOCKED 'rm -f x.jpg; ffmpeg -i a.mp4 -frames:v 1 b.jpg; rm -rf out'
check BLOCKED 'find docs -name "*.pyc" -delete'
# --- review 2026-11-09 of the change above, all reproduced. (1) Real recursive
# force deletes that the reader misses and only main's floor caught: the first
# version let them through. (3) Wrong refusals the first version added: an
# "rm" in prose, a message, a string or a comment, with a quote after it, read
# every command after it (across lines too) as its arguments.
check BLOCKED 'echo "`cd /tmp && rm \"notes #1\" -rf`"'
check BLOCKED 'echo "` rm \"a;b\" -rf`"'
check BLOCKED 'x="` rm \"a|b\" --recursive --force`"'
check BLOCKED 'rm $(case a in a) echo y;; esac) -rf'
check BLOCKED 'rm <(case a in a) echo y;; esac) -rf'
check BLOCKED 'rm -r $(echo ";") -f x'
check BLOCKED 'rm -f $(echo -r x)'
check BLOCKED 'rm $(echo -r ) -f x'
check BLOCKED 'rm -f `echo -r x`'
check BLOCKED 'rm -r $(echo -f x)'
check BLOCKED 'rm -f "$(echo x)" $(echo -r y)'
check BLOCKED 'eval " rm -v -r $(echo --force)"'
check BLOCKED 'bash -c "cd sub && rm x.jpg -r $(echo --force)"'
check BLOCKED 'echo "`cd sub && rm \"a;b\" $(echo --force) {-r,-f}`"'
check BLOCKED 'rm $(echo --force) $(echo -r x)'
check BLOCKED 'rm "a;b" $(echo --force) $(echo -r x)'
# --- 2026-11-09 (owner: "Fix the gaps"): options written in the command but
# reaching rm through a substitution or a variable. Real recursive force
# deletes that main's hook and the reviewed fix both let through (reader on).
# The reader now works out what it can from the text itself: the output of a
# $( ) or ` ` that is one echo or printf of plain words, and a variable given a
# plain value earlier in the same command. Anything not written out stays
# unknown, as before (owner, 2026-11-03), so `rm -f "$f"` is not refused.
check BLOCKED 'rm -r "$(echo -f)" x'
check BLOCKED 'x=-f; rm -r $x y'
check BLOCKED 'rm -r $(echo -f) x'
check BLOCKED 'rm $(echo -f) --rec'
check BLOCKED 'rm $(ls -f) $(echo -f) 2>&1 -R'
check BLOCKED 'echo "`cd sub && rm $(echo -r x) \"$SP/a.jpg\" -v $(echo -f)`"'
check BLOCKED 'rm $(echo -r ) a\;b $(echo -f) `echo x`'
check BLOCKED "rm \$(printf '%s\\n' -r x) -f"
check BLOCKED 'rm -f `echo -r` x'
check BLOCKED 'export x=-r; rm -f $x y'
check BLOCKED 'for o in -r; do rm -f $o y; done'
check BLOCKED 'x="-r -f"; rm $x y'
check BLOCKED 'x=$(echo -f); rm -r $x y'
check BLOCKED 'x=-f; rm -r "${x}" y'
check BLOCKED 'rm -r $(echo -e "-f\nx")'
check BLOCKED 'declare -r o=--force; rm --rec $o y'
# an apostrophe in a comment or heredoc prose is not a quote (found by fuzzing)
check BLOCKED "$(printf '# We rm the cache, it'"'"'s stale\nexport x='"'"'-r -f'"'"'; rm a $x')"
check BLOCKED "$(printf 'cat > n.md <<'"'"'EOF'"'"'\nDon'"'"'t rm it\nEOF\nx=-f; rm -r $x y')"
# a `)` right after esac ends the substitution (the reader took it for one
# more case pattern and read the rest of the line inside the substitution)
check BLOCKED 'rm $(case a in a) echo y;; esac) -R out --force'
check BLOCKED 'rm $(case a in a) echo y;; esac) --recursive --forc'
check BLOCKED 'git push $(case a in a) echo origin;; esac) main --force'
# --- 2026-11-10 (owner: "Fix the gaps", second independent review): the reader
# fill-in is order-aware and reads a chain to a fixed point. ---
# F3: an `esac` after what the reader reads as a pipe is a pattern word, not
# the closer, so main's catch is kept (this was weaker than main before).
check BLOCKED 'rm $(case esac in a|esac) echo x;; esac) -r -f y'
check BLOCKED 'git push $(case esac in a|esac) echo origin;; esac) main --force'
check BLOCKED 'git reset $(case esac in a|esac) echo x;; esac) --hard'
# F2: the nearest earlier assignment wins; a later or reassigned or unset value
# does not reach a use, and a `for`'s values are tried one at a time, not joined
check BLOCKED 'x=-f; x=-rf; rm $x dir'
check ALLOWED 'x=-rf; x=-i; rm $x dir'
check ALLOWED 'rm -r $x y; x=-f'
check ALLOWED 'x=-f; unset x; rm -r $x y'
check ALLOWED '(x=-f); rm -r $x y'
check ALLOWED 'opt=-r; cp $opt a b; opt=-f; rm $opt x.txt'
check ALLOWED 'for b in main dev; do git checkout $b && git pull; done'
check ALLOWED 'b=main; git checkout $b && b=dev; git checkout $b'
check ALLOWED 'for o in -r -f; do rm $o x; done'
check BLOCKED 'for o in -rf; do rm $o x; done'
check BLOCKED 'for o in a -rf b; do rm $o x; done'
# F1: a chain of assignments resolves at one re-read depth, not one per link
check ALLOWED "$(printf 'A=/srv\nB=$A/app\nC=$B/logs\nD=$C/out\nE=$D/x\nrm -f $E; git status')"
check BLOCKED "$(printf 'A=-r\nB=$A\nC=$B\nD=$C\nE=$D\nrm $E -f dir')"
check ALLOWED 'bash -c '"'"'A=1; B=$A; C=$B; D=$C; echo "$D"'"'"'; git status'
# F5: a stray \8 / \9 in printf text is literal, not a crash (which fails closed)
check ALLOWED 'echo "$(printf '"'"'build\9'"'"')"; git status'
check ALLOWED 'echo "$(printf '"'"'v\8'"'"')" && rm -f a.txt'
# --- 2026-11-10, third review: the fill-in is scope-aware, folds guarded
# reassignment, and never drops an option-like loop value past the cap. ---
# F-A: a use inside ( ) / $( ) inherits an outer variable, so a danger carried
# into a subshell or substitution is caught (was missed vs the prior head)
check BLOCKED 'x=-rf; (rm $x dir)'
check BLOCKED 'x=-rf; echo $(rm $x dir)'
check BLOCKED 'x=--hard; (git reset $x)'
check BLOCKED 'x=--hard; echo $(git reset $x)'
check BLOCKED 'flags=--force; (cd sub && git push origin main $flags)'
check ALLOWED 'x=-f; (rm $x)'
check ALLOWED '(x=-rf); rm $x dir'
# F-B: a `&&` / `||` guarded reassignment may not run, so the earlier value is
# still possible and is tried (the guarded empty value does not hide it)
check BLOCKED 'x=-rf; false && x=; rm $x dir'
check BLOCKED 'x=--hard; false && x=; git reset $x'
check BLOCKED 'x=--force; true || x=; git push origin main $x'
check ALLOWED 'x=--hard; x=--soft; git reset $x'
# F-C: an option-like value anywhere in a long `for` list is kept even past the
# variant cap; a loop over many plain filenames is still allowed
check BLOCKED "$(printf 'for x in a b c d e f g h i j k l m n o p q r s t u v w x y z aa bb cc dd ee ff gg hh ii jj kk ll -rf; do rm $x dir; done')"
check ALLOWED "$(printf 'for f in a b c d e f g h i j k l m n o p q r s t u v w x y z aa bb cc dd ee ff gg hh ii jj kk ll mm; do rm -f "$f"; done')"
# a multi-candidate value that word-splits into an option when used UNQUOTED is
# dangerous and must not be collapsed as "plain" (fifth review, 2026-11-10)
check BLOCKED 'for x in safe "a -rf" bar; do rm $x d; done'
check BLOCKED 'x=safe; true && x="a -rf"; rm $x d'
check ALLOWED 'for x in safe "a -rf" bar; do rm "$x" d; done'
# still allowed: nothing here gives rm both options
check ALLOWED "$(printf 'f=out.jpg\nrm -f "$f"\nffmpeg -i a.mp4 -frames:v 1 b.jpg')"
check ALLOWED 'rm -f "$f"'
check ALLOWED 'rm -f $(git ls-files -d)'
check ALLOWED 'rm -f $(cat list.txt)'
check ALLOWED 'rm -f $(echo a.jpg b.jpg)'
check ALLOWED 'for f in a.jpg b.jpg; do rm -f "$f"; done'
check ALLOWED 'x=-r; rm -i $x y'
check ALLOWED 'x=-f; echo "$x"; rm -r y'
check ALLOWED 'echo $(echo -r); rm -f x'
check ALLOWED "rm -r \$(printf '%d' 5) x"
check ALLOWED 'rm -f "x$(echo -r)"'
check ALLOWED "x='-r'; rm -f '\$x' y"
check ALLOWED 'x=$(case a in a) echo y;; esac); ls -f; rm -r z'
check BLOCKED 'rm $(echo -r x) "$(echo --force)" a\;b'
check BLOCKED "$(printf 'rm "a\nb" -rf x')"
check BLOCKED "$(printf 'cat > notes.md <<'"'"'EOF'"'"'\nDon'"'"'t rm it'"'"'s still needed\nEOF\nrm -rf out')"
check ALLOWED "$(printf 'echo "==> rm old outputs"\ncp -r assets out/\nln -sf out/latest current')"
check ALLOWED "$(printf 'echo "Step 1: rm stale thumbnails"\nrm -f thumbs/*.jpg\necho "Step 2: copy"\ncp -r src/assets public/')"
check ALLOWED "$(printf 'git commit -am "Stop the rm step" && git push\ncp -r a b && tail -f log')"
check ALLOWED "$(printf '# rm the cache first, it'"'"'s stale\ncp -r src dst && ln -sf a b')"
check ALLOWED "$(printf 'gh issue comment 5 --body "We rm the cache now"\nsort -r data.txt | cut -f 2')"
check ALLOWED 'echo "Running rm on old builds" && ls -R build | grep -f patterns.txt'
check ALLOWED "$(printf 'cat > notes.md <<'"'"'EOF'"'"'\nDon'"'"'t rm it'"'"'s still needed\nEOF\nffmpeg -i a.mp4 -vframes 1 b.jpg')"
check ALLOWED "$(printf 'echo "Next, rm the old covers"\nffmpeg -i a.mp4 -vframes 1 b.jpg')"
check ALLOWED "$(printf 'python3 - <<'"'"'EOF'"'"'\nprint("then rm it")\nEOF\nls -r out; tail -f log')"
check ALLOWED "echo \" rm it's\"; ls -r x; tail -f y"
check ALLOWED 'rm -r dir $(ls -f)'
check ALLOWED "$(printf 'rm a \\\n# -rf')"
check ALLOWED 'rm "$(dirname "$f")/x.jpg"; cp -r a b; tail -f log'
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
# --- git rules: only the flags of that one git command count (2026-11-03) ---
# The force push, clean, force branch delete, worktree remove, checkout -f and
# reset --hard rules let `.*` run across the whole line, so a later command's
# flag, or a hyphen inside a file or branch name, read as the git command's
# own. Every command in this first group was refused.
check ALLOWED 'git clean -n docs/foo-file'
check ALLOWED 'git clean -n && tail -f log'
check ALLOWED 'git clean -n -- -f'
check ALLOWED 'git clean -n -e keep-f'
check ALLOWED 'git push origin x && tail -f log'
check ALLOWED 'git push -u origin topic-f'
check ALLOWED 'git push origin main && npm install --force'
check ALLOWED 'git push origin main && git branch -f main origin/main'
check ALLOWED 'git push -o ci.skip origin x'
check ALLOWED 'git commit -m "push -f was refused" && git push origin main'
check ALLOWED 'git branch -d old-D'
check ALLOWED 'git branch --delete merged && cp --force a b'
check ALLOWED 'git branch -a | grep -D skip x'
check ALLOWED 'git checkout -b topic-f'
check ALLOWED 'git checkout -bfix'
check ALLOWED 'git checkout main && tail -f log'
check ALLOWED 'git switch -c topic-f'
check ALLOWED 'git switch main && tail -f log'
check ALLOWED 'git worktree remove wt && tail -f log'
check ALLOWED 'git worktree remove wt-f'
check ALLOWED 'git worktree list && rm -f notes.txt'
check ALLOWED 'git reset HEAD notes.md; grep -- --hard notes.md'
check ALLOWED 'git reset --soft HEAD~1 && ls --hard'
# every real spelling, wherever the flag sits in that command
check BLOCKED 'git push origin x --force'
check BLOCKED 'git push origin x -f'
check BLOCKED 'git push -uf origin x'
check BLOCKED 'git push -o ci.skip -f origin x'
check BLOCKED 'git push "-f" origin x'
check BLOCKED "git push origin x '--force'"
check BLOCKED 'git push --forc origin x'
check BLOCKED 'git push --force-w origin x'
check BLOCKED 'git push --force-with-lease=main:abc123 origin main'
check BLOCKED 'git push origin +main'
check BLOCKED 'git push origin +HEAD:main'
check BLOCKED 'git push origin "+main"'
check BLOCKED 'git push --mirror origin'
check BLOCKED 'git push --mir origin'
check BLOCKED 'git --no-pager push -f'
check BLOCKED 'git --git-dir=.git push -f'
check BLOCKED 'git -c core.x=y push --force'
check BLOCKED '/usr/bin/git push -f'
check BLOCKED 'bash -c "git push -f"'
check BLOCKED 'ls && git push -f origin x'
check BLOCKED 'git push origin x && tail -f log && git push -f'
check BLOCKED 'git clean -xfd'
check BLOCKED 'git clean -d -f'
check BLOCKED 'git clean docs -fd'
check BLOCKED 'git clean --forc'
check BLOCKED 'git clean "-f"'
check BLOCKED 'git clean -e "*.log" -f'
check BLOCKED 'git clean -fd -- docs'
check BLOCKED 'git -C /other/repo clean -fd'
check BLOCKED 'ls; git clean -fd'
check BLOCKED "sh -c 'git clean -fd'"
check BLOCKED 'git branch "-D" x'
check BLOCKED 'git branch -rD origin/x'
check BLOCKED 'git branch x -D'
check BLOCKED 'git --no-pager branch -D x'
check BLOCKED 'git worktree remove wt --force'
check BLOCKED 'git worktree remove -f -f wt'
check BLOCKED 'git worktree remove --forc wt'
check BLOCKED 'git worktree remove "-f" wt'
check BLOCKED 'git -C /other/repo worktree remove --force wt'
check BLOCKED 'git --no-pager worktree remove -f wt'
check BLOCKED 'git checkout main -f'
check BLOCKED 'git checkout -qf main'
check BLOCKED 'git checkout -fq main'
check BLOCKED 'git checkout -fb new'
check BLOCKED 'git checkout --forc main'
check BLOCKED 'git checkout "-f" main'
check BLOCKED 'git -C /other/repo checkout -f'
check BLOCKED 'git switch -f main'
check BLOCKED 'git switch --force main'
check BLOCKED 'git switch --discard-changes main'
check BLOCKED 'git switch --discard main'
check BLOCKED 'git switch main --discard-changes'
check BLOCKED 'git -C /other/repo switch -f main'
check BLOCKED 'git reset HEAD~1 --hard'
check BLOCKED 'git reset "--hard"'
check BLOCKED 'git reset --har HEAD~1'
check BLOCKED 'git --no-pager reset --hard'
check BLOCKED 'echo done; git reset --hard'
# the override still works for these rules
check ALLOWED 'AGENTSKEL_UNSAFE=i-understand git push origin +main'
# push --prune deletes every remote branch with no local twin, with none of
# the merged check `git push --delete` gets. It and --mirror (which deletes
# too) are remote deletes, so the override does not apply, as for --delete.
check BLOCKED 'git push --prune origin'
check BLOCKED 'git push --all --prune origin'
check BLOCKED 'git push origin --prun'
check BLOCKED 'git push --prune origin "refs/heads/*:refs/heads/*"'
check BLOCKED 'git -C /other/repo push --prune origin'
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push --prune origin'
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push --mirror origin'
# a block the override covers must not hide one it does not
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push -f --prune origin'
check BLOCKED "AGENTSKEL_UNSAFE=i-understand git -c core.sshCommand='git push --prune o' push -f x"
check ALLOWED 'git push --progress origin main'
check ALLOWED 'git push --no-prune origin main'
check ALLOWED 'git fetch --prune origin'
check ALLOWED 'git remote prune origin'
# checkout of paths from a commit discards those paths' changes, like
# `checkout -- <path>`: a `--` anywhere, two or more names, or a pathspec file
check BLOCKED 'git checkout HEAD~1 -- src/file.ts'
check BLOCKED 'git checkout main -- .'
check BLOCKED 'git checkout main "--" src/file.ts'
check BLOCKED 'git checkout origin/main src/file.ts'
check BLOCKED 'git checkout HEAD .'
check BLOCKED 'git checkout -q main src/a.ts src/b.ts'
check BLOCKED 'git -C /other/repo checkout main -- src/file.ts'
check BLOCKED 'git checkout --pathspec-from-file=list.txt main'
check BLOCKED 'git checkout --pathspec-from-file list.txt'
check ALLOWED 'git checkout -b topic origin/main'
check ALLOWED 'git checkout -B topic origin/main'
check ALLOWED 'git checkout -qb topic origin/main'
check ALLOWED 'git checkout --orphan gh-pages main'
check ALLOWED 'git checkout --track origin/topic'
check ALLOWED 'git checkout -t origin/topic'
check ALLOWED 'git checkout --detach HEAD~2'
check ALLOWED 'git checkout main && git log -- src/x.ts'
check ALLOWED 'git checkout - '
check ALLOWED 'AGENTSKEL_UNSAFE=i-understand git checkout main -- src/file.ts'

# --- review of PR #167 (two reviewers, 2026-11-03) ---
# 1. an option glued to an empty expansion is the option (x unset): main's
#    patterns caught these and the first narrowed floor did not
check BLOCKED 'git push origin main $x-f'
check BLOCKED 'git push origin main ${x}--force'
check BLOCKED 'git push origin main $(:)-f'
check BLOCKED 'git push origin x `:`--force'
check BLOCKED 'git push origin x "$X"-f'
check BLOCKED 'git push origin x *-f'
check BLOCKED 'git push origin ${x:---force-with-lease}'
check BLOCKED 'git push origin x --force$x'
check BLOCKED 'git push origin $x+main'
check BLOCKED 'git push -u$x origin main'
check BLOCKED 'git reset $x--hard'
check BLOCKED 'git reset $(:)--hard'
check BLOCKED 'git reset ${x:---hard}'
check BLOCKED 'git reset --har${x}'
check BLOCKED 'git clean $x-fd'
check BLOCKED 'git clean ${x:--fd}'
check BLOCKED 'git worktree remove $x--force wt'
check BLOCKED 'git branch $x-D feature'
check BLOCKED 'git checkout $x-f main'
check BLOCKED 'git push origin ${x:--f}'
check BLOCKED 'git push origin "${x:-+main}"'
check ALLOWED 'git checkout ${BRANCH:-main}'
check ALLOWED 'git push -u origin "${BRANCH:-topic}"'
# after `--` git push reads -f as a refspec named "-f" (checked: "src refspec
# -f does not match any"); -cf is -c with the value "f"
check ALLOWED 'git push origin main -- -f'
check ALLOWED 'git switch -cf x'
# 2. a `--` with nothing after it is a plain switch. --ours / --theirs was
#    allowed by MCU-Watchlist's owner as conflict resolution; agentskel's
#    owner (2026-11-17) keeps it blocked: it overwrites the file in the
#    working tree, discarding edits or a hand resolution, like
#    `git checkout -- <path>`.
check ALLOWED 'git checkout main --'
check BLOCKED 'git checkout --theirs -- src/a.ts'
check BLOCKED 'git checkout --ours a.ts b.ts'
check ALLOWED 'git checkout "$branch"'
check ALLOWED 'git push origin "$BRANCH"'
# 5. remote deletes in every spelling; only the plain `--delete` / `-d` form
#    reaches the merged-branch check (ASK), everything else is blocked with
#    no override
check BLOCKED 'git push origin --del feature'
check BLOCKED 'git push origin --dele feature'
check BLOCKED 'git push -qd origin feature'
check BLOCKED 'git push -dq origin feature'
check BLOCKED "git push origin ':feature'"
check BLOCKED 'git push origin "":feature'
check BLOCKED 'git push origin \:feature'
check BLOCKED 'git push origin $x:feature'
check BLOCKED "git push origin '+:feature'"
check BLOCKED "AGENTSKEL_UNSAFE=i-understand git push origin '+:feature'"
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push origin --del feature'
check BLOCKED 'git -c remote.origin.push=:refs/heads/feature push origin'
# 6. mirror and force refspecs set by configuration for this one command
check BLOCKED 'git -c remote.origin.mirror=true push origin'
check BLOCKED 'git -c Remote.Origin.Mirror=true push origin'
check BLOCKED "git -c 'remote.origin.push=+refs/heads/*:refs/heads/*' push origin"
check BLOCKED 'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=remote.origin.mirror GIT_CONFIG_VALUE_0=true git push origin'
check BLOCKED "GIT_CONFIG_PARAMETERS=\"'remote.origin.mirror'='true'\" git push origin"
check BLOCKED 'git --config-env=remote.origin.push=REFSPEC push origin'
check ALLOWED 'git -c remote.origin.push=refs/heads/main:refs/heads/main push origin'
check ALLOWED 'git -c push.default=current push -u origin topic'
#    ...and written to a config file, where the next plain push would read it
check BLOCKED 'git config remote.origin.mirror true'
check BLOCKED 'git config --local remote.origin.push +refs/heads/*:refs/heads/*'
check BLOCKED 'git config set remote.origin.push :refs/heads/feature'
check BLOCKED 'git config --add remote.backup.mirror true'
check BLOCKED 'git config clean.requireForce false'
check BLOCKED "git config alias.p 'push -f'"
check BLOCKED "git config --global alias.nuke 'reset --hard'"
check ALLOWED 'git config --get remote.origin.mirror'
check ALLOWED 'git config get remote.origin.push'
check ALLOWED 'git config --unset remote.origin.mirror'
check ALLOWED 'git config remote.origin.push'
check ALLOWED 'git config --list'
check ALLOWED 'git config user.email t@example.com'
check ALLOWED "git config alias.st 'status -sb'"
check ALLOWED 'git config push.autoSetupRemote true'
# 7. aliases and settings given with -c for this one command
check BLOCKED "git -c alias.p='push -f' p origin main"
check BLOCKED "git -c alias.r='reset --hard' r"
check BLOCKED "git -c alias.c='clean -fdx' c"
check BLOCKED "git -c alias.p='push --prune' p origin"
check BLOCKED 'git -c clean.requireForce=false clean -dx'
check ALLOWED "git -c alias.st='status -sb' st"
check ALLOWED 'git -c clean.requireForce=true clean -n'
# 8. git under another name
check BLOCKED '/usr/lib/git-core/git-push -f origin main'
check BLOCKED 'git-reset --hard'
check BLOCKED 'env git-clean -fd'
check BLOCKED '/usr/bin/gi[t] reset --hard'
check BLOCKED 'g?t push --force origin x'
check BLOCKED '/bin/r[m] -rf build'
check ALLOWED 'git-lfs push origin main'
check ALLOWED 'cat git-reset-notes.md'
# 9. a single name that can only be a path: the whole tree, like `checkout .`
check BLOCKED "git checkout '*'"
check BLOCKED 'git checkout ./'
check BLOCKED 'git checkout src/'
check BLOCKED 'git checkout :/'
check BLOCKED "git checkout '*.ts'"
check ALLOWED 'git checkout feature/x'
check ALLOWED 'git checkout HEAD~2'
check ALLOWED 'git checkout v1.2.0'
# 10. plumbing that overwrites the working tree
check BLOCKED 'git checkout-index -f -a'
check BLOCKED 'git checkout-index --force --all'
check BLOCKED 'git checkout-index -fa'
check BLOCKED 'git read-tree -u --reset HEAD'
check BLOCKED 'git read-tree --reset -u HEAD'
check ALLOWED 'git checkout-index -a'
check ALLOWED 'git read-tree -m -u HEAD'
check ALLOWED 'git read-tree --reset HEAD'

# --- second review of PR #167 (two more reviewers, 2026-11-03) ---
# A. a name that starts with a variable is a name: with the variable empty
#    git rejects "-fix" / "-feature" as unknown switches and changes nothing
check ALLOWED 'git push origin "$BRANCH-fix"'
check ALLOWED 'git push -u origin "${USER}-feature"'
check ALLOWED 'git push origin "$(git branch --show-current)-fix"'
check ALLOWED 'git checkout "$PREFIX-feature"'
check ALLOWED 'git switch "$USER-fix"'
check ALLOWED 'git branch -d "$PREFIX-feature"'
check ALLOWED 'git worktree remove "$WT-feature"'
check ALLOWED 'git push origin "$B-done"'
check ALLOWED 'git push origin "$B-delete"'
check ALLOWED "git push origin '*:*'"
check ALLOWED 'git checkout-index -a -f --prefix=out/'
# B. a refspec whose source is a variable deletes the branch when it is
#    empty: blocked, but the override applies (owner: 1b). A literal
#    :branch is a delete and never overridable.
check BLOCKED 'git push origin "$BRANCH:$BRANCH"'
check BLOCKED 'git push origin "$(git rev-parse HEAD):refs/heads/x"'
check ALLOWED 'AGENTSKEL_UNSAFE=i-understand git push origin "$BRANCH:$BRANCH"'
check ALLOWED 'AGENTSKEL_UNSAFE=i-understand git push origin $LOCAL:$REMOTE'
check BLOCKED "AGENTSKEL_UNSAFE=i-understand git push origin ':feature'"
# an option hidden in an expansion may be -d: blocked, override applies (1b)
check BLOCKED 'git push -u$x origin main'
check ALLOWED 'AGENTSKEL_UNSAFE=i-understand git push -u$x origin main'
# C. (the floor alone is tested at the end of this file)
check BLOCKED 'git push --force-with-lease="main:$SHA" origin main'
check BLOCKED 'git push --force-with-lease=$REF origin main'
check BLOCKED "git push origin 'a;b' -f"
check BLOCKED 'git push origin x\ -- -f'
# D. a long command naming git many times is checked quickly, not timed out
LONGPUSH="echo docs: $(printf 'git push %.0s' $(seq 3500))"
quick ALLOWED 3 "$LONGPUSH"
quick ALLOWED 3 "echo $(printf 'git %.0s' $(seq 6000))"
quick BLOCKED 3 "$LONGPUSH; git push -f"
# F/G. config: an option hidden in an expansion is not a read; an alias
#    ending in `--` checks out paths when used
check BLOCKED 'git config -$x remote.origin.mirror true'
check BLOCKED 'git config alias.discard "checkout --"'
# I. alias text is split the way git splits it (quotes removed), and an
#    alias may start with options
check BLOCKED "AGENTSKEL_UNSAFE=i-understand git -c alias.p=\"push -f origin ':u1'\" p"
check BLOCKED "AGENTSKEL_UNSAFE=i-understand git -c alias.p=\"push origin '+:u1'\" p"
check BLOCKED "git -c alias.p=\"push '-f'\" p origin main"
check BLOCKED "git -c alias.p=\"push origin ':u1'\" p"
check BLOCKED "GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=alias.p GIT_CONFIG_VALUE_0=\"push '-f'\" git p origin main"
check BLOCKED "git config alias.p \"push '-f'\""
check BLOCKED "git config alias.p '-c remote.origin.mirror=true push'"
check BLOCKED "git -c alias.p='-c remote.origin.mirror=true push' p origin"
# J. an empty expansion before or inside the subcommand
check BLOCKED 'git $x push --force origin main'
check BLOCKED 'git ${x} reset --hard'
check BLOCKED 'git $(:) clean -fdx'
check BLOCKED 'git `true` checkout -f'
check BLOCKED 'git $x push --mirror origin'
check BLOCKED 'git $x push origin :feat'
check BLOCKED 'git $x branch -D feat'
check BLOCKED 'git push$x -f origin main'
check BLOCKED 'git reset$x --hard'
check BLOCKED 'git ${x:-push} -f'
check BLOCKED 'git config $x remote.origin.mirror true'
check BLOCKED 'git -c alias.p="push -f" $x p'
# K. input built to crash the reader: escapes are decoded before the
#    fallback looks for git / rm, and no override applies to git then
check BLOCKED "echo {a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}; git \$'\\x70ush' --mirror origin"
check BLOCKED "echo {a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}; git \$'\\x72eset' --hard"
check BLOCKED "echo {a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}; r\$'\\x6d' -rf /tmp/zz"
# L. an alias whose text is not in the command is blocked
check BLOCKED 'X="push --force" git --config-env=alias.p=X p origin main'
check BLOCKED "GIT_CONFIG_PARAMETERS=\"'alias.p'='push --force'\" git p origin main"
check BLOCKED "GIT_CONFIG_PARAMETERS=\"'alias.p'\" git p origin main"
# M. fallback words bash decodes: \-f, $'-f', nested ${ }, array elements
check BLOCKED 'git push origin main ${x:-\-f}'
check BLOCKED "git push origin main \${x:-\$'-f'}"
check BLOCKED 'git push origin main ${x:-${y:--f}}'
check BLOCKED 'git push origin main ${a[0]:--f}'
# N. git-<sub> written as a glob, and git behind a wrapper's own options
check BLOCKED '/usr/lib/git-core/git-p?sh -f origin main'
check BLOCKED 'gi[t]-push -f origin main'
check BLOCKED 'git-[p]ush -f origin main'
check BLOCKED 'git-rese? --hard'
check BLOCKED 'timeout 10 /usr/lib/git-core/git-push -f'
check BLOCKED 'sudo -u bob /usr/lib/git-core/git-push -f'
check BLOCKED 'nice -n 5 gi[t] push -f'
# O. --ours / --theirs: blocked for the whole tree (MCU) and, in agentskel,
#    for files too (owner, 2026-11-17; see 2. above)
check BLOCKED 'git checkout --ours .'
check BLOCKED 'git checkout --theirs -- .'
check BLOCKED 'git checkout --theirs -- src/'
check BLOCKED 'git checkout --ours -- src/a.ts'

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
# second review of PR #167: a plain delete the merged-branch check never sees
# (its prefilter and parser read text, the reader reads bash) is blocked
check_in BLOCKED "$R" 'git --no-pager push origin --delete unmerged'
check_in BLOCKED "$R" 'git --no-pager push origin --delete merged-a'
check_in BLOCKED "$R" 'git -p push origin --delete unmerged'
check_in BLOCKED "$R" '"git" push origin --delete unmerged'
check_in BLOCKED "$R" '\git push origin --delete unmerged'
check_in BLOCKED "$R" "git 'push' origin --delete unmerged"
check_in BLOCKED "$R" '/usr/bin/git push origin --delete unmerged'
check_in BLOCKED "$R" "git push origin --del''ete unmerged"
check_in BLOCKED "$R" 'git push origin -""d unmerged'
check_in BLOCKED "$R" "git push origin \$'--delete' unmerged"
check_in BLOCKED "$R" '(git push origin --delete unmerged)'
check_in BLOCKED "$R" 'echo $(git push origin --delete unmerged)'
check_in BLOCKED "$R" 'bash -c "git push origin --delete unmerged"'
check_in BLOCKED "$R" '/usr/lib/git-core/git-push origin --delete unmerged'
check_in BLOCKED "$R" 'git push origin --delete merged-a; echo `git push origin --delete unmerged`'
check_in ASKED   "$R" 'git push origin --delete merged-a && git fetch --prune'

# --- third review of PR #167 (two more reviewers, 2026-11-04) ---
# 1. an "ask" must name the branch that actually runs. A delete hidden in
#    backticks with a decoy after a comment used to match on count and ask for
#    the merged decoy while the unmerged one ran.
check_in BLOCKED "$R" 'echo `git push origin --delete unmerged` # ; git push origin --delete merged-a'
check_in BLOCKED "$R" 'echo `git push origin --delete merged-a` ; git push origin --delete unmerged'
# a real top-level delete plus a comment or redirection still asks
check_in ASKED   "$R" 'git push origin --delete merged-a # cleanup'
check_in ASKED   "$R" 'git push origin --delete merged-a 2>&1'
# 6/7. a real merged delete plus an echo that merely mentions another delete.
#    MCU-Watchlist asks; agentskel (owner, 2026-11-17: the stricter side wins
#    where a delete may hide) blocks. The reader cannot tell echo text from a
#    bash -c payload, and a quoted delete that rides along with an approved
#    one would run unasked (`... && bash -c "git push origin --delete y"`).
check_in BLOCKED "$R" 'git push origin --delete merged-a && echo "next: git push origin --delete merged-b"'
check_in BLOCKED "$R" 'git push origin --delete merged-a && bash -c "git push origin --delete unmerged"'
check_in BLOCKED "$R" 'git push origin --delete merged-a && echo "git push origin --delete unmerged" | sh'
# the hook's own parser reads a `#` only at the start of a word: "merged-a#2"
# is one branch name (shlex would cut it to "merged-a" and ask about that)
check_in BLOCKED "$R" 'git push origin --delete merged-a#2'
# 2. git-push behind an unlisted wrapper, and find -exec
check_in BLOCKED "$R" 'setsid /usr/lib/git-core/git-push origin --delete unmerged'
# 3. a plain delete with -d before the remote still reaches the merged check
check_in ASKED   "$R" 'git push -d origin merged-a'
check_in BLOCKED "$R" 'git push -d origin unmerged'
check_in ASKED   "$R" 'git push --delete origin merged-a merged-b'
# a glued-fallback delete is seen (unmerged blocks); the merged check cannot
# resolve the glued spelling, so even a merged target blocks rather than asks —
# safe, write it plainly to get an ask
check_in BLOCKED "$R" 'git push origin${x:- --delete} unmerged'
check_in BLOCKED "$R" 'git push origin${x:- --delete} merged-a'
# the reader and the merged check read the same (heredoc-aware) text, so their
# delete counts agree: an unmerged delete quoted in a kept heredoc body blocks
check_in BLOCKED "$R" "$(printf 'git push origin --delete merged-a\ncat <<EOF\ngit push origin --delete unmerged\nEOF')"
# a delete flag after a newline inside a fallback reaches the remote-delete
# path (protected main + unmerged both deleted by bash) -> blocked
check_in BLOCKED "$R" "$(printf 'git push origin${x:- main\n--delete} unmerged')"

# 2 (override must not reach a trailing-expansion remote delete/force)
check BLOCKED 'git push --mirror$x origin'
check BLOCKED 'git push --prune$x origin'
check BLOCKED 'git push origin --delete$x wip'
check BLOCKED 'git push origin --delete"$x" wip'
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push --mirror$x origin'
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push --prune$x origin'
check BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push origin --delete$x wip'
# a leading-expansion option stays owner-1b (overridable): $x empty is --mirror,
# any other value is a branch name
check BLOCKED 'git push origin $x--mirror'
check ALLOWED 'AGENTSKEL_UNSAFE=i-understand git push origin $x--mirror'
# 3. checkout-index --prefix only exempts a plain relative subfolder
check BLOCKED 'git checkout-index -a -f --prefix="$PWD/"'
check BLOCKED 'git checkout-index -a -f --prefix=src/../'
check BLOCKED 'git checkout-index -a -f --prefix=/etc/'
check ALLOWED 'git checkout-index -a -f --prefix=out/'
check ALLOWED 'git checkout-index -a -f --prefix=build/x/'
# 4. git config set <options> key value (git 2.46+): options are not the key
check BLOCKED 'git config set --local remote.origin.mirror true'
check BLOCKED "git config set --global alias.p 'push --mirror origin'"
check ALLOWED 'git config set --local user.name me'
# 5. a glob argument after a wrapper is not a command named rm
check ALLOWED 'sudo cp * /var/www/ -rf'
check ALLOWED 'timeout 30 cp * /backup/ -rf'
check ALLOWED 'grep -l sudo * -r -f pats.txt'
check ALLOWED 'sudo cp file dest'
# 7. other remote/local deletes and overwrites
check BLOCKED 'git send-pack ../remote.git :unmerged'
check BLOCKED 'git send-pack origin --force refs/heads/x'
check BLOCKED 'git send-pack origin +refs/heads/x:refs/heads/x'
check BLOCKED 'git update-ref -d refs/heads/x'
check BLOCKED 'git update-ref --delete refs/heads/x'
check BLOCKED 'git --no-pager stash drop'
check BLOCKED 'git --no-pager stash clear'
check BLOCKED 'env git stash drop'
check BLOCKED "gh api -X \$'DELETE' repos/o/r/git/refs/heads/x"
check ALLOWED 'git send-pack origin refs/heads/x:refs/heads/x'
check ALLOWED 'git update-ref refs/heads/x HEAD'
check ALLOWED 'git branch -m old new'
check ALLOWED 'git stash'
check ALLOWED 'git stash list'
check ALLOWED 'git stash pop'
# 8. an unquoted ${x:-W} fallback is word-split, so a -f in it is an option
check BLOCKED 'git push origin ${x:-main -f}'
check BLOCKED 'git reset ${x:-HEAD --hard}'
check ALLOWED 'git checkout ${x:-main}'
check ALLOWED 'git push -u origin "${BRANCH:-topic -f}"'
# a flag in a fallback glued to the preceding word still word-splits (bash runs
# `git reset --hard`): the leading space is a boundary (third review of PR #167)
check BLOCKED 'git reset${x:- --hard}'
check BLOCKED 'git push origin${x:- -f}'
check BLOCKED 'git push origin${x:- --mirror}'
check BLOCKED 'git branch${x:- -D} feature'
check BLOCKED 'git clean${x:- -fd}'
check BLOCKED 'git checkout${x:- -f}'
check BLOCKED 'git reset${x:-X --hard}'
check BLOCKED 'git reset${x:=  --hard}'
check ALLOWED 'git checkout${x:- main}'
check ALLOWED 'cp file dest${x:- -v}'
# quoted, bash does not word-split, so the glued fallback is one argument
check ALLOWED 'git push origin"${x:- --delete}" wip'
# a flag after a NEWLINE inside the fallback is IFS-split by bash too (fourth
# review of PR #167): every fallback word is read, not just the first
check BLOCKED "$(printf 'git reset${x:- HEAD\n--hard}')"
check BLOCKED "$(printf 'git clean${x:- docs\n-fd}')"
check BLOCKED "$(printf 'git checkout${x:- file\n-f}')"
check BLOCKED "$(printf 'git push origin${x:- x\n--mirror}')"
check BLOCKED "$(printf 'git branch${x:- -D\nfeature}')"
# a short option split across two parameter-defaults: `${x:--}${y:-f}` is -f
# (sixth review of PR #167) — the interior placeholder no longer demotes it
check BLOCKED 'git push origin ${x:--}${y:-f}'
check BLOCKED 'git push ${x:--}${y:--mirror} origin'
check BLOCKED 'git push origin ${x:--}${y:--delete} a b'
check BLOCKED 'git push origin ${a:--}${b:--del}${c:-ete} a b'
check BLOCKED 'git branch ${x:--}${y:-D} feature'
check BLOCKED 'git checkout ${x:--}${y:-f}'
check BLOCKED 'git reset ${x:---}${y:-hard}'
# built from a variable, so the override still applies (owner 1b)
check ALLOWED 'AGENTSKEL_UNSAFE=i-understand git push origin ${x:--}${y:-f}'
# a real branch name glued to a variable is still not read as flags
check ALLOWED 'git push origin "$BRANCH-fix"'
check ALLOWED 'git checkout "$PREFIX-feature"'
# A forced branch move/copy (-M, -C, -f -m, --move --force) replaces the
# target branch if it exists. agentskel's owner (2026-11-17): blocked only
# when the target exists (or cannot be checked: a variable, another repo via
# cd / -C / GIT_DIR, or a branch an earlier command in the line may create);
# otherwise nothing is lost and it is allowed. MCU-Watchlist allows every
# single-name form and blocks every two-name form, so each two-name case it
# blocked runs here with an absent target (allowed) and a twin whose target
# exists (blocked). Run in $R, where the branches are known.
check_in BLOCKED "$R" 'git branch -M feature main'
check_in BLOCKED "$R" 'git branch -M x main'
check_in ALLOWED "$R" 'git branch -C old new'
check_in BLOCKED "$R" 'git branch -C old merged-a'
check_in ALLOWED "$R" 'git branch --move --force a b'
check_in BLOCKED "$R" 'git branch --move --force a unmerged'
check_in ALLOWED "$R" 'git branch -M main'
check_in ALLOWED "$R" 'git branch -C topic'
check_in BLOCKED "$R" 'git branch -M "$BRANCH"'
check_in ALLOWED "$R" 'git branch -M -- solo'
check ALLOWED 'git branch -m old new'
check ALLOWED 'git branch -c a b'
# operands after `--`, and a lowercase move with a separate force (fourth
# review of PR #167): blocked when the target exists
check_in ALLOWED "$R" 'git branch -M -- old new'
check_in BLOCKED "$R" 'git branch -M -- old merged-b'
check_in ALLOWED "$R" 'git branch -M old -- new'
check_in BLOCKED "$R" 'git branch -M old -- squashed'
check_in ALLOWED "$R" 'git branch -C -- a b'
check_in BLOCKED "$R" 'git branch -C -- a merged-a'
check_in ALLOWED "$R" 'git branch -f -m old new'
check_in BLOCKED "$R" 'git branch -f -m old unmerged'
check_in ALLOWED "$R" 'git branch -mf old new'
check_in BLOCKED "$R" 'git branch -mf old merged-a'
# agentskel (2026-11-17): the single-name form replaces an existing branch
# too, unless it is the current branch; and an unverifiable target blocks
check_in BLOCKED "$R" 'git branch -M merged-a'
check_in BLOCKED "$R" 'git branch -C unmerged'
check_in BLOCKED "$R" 'git branch -M MERGED-A'
check_in BLOCKED "$R" 'git branch topic2 && git branch -M topic2'
check_in BLOCKED "$R" 'git checkout -b t3 && git branch -M x t3'
check_in BLOCKED "$R" 'git switch -c t4; git branch -C t4'
check_in BLOCKED "$R" 'cd .. && git branch -M solo'
check_in BLOCKED "$R" 'git -C /tmp branch -M solo'
check_in BLOCKED "$R" 'GIT_DIR=/tmp/x git branch -M solo'
check_in BLOCKED "$R" 'git branch -M $(echo merged-a)'
check_in BLOCKED "$R" 'bash -c "git branch -M merged-a"'
check_in ALLOWED "$R" 'git add -A && git commit -m init && git branch -M solo && git push -u origin solo'
# 9. a brace bomb no longer blinds the reader (it keeps the word unexpanded)
check BLOCKED "echo {a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}; git push --mirror origin"
check BLOCKED "echo {a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}; git \$'\\x70ush' --mirror origin"
check BLOCKED "echo {a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}{a,b}; /usr/bin/g?t push --force origin main"

# --- the git floor alone (reader switched off) never lets through what
# main's patterns caught, apart from the wrong refusals this PR removes
# (second review of PR #167: the first two versions of the floor did) ---
FLOOR="$TMP/floor"; mkdir -p "$FLOOR"
cp "$(dirname "$HOOK")/pre-bash-safety.sh" "$(dirname "$HOOK")/pre-bash-heredocs.py" "$FLOOR/"
[ -f "$(dirname "$HOOK")/pre-bash-safety-engine.sh" ] && cp "$(dirname "$HOOK")/pre-bash-safety-engine.sh" "$FLOOR/"
printf 'print("ALLOW")\n' > "$FLOOR/pre-bash-commands.py"
floor() { # floor <BLOCKED|ALLOWED> <command>
  local want="$1" cmd="$2" got
  printf '%s' "$cmd" | python3 -c \
    'import json,sys; print(json.dumps({"tool_input":{"command":sys.stdin.read()}}))' \
    | "$FLOOR/pre-bash-safety.sh" >/dev/null 2>&1
  [ $? = 2 ] && got=BLOCKED || got=ALLOWED
  if [ "$got" = "$want" ]; then pass=$((pass+1));
  else fail=$((fail+1)); printf 'FAIL  floor expected %-7s got %-7s : %s\n' "$want" "$got" "$cmd"; fi
}
floor BLOCKED 'git push --force origin main'
floor BLOCKED 'git push -f'
floor BLOCKED 'git reset --hard'
floor BLOCKED 'git clean -fd'
floor BLOCKED 'git branch -D x'
floor BLOCKED 'git worktree remove --force wt'
floor BLOCKED 'git checkout -f'
floor BLOCKED 'git push origin main $x-f'
floor BLOCKED 'git push origin x `:`--force'
floor BLOCKED 'git reset ${x:---hard}'
floor BLOCKED 'git clean $x-fd'
floor BLOCKED 'git branch $x-D feature'
floor BLOCKED 'git worktree remove $x--force wt'
floor BLOCKED 'git push --force-with-lease="main:$SHA" origin main'
floor BLOCKED 'git push --force-with-lease=$REF origin main'
floor BLOCKED "git push origin 'a;b' -f"
floor BLOCKED 'git push origin x\ -- -f'
floor BLOCKED 'git clean "-f"'
floor BLOCKED 'git reset "--hard"'
floor ALLOWED 'git push origin x && tail -f log'
floor ALLOWED 'git clean -n docs/foo-file'
floor ALLOWED 'git branch -d old-D'
floor ALLOWED 'git checkout -b topic-f'
floor ALLOWED 'git push origin main -- -f'

# --- the rm floor alone (reader switched off), 2026-11-08: when it can be
# sure where an rm starts and ends, it reads that rm's own arguments as bash
# splits them, so a one-file delete followed by ffmpeg's -frames:v / -vframes
# is not a recursive force delete; a quoted or escaped separator, a
# redirection, a substitution or an escaped blank before # does not end rm.
# Whenever it cannot be sure (the rm sits inside a quote, a substitution or a
# comment on its line, or something in its arguments leaves the end in doubt)
# it applies main's rule to that rm exactly (review, 2026-11-09). Either way
# it counts whole option words only.
floor ALLOWED 'rm x.jpg; ffmpeg -i a.mp4 -frames:v 1 b.jpg'
floor ALLOWED 'rm -f a.jpg; ffmpeg -i a.mp4 -frames:v 1 b.jpg'
floor ALLOWED 'rm x.jpg; echo -fr'
floor ALLOWED 'rm -f a.jpg && ffmpeg -i a.mp4 -vframes 1 b.jpg'
floor ALLOWED 'rm x.jpg || echo -fr'
floor ALLOWED 'rm x.jpg | ffmpeg -i - -frames:v 1 b.jpg'
floor ALLOWED 'rm x.jpg 2>/dev/null; ffmpeg -i a.mp4 -frames:v 1 b.jpg'
floor ALLOWED 'rm -f "$SP/a.jpg" && ffmpeg -i a.mp4 -vframes 1 "$SP/b.jpg"'
floor ALLOWED 'rm "${OUT}/x.jpg"; ffmpeg -i a.mp4 -frames:v 1 b.jpg'
floor ALLOWED 'rm -f "$(pwd)/a.jpg"; ffmpeg -i a.mp4 -vframes 1 b.jpg'
floor ALLOWED 'rm x.jpg # then ffmpeg -frames:v 1 b.jpg'
floor ALLOWED 'rm -i -- -frames:v'
floor ALLOWED 'gh pr create --title "Covers" --body "Delete it with rm first, then ffmpeg -frames:v 1"'
floor ALLOWED "$(printf 'rm x.jpg\nffmpeg -i a.mp4 -frames:v 1 b.jpg')"
floor ALLOWED 'ffmpeg -i a.mp4 -frames:v 1 b.jpg; rm x.jpg'
floor ALLOWED 'rm -r old-dir; ls -f notes'
floor ALLOWED 'rm -r a && rm -f b'
floor ALLOWED 'rm --force notes.txt'
floor ALLOWED 'rm notes-confirmed-four.txt; ls out/run-confirmed-final'
floor BLOCKED 'rm -rf cut3'
floor BLOCKED 'rm -rf x'
floor BLOCKED 'rm -fr x'
floor BLOCKED 'rm -Rf x'
floor BLOCKED 'rm -rfv x'
floor BLOCKED 'rm -vrf x'
floor BLOCKED 'rm -r -f x'
floor BLOCKED 'rm x -rf'
floor BLOCKED 'rm -r x -f'
floor BLOCKED 'rm --recursive --force x'
floor BLOCKED 'rm --recursive -f x'
floor BLOCKED 'rm "-rf" x'
floor BLOCKED "rm '-r' '-f' x"
floor BLOCKED 'cd d && rm -rf x; ls'
floor BLOCKED 'rm -f x.jpg; ffmpeg -i a.mp4 -frames:v 1 b.jpg; rm -rf out'
floor BLOCKED 'find docs -name "*.pyc" -delete'
# a flag glued to something bash removes is still that flag
floor BLOCKED 'rm -rf"" y'
floor BLOCKED 'rm -rf$x y'
floor BLOCKED 'rm -rf{,} y'
floor BLOCKED 'rm $x-rf y'
floor BLOCKED 'rm $x--force -r y'
floor BLOCKED 'rm ${u:--rf} y'
floor BLOCKED 'rm -r ${u:---force} y'
floor BLOCKED 'rm {-rf,} x'
floor BLOCKED 'rm {--force,-r} x'
# none of these ends rm's arguments
floor BLOCKED 'rm "a;b" -rf x'
floor BLOCKED "rm 'a|b' -r -f x"
floor BLOCKED 'rm a\;b -rf x'
floor BLOCKED 'rm -r x 2>&1 -f'
floor BLOCKED 'rm -r x &>/dev/null -f'
floor BLOCKED 'rm -r x >|log -f'
floor BLOCKED 'rm -r $(cat list) -f'
floor BLOCKED 'rm x\ #y -rf z'
floor BLOCKED 'echo " rm a"; rm "b;c" -rf'
# an escaped line break carries rm's arguments on, as in bash; main's rule
# never saw these. (A quote does not: `rm "a<newline>b" -rf x` is the reader's,
# as on main, and so are `rm -r $(echo ";") -f x`, `$[1|0]` and extglob.)
floor BLOCKED "$(printf 'rm -r x \\\n -f')"
floor BLOCKED "$(printf 'rm -r\\\nf x')"
floor BLOCKED 'rm --rec --forc x'
floor BLOCKED "rm -r'f' y"
floor BLOCKED 'rm -{r,f} x'
floor BLOCKED 'rm -r{f,} x'
# a substitution's own options are not rm's (`$(ls -f)`), but a whole -rf or
# a long option in one is (bash pastes its output into rm's arguments)
floor ALLOWED 'rm -r dir $(ls -f)'
# second review 2026-11-09: main's one-command rule counted a blank-separated
# -r or -f inside a substitution too, and bash pastes the output into rm's
# arguments, so these are real deletes the first P reading let through
floor BLOCKED 'rm -f $(echo -r x)'
floor BLOCKED 'rm $(echo -r ) -f x'
floor BLOCKED 'rm -f `echo -r x`'
floor BLOCKED 'rm -r $(echo -f x)'
floor BLOCKED 'rm -f "$(echo x)" $(echo -r y)'
floor BLOCKED 'rm -f <(echo -r ) x'
# found by fuzzing the second version: main read a long word glued to
# something (`--force)`, `"--force"`) as -f...r, which caught these real
# deletes inside a string; and a brace list is -r -f to rm
floor BLOCKED 'eval " rm -v -r $(echo --force)"'
floor BLOCKED 'bash -c "cd sub && rm x.jpg -r $(echo --force)"'
floor BLOCKED 'echo "`cd sub && rm \"a;b\" $(echo --force) {-r,-f}`"'
floor BLOCKED 'bash -c "cd sub && rm \"a;b\" {-r,-f}"'
floor BLOCKED 'rm $(case a in a) echo y;; esac) {-r,-f}'
# read as main read it: --force glued to ) counts as -f...r (both ways, fuzz
# seed 31); main refused this too
floor BLOCKED 'rm $(echo --force) x'
floor BLOCKED 'rm "a;b" $(echo --force) $(echo -r x)'
# a -r or -f main counted pairs with a long option too (found by fuzzing), and
# an escaped ; & | is never the end of a command, in any quoting
floor BLOCKED 'rm $(echo --force) $(echo -r x)'
floor BLOCKED 'rm $(echo -r x) "$(echo --force)" a\;b'
floor BLOCKED "rm -f x\\ #y a\\;b \$(printf '%s\\n' -r x)"
floor BLOCKED 'rm $(echo -rf) x'
floor BLOCKED 'rm -r $(echo --force) x'
floor BLOCKED 'rm -r `echo --force` x'
# review 2026-11-09 (1, 2): an rm inside a string or a substitution, which
# bash runs, is read as main read it, so the floor alone still catches these
floor BLOCKED 'echo "`cd /tmp && rm \"notes #1\" -rf`"'
floor BLOCKED 'echo "` rm \"a;b\" -rf`"'
floor BLOCKED 'x="` rm \"a|b\" --recursive --force`"'
floor BLOCKED 'rm $(case a in a) echo y;; esac) -rf'
floor BLOCKED 'rm <(case a in a) echo y;; esac) -rf'
floor BLOCKED 'bash -c "cd /tmp && rm \"a;b\" -rf"'
floor BLOCKED 'bash -c "cd /tmp && rm \"draft #2\" -rf"'
floor BLOCKED 'eval " rm a \";\" -rf"'
floor BLOCKED 'sh -c "set -e; rm \"x|y\" -rf"'
floor BLOCKED 'trap "cd /tmp && rm \"a;b\" -rf" EXIT'
floor BLOCKED 'bash <<< " rm \"a;b\" -rf"'
floor BLOCKED "bash -c \$'cd /tmp && rm \\'a;b\\' -rf'"
floor BLOCKED 'bash -c "cd /tmp && rm \"a;b\" --recursive --force"'
floor BLOCKED "$(printf 'bash -c "\ncd /tmp && rm \\"a;b\\" -rf\n"')"
floor BLOCKED 'eval "cd x; rm -r " -f y'
floor BLOCKED 'x=$(cd a; rm -rf b)'
# review 2026-11-09 (3): an "rm" in prose, a message, a string or a comment,
# with a quote after it, does not read the commands after it as its own
floor ALLOWED "$(printf 'echo "==> rm old outputs"\ncp -r assets out/\nln -sf out/latest current')"
floor ALLOWED "$(printf 'echo "Step 1: rm stale thumbnails"\nrm -f thumbs/*.jpg\necho "Step 2: copy"\ncp -r src/assets public/')"
floor ALLOWED "$(printf 'git commit -am "Stop the rm step" && git push\ncp -r a b && tail -f log')"
floor ALLOWED "$(printf '# rm the cache first, it'"'"'s stale\ncp -r src dst && ln -sf a b')"
floor ALLOWED "$(printf 'gh issue comment 5 --body "We rm the cache now"\nsort -r data.txt | cut -f 2')"
floor ALLOWED 'echo "Running rm on old builds" && ls -R build | grep -f patterns.txt'
floor ALLOWED 'echo "Running rm on old builds" && ls -R build | grep -f "x"'
floor ALLOWED "$(printf 'cat > notes.md <<'"'"'EOF'"'"'\nDon'"'"'t rm it'"'"'s still needed\nEOF\nffmpeg -i a.mp4 -vframes 1 b.jpg')"
floor ALLOWED "$(printf 'echo "Next, rm the old covers"\nffmpeg -i a.mp4 -vframes 1 b.jpg')"
floor ALLOWED "$(printf 'python3 - <<'"'"'EOF'"'"'\nprint("then rm it")\nEOF\nls -r out; tail -f log')"
floor ALLOWED "echo \" rm it's\"; ls -r x; tail -f y"
floor ALLOWED "$(printf 'echo "first line\nsecond rm x"; ls -r "a"; tail -f b')"
floor ALLOWED "$(printf 'rm a \\\n# -rf')"
floor ALLOWED 'rm "$(dirname "$f")/x.jpg"; cp -r a b; tail -f log'
floor BLOCKED "$(printf 'cat > notes.md <<'"'"'EOF'"'"'\nDon'"'"'t rm it'"'"'s still needed\nEOF\nrm -rf out')"
# the price of a floor that cannot tell an rm inside a string, or after --
floor BLOCKED 'rm -- -rf'
floor BLOCKED 'gh pr create --title "hook" --body "Blocks rm path -rf now"'

# --- agentskel v1.69.0 differential (2026-11-18): with the reader switched
# off, the floor let the override through a push that prunes or mirrors (the
# force-push floor rule is overridable; --prune / --mirror were only the
# reader's), and the merged-delete parser missed a delete inside backticks
# or $( ) once the comment after it was read as a comment ---
floor BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push -f --prune origin'
floor BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push --mirror origin'
floor BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push origin --prune'
floor BLOCKED 'git push --prune origin'
floor BLOCKED 'AGENTSKEL_UNSAFE=i-understand git push "--mirror" origin'
# a variable in front is an option built from a variable: overridable
floor ALLOWED 'AGENTSKEL_UNSAFE=i-understand git push origin $x--mirror'
floor ALLOWED 'git fetch --prune'
floor ALLOWED 'git push origin main && git fetch --prune'
floor BLOCKED 'echo `git push origin --delete unmerged` # ; git push origin --delete merged-a'
floor BLOCKED 'echo `git push origin --delete unmerged` # note'
floor BLOCKED 'echo $(git push origin --delete unmerged) # note'
floor BLOCKED 'x=$(git push origin :unmerged) # note'
check ALLOWED 'git fetch --prune'
check ALLOWED 'git remote prune origin --dry-run'
# ...and an rm in a subshell or substitution: the reader read `$x-rf` as a
# name (PR #61's reader read the empty-variable form; MCU's leaves that to the
# floor), and the floor only found an rm after a space or ; & |, so `(rm`,
# `$(rm` and a backtick hid it; inside one the floor's doubtful reading did
# not count `$x-rf` either
check BLOCKED '(rm $x-rf /tmp/zz)'
check BLOCKED '(rm $9-rf y)'
check BLOCKED '(rm `:`-rf y)'
check BLOCKED '(rm $x--force -r y)'
check BLOCKED 'echo $(rm $x-rf y)'
check BLOCKED 'echo `rm $x-rf y`'
floor BLOCKED '(rm -rf y)'
floor BLOCKED 'echo $(rm -rf y)'
floor BLOCKED 'echo `rm -rf y`'
floor BLOCKED '{ rm -r -f y; }'
floor BLOCKED '(rm $x-rf /tmp/zz)'
floor BLOCKED '(rm `:`-rf y)'
floor BLOCKED 'echo $(rm $x--force -r y)'
check ALLOWED 'rm "$OUT-firmware.bin"'
check ALLOWED '(rm $x-report.txt "$y-final-firmware.bin")'
floor ALLOWED 'rm "$OUT-firmware.bin"'
floor ALLOWED '(rm $x-report.txt "$y-final-firmware.bin")'
floor ALLOWED '(cd sub && rm -f a.jpg); ffmpeg -i a.mp4 -frames:v 1 b.jpg'

# --- review of the MCU merge (2026-11-20) ---
# Aliases already stored in the repo's config, called with no option: MCU's
# reader skips a git command with no option or refspec, so the alias was
# never expanded (PR #61 blocked these; it had no case for them).
A="$TMP/aliases"; mkdir -p "$A"; gq "$A" init -q
gq "$A" config alias.wipe 'reset --hard'
gq "$A" config alias.nuke '!rm -rf build'
gq "$A" config alias.drop 'stash drop'
gq "$A" config alias.st 'status'
check_in BLOCKED "$A" 'git wipe'
check_in BLOCKED "$A" 'git wipe HEAD'
check_in BLOCKED "$A" 'git nuke'
check_in BLOCKED "$A" 'git drop'
check_in BLOCKED "$A" 'git WIPE'
check_in ALLOWED "$A" 'git st'
check_in ALLOWED "$A" 'git status'
# checkout -p / --patch with a path discards the hunks it is told to (the
# docs said blocked; only --patch was)
check BLOCKED 'git checkout -p src/a.ts'
check BLOCKED 'git checkout -p HEAD~1 -- src/a.ts'
check BLOCKED 'git checkout --patch src/a.ts'
# after `--`, git push still reads refspecs: a +refspec there is a force push,
# for the floor too (it is cut at `--` for options only)
floor BLOCKED 'git push origin -- +main'
check BLOCKED 'git push origin -- +main'
floor ALLOWED 'git push origin main -- -f'

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
