#!/usr/bin/env bash
set -euo pipefail

REPO_NAME="${1:-test12-permanent}"
VISIBILITY="${2:-public}" # public|private

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI not found. Install with: brew install gh"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "GitHub CLI is not logged in."
  echo "Run this and follow the steps:"
  echo "  gh auth login --web --git-protocol https --skip-ssh-key"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not a git repo. Run: git init"
  exit 1
fi

if [[ "$VISIBILITY" != "public" && "$VISIBILITY" != "private" ]]; then
  echo "Visibility must be: public or private"
  exit 1
fi

echo "Creating repo + pushing: $REPO_NAME ($VISIBILITY)"
gh repo create "$REPO_NAME" --"$VISIBILITY" --source=. --remote=origin --push

echo "Done."
echo "Repo:"
gh repo view --web >/dev/null 2>&1 || true

