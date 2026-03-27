#!/bin/bash
set -e

# install-agent.sh — Mount AI agent memory for this project.
# Run this once after cloning. Re-running is safe (idempotent).

if [ -d ".memory" ]; then
  echo "Pulling latest AI memory..."
  git -C .memory pull --ff-only origin ai-memory || {
    echo "Warning — could not pull latest memory. Continuing with local copy."
  }
  echo "Done — .memory/ is up to date."
  exit 0
fi

echo "Fetching latest branches..."
git fetch origin

if git branch -r | grep -q origin/ai-memory; then
  echo "Found ai-memory branch. Mounting worktree..."
  git worktree add .memory ai-memory
  echo ""
  echo "Done — AI memory loaded at .memory/"
  echo "  Start Claude Code and begin working."
else
  echo ""
  echo "Error — This project has no AI memory yet."
  echo "  Ask your tech lead to run the setup-skeleton workflow first."
  exit 1
fi
