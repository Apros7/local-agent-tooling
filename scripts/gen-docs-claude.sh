#!/usr/bin/env bash
# Regenerate docs for the current branch with Claude Code, then commit them.
# Usage: ./scripts/gen-docs-claude.sh [base-branch]
#
# "base-branch" is whatever you'll eventually open the PR against - it has
# nothing to do with which branch you're currently on. Resolution order:
#   1. $1, if given
#   2. base_branch=... in .gen-docs.conf at the repo root
#   3. the remote's default branch (git origin/HEAD)
#   4. origin/main
set -euo pipefail

# Refuse to run with uncommitted work, so nothing gets lost
if ! git diff --quiet HEAD; then
  echo "Commit or stash your changes first."; exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_FILE="$REPO_ROOT/.gen-docs.conf"

resolve_base() {
  if [[ -n "${1:-}" ]]; then echo "$1"; return; fi
  if [[ -f "$CONFIG_FILE" ]]; then
    local configured
    configured="$(grep -E '^base_branch=' "$CONFIG_FILE" | tail -1 | cut -d= -f2-)"
    if [[ -n "$configured" ]]; then echo "$configured"; return; fi
  fi
  local remote_head
  remote_head="$(git symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/@@')"
  if [[ -n "$remote_head" ]]; then echo "$remote_head"; return; fi
  echo "origin/main"
}
BASE="$(resolve_base "${1:-}")"

git fetch origin

if ! git rev-parse --verify --quiet "$BASE" >/dev/null; then
  echo "Base branch '$BASE' not found (checked: arg, $CONFIG_FILE, origin/HEAD, origin/main fallback)." >&2
  echo "Pass one explicitly: $0 <base-branch>" >&2
  exit 1
fi
echo "Base branch: $BASE"

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
