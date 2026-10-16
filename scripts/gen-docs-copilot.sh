#!/usr/bin/env bash
# Regenerate docs for the current branch with GitHub Copilot CLI, then commit them.
# Usage: ./scripts/gen-docs-copilot.sh [base-branch]
#
# "base-branch" is whatever you'll eventually open the PR against - it has
# nothing to do with which branch you're currently on. Resolution order:
#   1. $1, if given
#   2. base_branch=... in .gen-docs.conf at the repo root
#   3. the remote's default branch (git origin/HEAD)
#   4. origin/main
#
# The docs directory defaults to "docs" at the repo root; override with
# docs_dir=... in .gen-docs.conf (e.g. docs_dir=some/nested/docs) if yours
# lives elsewhere. All git commands below run rooted at the repo root via
# -C, so this works the same regardless of which directory you invoke it
# from.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_FILE="$REPO_ROOT/.gen-docs.conf"
GIT=(git -C "$REPO_ROOT")

# Refuse to run with uncommitted work, so nothing gets lost
if ! "${GIT[@]}" diff --quiet HEAD; then
  echo "Commit or stash your changes first."; exit 1
fi

resolve_base() {
  if [[ -n "${1:-}" ]]; then echo "$1"; return; fi
  if [[ -f "$CONFIG_FILE" ]]; then
    local configured
    configured="$(grep -E '^base_branch=' "$CONFIG_FILE" | tail -1 | cut -d= -f2-)"
    if [[ -n "$configured" ]]; then echo "$configured"; return; fi
  fi
  local remote_head
  remote_head="$("${GIT[@]}" symbolic-ref -q refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/@@')"
  if [[ -n "$remote_head" ]]; then echo "$remote_head"; return; fi
  echo "origin/main"
}
BASE="$(resolve_base "${1:-}")"

resolve_docs_dir() {
  if [[ -f "$CONFIG_FILE" ]]; then
    local configured
    configured="$(grep -E '^docs_dir=' "$CONFIG_FILE" | tail -1 | cut -d= -f2-)"
    if [[ -n "$configured" ]]; then echo "$configured"; return; fi
  fi
  echo "docs"
}
DOCS_DIR="$(resolve_docs_dir)"

"${GIT[@]}" fetch origin

if ! "${GIT[@]}" rev-parse --verify --quiet "$BASE" >/dev/null; then
  echo "Base branch '$BASE' not found (checked: arg, $CONFIG_FILE, origin/HEAD, origin/main fallback)." >&2
  echo "Pass one explicitly: $0 <base-branch>" >&2
  exit 1
fi
if ! "${GIT[@]}" rev-parse --verify --quiet "$BASE:$DOCS_DIR" >/dev/null; then
  echo "Docs dir '$DOCS_DIR' not found on $BASE. Set docs_dir=... in $CONFIG_FILE if it lives elsewhere." >&2
  exit 1
fi
echo "Base branch: $BASE, docs dir: $DOCS_DIR"

"${GIT[@]}" checkout "$BASE" -- "$DOCS_DIR"   # remove this line if you hand-write docs on branches

# Copilot CLI's non-interactive stdin handling isn't guaranteed across
# versions, so the diff is written to a temp file and read explicitly
# instead of piped in (the temp dir is readable by default; no
# --allow-all-paths needed).
DIFF_FILE="$(mktemp)"
trap 'rm -f "$DIFF_FILE"' EXIT
"${GIT[@]}" diff "$BASE"...HEAD -- . ":!$DOCS_DIR" > "$DIFF_FILE"

copilot -p "
Read the file at $DIFF_FILE - it is the full code diff for the current
branch against $BASE.
If CLAUDE.md or AGENTS.md defines a code-to-docs map, use it. Otherwise infer
which files under $DOCS_DIR cover the changed code by reading the diff and the
existing docs structure.
Update only files under $DOCS_DIR so they accurately describe the code AFTER this change.
- Don't document unchanged behaviour and don't invent features.
- Keep the existing structure and style of the docs.
- If no docs need changing, change nothing.
Finish with a short list of the files you changed and why." \
  --allow-tool 'write' \
  --deny-tool 'shell' \
  --deny-tool 'url' \
  --no-color \
  -s

if "${GIT[@]}" diff --quiet HEAD -- "$DOCS_DIR"; then
  echo "No docs changes needed."
else
  "${GIT[@]}" add "$DOCS_DIR"
  "${GIT[@]}" commit -m "docs: update for $("${GIT[@]}" branch --show-current)"
  echo "Docs commit created. Review with: git show HEAD"
fi
