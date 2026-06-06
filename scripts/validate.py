#!/usr/bin/env python3
"""
agentskel static validator.

Runs deterministic checks against the skeleton repo state. Exits 0 when
every check passes, 1 when any check fails. Intended for pre-push and CI.

Checks:
  1. frontmatter shape    — every skill/workflow has valid YAML frontmatter
                            with `description:` (and `name:` for SKILL.md)
  2. description length   — descriptions do not exceed 1024 characters
                            (multi-line YAML folded scalars are supported)
  3. version consistency  — VERSION matches README, MASTER_PLAN, CONFIG
  4. stub parity          — .claude/skills/ stubs match sources byte-for-byte
                            in description + reference path; no orphans
  5. changelog presence   — CHANGELOG.md has a section for the current VERSION

Usage:
  scripts/validate.py            # run all checks; exit 1 on any failure
  scripts/validate.py -v         # verbose (print every pass)
"""

from __future__ import annotations

import glob
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)
NAME_LINE_RE = re.compile(r"^name:\s*(.*)$", re.MULTILINE)

MAX_DESC_CHARS = 1024  # agentskills.io spec hard limit

PASS = "\033[32mPASS\033[0m"
FAIL = "\033[31mFAIL\033[0m"


class Result:
    __slots__ = ("name", "passed", "failed", "errors")

    def __init__(self, name: str):
        self.name = name
        self.passed = 0
        self.failed = 0
        self.errors: list[str] = []

    def ok(self) -> None:
        self.passed += 1

    def bad(self, msg: str) -> None:
        self.failed += 1
        self.errors.append(msg)


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _extract_description(frontmatter_block: str) -> str | None:
    """Extract the logical description value from a YAML frontmatter block.

    Handles single-line values and multi-line folded/block scalars (> and |).
    Returns the value normalized to a single string with newlines collapsed to
    spaces, or None if the field is missing or empty.
    """
    m = re.search(r"^description:[ \t]*(.*)", frontmatter_block, re.MULTILINE)
    if not m:
        return None
    first = m.group(1).rstrip()
    if first in (">", "|", ">-", "|-", ">+", "|+", ""):
        # Multi-line scalar — collect indented continuation lines
        rest = frontmatter_block[m.end():]
        content = []
        for line in rest.split("\n"):
            if line and line[:1] in (" ", "\t"):
                content.append(line.strip())
            else:
                break
        joined = " ".join(content).strip()
        return joined if joined else None
    stripped = first.strip()
    return stripped if stripped else None


def _skill_workflow_files() -> list[Path]:
    patterns = [
        "core/skills/*/SKILL.md",
        "roles/dev/skills/*/SKILL.md",
        "roles/dev/workflows/*.md",
        ".agents/skills/*/SKILL.md",
        ".agents/workflows/*.md",
    ]
    out: list[Path] = []
    for pat in patterns:
        out.extend(Path(p) for p in sorted(glob.glob(str(REPO / pat))))
    return out


def check_frontmatter() -> Result:
    r = Result("frontmatter shape")
    for path in _skill_workflow_files():
        text = _read(path)
        m = FRONTMATTER_RE.match(text)
        if not m:
            r.bad(f"{path.relative_to(REPO)}: missing or malformed YAML frontmatter")
            continue
        block = m.group(1)
        desc = _extract_description(block)
        if not desc:
            r.bad(f"{path.relative_to(REPO)}: frontmatter has no non-empty `description:`")
            continue
        if path.name == "SKILL.md":
            name_m = NAME_LINE_RE.search(block)
            if not name_m or not name_m.group(1).strip():
                r.bad(f"{path.relative_to(REPO)}: SKILL.md frontmatter has no non-empty `name:`")
                continue
        r.ok()
    return r


def check_description_length() -> Result:
    r = Result(f"description length (≤{MAX_DESC_CHARS} chars)")
    for path in _skill_workflow_files():
        text = _read(path)
        m = FRONTMATTER_RE.match(text)
        if not m:
            continue  # frontmatter check will catch this
        desc = _extract_description(m.group(1))
        if desc is None:
            continue  # frontmatter check will catch this
        if len(desc) > MAX_DESC_CHARS:
            r.bad(
                f"{path.relative_to(REPO)}: description is {len(desc)} chars, "
                f"exceeds {MAX_DESC_CHARS}-char limit"
            )
            continue
        r.ok()
    return r


