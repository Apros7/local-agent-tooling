#!/usr/bin/env bash
# Regenerate docs for the current branch with Claude Code, then commit them.
# Usage: ./scripts/gen-docs-claude.sh [base-branch]   (default: origin/main)
set -euo pipefail
BASE="${1:-origin/main}"

# Refuse to run with uncommitted work, so nothing gets lost
if ! git diff --quiet HEAD; then
  echo "Commit or stash your changes first."; exit 1
fi

git fetch origin
git checkout "$BASE" -- docs/   # remove this line if you hand-write docs on branches

# Pipe the branch diff (excluding docs/) straight into Claude
git diff "$BASE"...HEAD -- . ':!docs' | claude -p "
The piped input is the full code diff for the current branch against $BASE.
If CLAUDE.md or AGENTS.md defines a code-to-docs map, use it. Otherwise infer
which files under docs/ cover the changed code by reading the diff and the
existing docs structure.
Update only files under docs/ so they accurately describe the code AFTER this change.
- Don't document unchanged behaviour and don't invent features.
- Keep the existing structure and style of the docs.
- If no docs need changing, change nothing.
Finish with a short list of the files you changed and why." \
  --allowedTools "Read,Edit,Write,Glob,Grep" \
  --permission-mode acceptEdits

if git diff --quiet HEAD -- docs/; then
  echo "No docs changes needed."
else
  git add docs/
  git commit -m "docs: update for $(git branch --show-current)"
  echo "Docs commit created. Review with: git show HEAD"
fi
