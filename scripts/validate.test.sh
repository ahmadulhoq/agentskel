#!/usr/bin/env bash
# Tests for validate.py check 12 (`no unreleased skeleton changes`).
#
# The check reads git history, so its answer depends on the state the repo is
# in. v1.68.0 changed it after testing only an open branch, and main went red
# the moment that branch merged; the first v1.68.1 draft then missed an
# unbumped edit on a branch that had merged main. Every state a repo passes
# through is built here from scratch, in throwaway repos, so the next change
# to this check is tested in all of them.
#
# Usage: bash scripts/validate.test.sh    (exit 0 = all pass)
set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1

VALIDATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/validate.py"
TMP=$(mktemp -d)
trap 'rm -r "$TMP"' EXIT
PASS=0
FAIL=0

g() { git -C "$1" "${@:2}" >/dev/null 2>&1; }

# expect <PASS|FAIL> <label> <repo>
expect() {
    local want=$1 label=$2 repo=$3 got
    got=$(python3 - "$VALIDATE" "$repo" <<'PY'
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location("v", sys.argv[1])
v = importlib.util.module_from_spec(spec); spec.loader.exec_module(v)
v.REPO = pathlib.Path(sys.argv[2])
r = v.check_no_unreleased_skeleton_changes()
print("FAIL" if r.failed else "PASS")
PY
)
    if [ "$got" = "$want" ]; then
        PASS=$((PASS + 1)); echo "ok   [$got] $label"
    else
        FAIL=$((FAIL + 1)); echo "FAIL [$got, want $want] $label"
    fi
}

# fresh <name>: a clone of a remote whose main is at release 1.0.0
fresh() {
    local r="$TMP/$1"
    git clone -q "$TMP/origin.git" "$r" 2>/dev/null
    g "$r" config user.email t@example.com
    g "$r" config user.name t
    echo "$r"
}
bump() { echo "$2" > "$1/VERSION"; }
edit_core() { echo "# $2" >> "$1/core/a.sh"; }
commit() { g "$1" add -A; g "$1" commit -m "$2"; }

git init -q --bare -b main "$TMP/origin.git"
SEED=$(fresh seed)
mkdir -p "$SEED/core" "$SEED/docs"
echo 1.0.0 > "$SEED/VERSION"; echo a > "$SEED/core/a.sh"; echo d > "$SEED/docs/d.md"
commit "$SEED" "release 1.0.0"; g "$SEED" push origin main

# A merged release PR on main: branch bumps to 1.1.0, then a review fix lands
# AFTER the bump commit, then it is merged with a merge commit.
g "$SEED" switch -c rel
bump "$SEED" 1.1.0; edit_core "$SEED" feature; commit "$SEED" "release 1.1.0"
edit_core "$SEED" review-fix; commit "$SEED" "review fix after the bump"
g "$SEED" push origin rel
g "$SEED" switch main; g "$SEED" merge --no-ff -m "Merge rel" rel; g "$SEED" push origin main

echo "== on the default branch"
R=$(fresh main1)
expect PASS "post-merge main (review commit after the bump inside the merged PR)" "$R"
edit_core "$R" dirty
expect FAIL "post-merge main + uncommitted core edit" "$R"
bump "$R" 1.1.1
expect PASS "post-merge main + uncommitted core edit + uncommitted bump" "$R"
R=$(fresh main2)
echo "# docs only" >> "$R/docs/d.md"; commit "$R" "docs"
expect PASS "unpushed docs-only commit on main (outside tracked paths)" "$R"
R=$(fresh main3)
edit_core "$R" direct; commit "$R" "direct core commit, no bump"
expect FAIL "unpushed core commit on main without a bump (Direct-Commit Mode)" "$R"
bump "$R" 1.2.0; commit "$R" "bump"
expect PASS "... followed by a bump commit" "$R"

echo "== on a branch"
R=$(fresh br1); g "$R" switch -c feat
bump "$R" 1.2.0; edit_core "$R" x; commit "$R" "release 1.2.0"
edit_core "$R" fix; commit "$R" "review fix after the bump"
expect PASS "release branch with review commits after its own bump" "$R"
R=$(fresh br2); g "$R" switch -c feat
edit_core "$R" x; commit "$R" "core edit, no bump"
expect FAIL "branch with a core edit and no bump" "$R"
R=$(fresh br3); g "$R" switch -c feat
echo "# docs" >> "$R/docs/d.md"; commit "$R" "docs only"
expect PASS "branch touching only docs" "$R"
R=$(fresh br4); g "$R" switch -c feat
edit_core "$R" x; commit "$R" "core edit, no bump"
# main moves on with its own release; the branch merges it in
g "$SEED" switch main; bump "$SEED" 1.3.0; commit "$SEED" "release 1.3.0"; g "$SEED" push origin main
g "$R" fetch origin; g "$R" merge --no-ff -m "merge main into feat" origin/main
expect FAIL "branch merged main AFTER an unbumped core edit (merge is not a bump)" "$R"
R=$(fresh br5); g "$R" switch -c feat
bump "$R" 1.4.0; commit "$R" "uncommitted-then-committed bump"
edit_core "$R" y
expect PASS "release branch + uncommitted core edit" "$R"

echo "== a PR's CI merge commit (main merged with the PR head)"
R=$(fresh ci1); g "$R" switch -c pr
bump "$R" 1.4.0; edit_core "$R" x; commit "$R" "release"; edit_core "$R" fix; commit "$R" "fix"
g "$R" switch --detach origin/main; g "$R" merge --no-ff -m "ci merge ref" pr
expect PASS "PR that bumps, review fix after the bump" "$R"
R=$(fresh ci2); g "$R" switch -c pr
edit_core "$R" x; commit "$R" "core, no bump"
g "$R" switch --detach origin/main; g "$R" merge --no-ff -m "ci merge ref" pr
expect FAIL "PR that touches core without a bump" "$R"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