def check_version_consistency() -> Result:
    r = Result("version consistency")
    version_path = REPO / "VERSION"
    if not version_path.exists():
        r.bad("VERSION file missing")
        return r
    canon = _read(version_path).strip()
    if not re.match(r"^\d+\.\d+\.\d+$", canon):
        r.bad(f"VERSION '{canon}' is not semver X.Y.Z")
        return r

    # (rel path, regex, required). .memory/ files live on an orphan branch and
    # are not present in a plain `main` checkout (e.g. in CI). Skip missing
    # optional files — they're validated in local dev where .memory/ is mounted.
    checks = [
        ("README.md", r"\*\*v(\d+\.\d+\.\d+)\*\* — see", True),
        ("MASTER_PLAN.md", r"Corresponds to: agentskel v(\d+\.\d+\.\d+)", True),
        (".memory/CONFIG.md", r"Skeleton Version\s*\|\s*(\d+\.\d+\.\d+)", False),
    ]
    for rel, pat, required in checks:
        path = REPO / rel
        if not path.exists():
            if required:
                r.bad(f"{rel}: required file missing")
            continue  # optional missing file: no pass, no fail
        m = re.search(pat, _read(path))
        if not m:
            r.bad(f"{rel}: version marker not found (pattern {pat!r})")
            continue
        if m.group(1) != canon:
            r.bad(f"{rel}: version {m.group(1)} != VERSION {canon}")
            continue
        r.ok()
    return r


def _is_first_party_skill(name: str) -> bool:
    """A skill is first-party (under agentskel's parity contract) if it has a
    source in core/skills/ or roles/dev/skills/. Skills present only in
    .agents/skills/ (e.g. externally-installed packs like android/skills)
    are third-party and skipped by parity checks."""
    return (REPO / "core/skills" / name / "SKILL.md").exists() or (
        REPO / "roles/dev/skills" / name / "SKILL.md"
    ).exists()


def _is_first_party_workflow(name: str) -> bool:
    """A workflow is first-party if it has a source in roles/dev/workflows/."""
    return (REPO / "roles/dev/workflows" / f"{name}.md").exists()


