#!/usr/bin/env bash
set -euo pipefail

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

if [ -n "$(git status --porcelain -- docs/README.md)" ]; then
  git add docs/README.md
  git commit -m "terraform-docs: automated docs update"
  git push
else
  echo "No doc changes to commit."
fi
