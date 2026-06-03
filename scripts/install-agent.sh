#!/bin/bash
set -e

# install-agent.sh — Mount AI agent memory and link external skills for this project.
# Run this once after cloning. Re-running is safe (idempotent).

SHARED_SKILLS_ROOT="$HOME/.agentskel/skills"

# ── 1. Mount .memory/ worktree ────────────────────────────────────────────────

if [ -d ".memory" ]; then
  echo "Pulling latest AI memory..."
  git -C .memory pull --ff-only origin ai-memory 2>/dev/null || {
    echo "Warning — could not pull latest memory. Continuing with local copy."
  }
  echo "Done — .memory/ is up to date."
else
  echo "Fetching latest branches..."
  git fetch origin

  if git branch -r | grep -q origin/ai-memory; then
    echo "Found ai-memory branch. Mounting worktree..."
    git worktree add .memory ai-memory
    echo ""
    echo "Done — AI memory loaded at .memory/"
  else
    echo ""
    echo "Error — This project has no AI memory yet."
    echo "  Ask your tech lead to run the setup-skeleton workflow first."
    exit 1
  fi
fi

# ── 2. Link external skills from shared store ─────────────────────────────────
# Reads .agents/skills/.gitignore to discover which skill dirs are external,
# then ensures they exist in ~/.agentskel/skills/ and are symlinked locally.
# Skips silently if no external skills are recorded for this project.

SKILLS_DIR=".agents/skills"
GITIGNORE="$SKILLS_DIR/.gitignore"

if [ ! -f "$GITIGNORE" ]; then
  # No external skills registered for this project yet.
  exit 0
fi

# Read external skill dir names (skip comment lines and blank lines).
external_skills=()
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  external_skills+=("$line")
done < "$GITIGNORE"

if [ ${#external_skills[@]} -eq 0 ]; then
  exit 0
fi

echo ""
echo "Linking external skills..."

# Determine which pack each external skill belongs to by checking all pack dirs
# under the shared store. If a skill isn't found in any pack, attempt a best-effort
# install of any pack whose skills are entirely missing.
missing_skills=()

for skill in "${external_skills[@]}"; do
  target=$(find "$SHARED_SKILLS_ROOT" -maxdepth 2 -name "$skill" -type d 2>/dev/null | head -1)
  if [ -n "$target" ]; then
    ln -sfn "$target" "$SKILLS_DIR/$skill"
    echo "  Linked: $skill"
  else
    missing_skills+=("$skill")
  fi
done

if [ ${#missing_skills[@]} -gt 0 ]; then
  echo ""
  echo "Warning — the following external skills were not found in $SHARED_SKILLS_ROOT:"
  for skill in "${missing_skills[@]}"; do
    echo "  - $skill"
  done
  echo ""
  echo "To install them, run the update-external-skills workflow in your AI agent."
  echo "Or install manually — see docs/PLATFORM-SKILLS.md for instructions."
fi

echo "Done."