def _stub_parity_for(label: str, stubs_dir: Path, tool_name: str) -> Result:
    """Verify <tool>/skills/<name>/SKILL.md mirrors current .agents/ sources.

    Same parity contract used for both .claude/skills/ and .gemini/skills/.
    Both tools follow the agentskills.io directory layout."""
    r = Result(f"{label} parity")
    skills_dir = REPO / ".agents/skills"
    workflows_dir = REPO / ".agents/workflows"

    if not stubs_dir.exists():
        r.bad(f"{stubs_dir.relative_to(REPO)}/ directory missing")
        return r

    # Build two sets:
    #   - `expected`: first-party skills/workflows under parity contract
    #   - `agents_present`: every name with a SKILL.md / workflow.md in .agents/
    #     (used to distinguish "third-party present" from "orphan stub")
    # Third-party skills (e.g. android/skills) live in .agents/ but have no
    # source in core/ or roles/. Skip parity for them, but their stubs are
    # legitimate — don't flag as orphan.
    expected: dict[str, tuple[Path, str, str]] = {}
    agents_present: set[str] = set()

    for p in sorted(glob.glob(str(skills_dir / "*/SKILL.md"))):
        path = Path(p)
        name = path.parent.name
        agents_present.add(name)
        if not _is_first_party_skill(name):
            continue
        fm = FRONTMATTER_RE.match(_read(path))
        if not fm:
            continue
        desc = _extract_description(fm.group(1))
        if not desc:
            continue
        expected[name] = (path, desc, "skill")

    for p in sorted(glob.glob(str(workflows_dir / "*.md"))):
        path = Path(p)
        name = path.stem
        agents_present.add(name)
        if not _is_first_party_workflow(name):
            continue
        fm = FRONTMATTER_RE.match(_read(path))
        if not fm:
            continue
        desc = _extract_description(fm.group(1))
        if not desc:
            continue
        expected[name] = (path, desc, "workflow")

    # Flag legacy flat-format stubs. Both tools silently ignore `<name>.md`
    # (flat files) — only the directory layout `<name>/SKILL.md` is discovered.
    rel_stubs = stubs_dir.relative_to(REPO)
    for stub in sorted(glob.glob(str(stubs_dir / "*.md"))):
        r.bad(
            f"{rel_stubs}/{Path(stub).name}: flat-file layout — {tool_name} "
            f"requires directory layout `{rel_stubs}/<name>/SKILL.md`. "
            f"Migrate via sync-skeleton Step 4c."
        )

    # Check each stub (directory layout: <tool>/skills/<name>/SKILL.md)
    stub_names: set[str] = set()
    for stub in sorted(glob.glob(str(stubs_dir / "*/SKILL.md"))):
        stub_path = Path(stub)
        name = stub_path.parent.name
        stub_names.add(name)

        if name not in expected:
            if name in agents_present:
                # Third-party skill — has source in .agents/ but not in
                # core/ or roles/. Skip parity check.
                continue
            r.bad(f"{rel_stubs}/{name}/SKILL.md: orphan (no source in .agents/)")
            continue

        source_path, exp_desc, kind = expected[name]
        stub_text = _read(stub_path)
        stub_fm = FRONTMATTER_RE.match(stub_text)
        stub_desc = _extract_description(stub_fm.group(1)) if stub_fm else None
        if not stub_desc:
            r.bad(f"{rel_stubs}/{name}/SKILL.md: stub has no `description:`")
            continue
        if stub_desc != exp_desc:
            r.bad(f"{rel_stubs}/{name}/SKILL.md: description drift from source")
            continue

        # Check reference path presence
        rel_source = str(source_path.relative_to(REPO))
        if rel_source not in stub_text:
            r.bad(f"{rel_stubs}/{name}/SKILL.md: missing reference to {rel_source}")
            continue
        r.ok()

    # Missing stubs (only flag for first-party — third-party stub generation
    # is the responsibility of the external pack's installer)
    missing = sorted(set(expected) - stub_names)
    for name in missing:
        r.bad(f"{rel_stubs}/{name}/SKILL.md: missing (source {expected[name][0].relative_to(REPO)} has no stub)")

    return r


def check_claude_stub_parity() -> Result:
    return _stub_parity_for("claude stub", REPO / ".claude/skills", "Claude Code")


def check_gemini_stub_parity() -> Result:
    return _stub_parity_for("gemini stub", REPO / ".gemini/skills", "Gemini CLI")


def check_agents_catalog_parity() -> Result:
    """AGENTS.md Skills/Workflows tables reflect current .agents/ source descriptions.

    The catalog feeds every non-Claude tool (Cursor, Copilot, Windsurf, Codex,
    Gemini) and is regenerated from frontmatter during setup/sync. Same drift
    risk as `.claude/skills/` stubs — this check is the non-Claude equivalent.
    """
    r = Result("AGENTS.md catalog parity")
    agents_md = REPO / "AGENTS.md"
    if not agents_md.exists():
        r.bad("AGENTS.md missing")
        return r

    text = _read(agents_md)

    # Extract Skills section
    sk_m = re.search(r"^## Skills\n(.*?)(?=^## )", text, re.MULTILINE | re.DOTALL)
    wf_m = re.search(r"^## Workflows\n(.*?)(?=^## )", text, re.MULTILINE | re.DOTALL)
    if not sk_m:
        r.bad("AGENTS.md: `## Skills` section not found")
        return r
    if not wf_m:
        r.bad("AGENTS.md: `## Workflows` section not found")
        return r

    row_re = re.compile(r"^\|\s*([^|\s][^|]*?)\s*\|\s*(.*?)\s*\|\s*`([^`]+)`\s*\|\s*$", re.MULTILINE)

    def parse_rows(section_text: str) -> dict[str, tuple[str, str]]:
        # skip header + separator rows
        rows: dict[str, tuple[str, str]] = {}
        for m in row_re.finditer(section_text):
            name = m.group(1).strip()
            if name in ("Skill", "Workflow") or set(name) <= {"-"}:
                continue
            rows[name] = (m.group(2).strip(), m.group(3).strip())
        return rows

    cat_skills = parse_rows(sk_m.group(1))
    cat_workflows = parse_rows(wf_m.group(1))

    def expected_entries(pattern: str, kind: str) -> tuple[dict[str, tuple[str, str]], set[str]]:
        """Returns (first_party_expected, agents_present).

        Third-party skills/workflows (no source in core/ or roles/) are
        excluded from `first_party_expected` but recorded in `agents_present`
        so we can tell "third-party row" from "true orphan row" later."""
        out: dict[str, tuple[str, str]] = {}
        present: set[str] = set()
        for p in sorted(glob.glob(str(REPO / pattern))):
            path = Path(p)
            name = path.parent.name if kind == "skill" else path.stem
            present.add(name)
            is_first_party = (
                _is_first_party_skill(name) if kind == "skill" else _is_first_party_workflow(name)
            )
            if not is_first_party:
                continue
            text = _read(path)
            fm = FRONTMATTER_RE.match(text)
            desc = _extract_description(fm.group(1)) if fm else None
            if not desc:
                continue
            out[name] = (desc, str(path.relative_to(REPO)))
        return out, present

    exp_skills, agents_skills = expected_entries(".agents/skills/*/SKILL.md", "skill")
    exp_workflows, agents_workflows = expected_entries(".agents/workflows/*.md", "workflow")

    def compare(
        label: str,
        expected: dict[str, tuple[str, str]],
        actual: dict[str, tuple[str, str]],
        present: set[str],
    ) -> None:
        for name, (desc, path) in expected.items():
            if name not in actual:
                r.bad(f"AGENTS.md {label}: missing row for `{name}` (source exists at {path})")
                continue
            a_desc, a_path = actual[name]
            if a_desc != desc:
                r.bad(f"AGENTS.md {label} `{name}`: description drift from source")
                continue
            if a_path != path:
                r.bad(f"AGENTS.md {label} `{name}`: path `{a_path}` != source path `{path}`")
                continue
            r.ok()
        # An actual row is orphan only if it's not first-party AND not
        # third-party-present in .agents/. Third-party rows are legitimate.
        for name in sorted(set(actual) - set(expected)):
            if name in present:
                continue  # third-party row — out of parity contract
            r.bad(f"AGENTS.md {label}: orphan row for `{name}` (no source in .agents/)")

    compare("Skills", exp_skills, cat_skills, agents_skills)
    compare("Workflows", exp_workflows, cat_workflows, agents_workflows)
    return r


def check_changelog_has_version() -> Result:
    r = Result("changelog has current version entry")
    version_path = REPO / "VERSION"
    changelog_path = REPO / "CHANGELOG.md"
    if not (version_path.exists() and changelog_path.exists()):
        r.bad("VERSION or CHANGELOG.md missing")
        return r
    canon = _read(version_path).strip()
    text = _read(changelog_path)
    if re.search(rf"^## v{re.escape(canon)}\b", text, re.MULTILINE):
        r.ok()
    else:
        r.bad(f"CHANGELOG.md: no section '## v{canon}' for current VERSION")
    return r


CHECKS = [
    check_frontmatter,
    check_description_length,
    check_version_consistency,
    check_claude_stub_parity,
    check_gemini_stub_parity,
    check_agents_catalog_parity,
    check_changelog_has_version,
]


def main(argv: list[str]) -> int:
    verbose = "-v" in argv or "--verbose" in argv

    print(f"agentskel validator — repo: {REPO}\n")
    results = [fn() for fn in CHECKS]
    total_pass = sum(r.passed for r in results)
    total_fail = sum(r.failed for r in results)

    for r in results:
        status = PASS if r.failed == 0 else FAIL
        print(f"  [{status}] {r.name}: {r.passed} ok, {r.failed} fail")
        for err in r.errors:
            print(f"           - {err}")
        if verbose and r.failed == 0 and r.passed:
            print(f"           ({r.passed} items checked)")

    print(f"\nTotal: {total_pass} ok, {total_fail} fail")
    return 0 if total_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
