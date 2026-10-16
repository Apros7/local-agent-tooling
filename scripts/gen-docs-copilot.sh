#!/usr/bin/env bash
# Regenerate docs for the current branch with GitHub Copilot CLI, then commit them.
# Usage: ./scripts/gen-docs-copilot.sh [--check] [base-branch]
#
#   --check   Report whether docs look stale instead of updating them.
#             Read-only: no edits, no commit. Exits 1 if docs look stale,
#             so this can be used as a CI gate.
#
# "base-branch" is whatever you'll eventually open the PR against - it has
# nothing to do with which branch you're currently on. Resolution order:
#   1. [base-branch] argument, if given
#   2. base_branch=... in tooling.conf at the repo root
#   3. the remote's default branch (git origin/HEAD)
#   4. origin/main
#
# The docs directory defaults to "docs" at the repo root; override with
# docs_dir=... in tooling.conf (e.g. docs_dir=some/nested/docs) if yours
# lives elsewhere. All git commands below run rooted at the repo root via
# -C, so this works the same regardless of which directory you invoke it
# from.
set -euo pipefail

CHECK=0
ARG=""
for a in "$@"; do
  case "$a" in
    --check) CHECK=1 ;;
    *) ARG="$a" ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel)"
CONFIG_FILE="$REPO_ROOT/tooling.conf"
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
BASE="$(resolve_base "$ARG")"

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

# Copilot CLI's non-interactive stdin handling isn't guaranteed across
# versions, so the diff is written to a temp file and read explicitly
# instead of piped in (the temp dir is readable by default; no
# --allow-all-paths needed).
DIFF_FILE="$(mktemp)"
trap 'rm -f "$DIFF_FILE"' EXIT
"${GIT[@]}" diff "$BASE"...HEAD -- . ":!$DOCS_DIR" > "$DIFF_FILE"

if [[ "$CHECK" -eq 1 ]]; then
  # Read-only: ask Copilot to report stale docs without touching anything.
  # --deny-tool write is belt-and-suspenders - reads aren't gated by
  # Copilot CLI anyway, but this guarantees no edit can slip through.
  REPORT="$(copilot -p "
Read the file at $DIFF_FILE - it is the full code diff for the current
branch against $BASE.
If CLAUDE.md or AGENTS.md defines a code-to-docs map, use it. Otherwise infer
which files under $DOCS_DIR cover the changed code by reading the diff and the
existing docs structure.
This is a read-only check - do not edit anything.
List any files under $DOCS_DIR that are now stale, missing, or incomplete
because of this diff, with a one-line reason each. If nothing needs changing,
say so.
End your response with exactly one line, and nothing after it:
RESULT: STALE
or
RESULT: OK" \
    --deny-tool 'write' \
    --deny-tool 'shell' \
    --deny-tool 'url' \
    --no-color \
    -s)"
  echo "$REPORT"
  if echo "$REPORT" | grep -q '^RESULT: STALE$'; then
    echo "Docs may be out of date - see report above." >&2
    exit 1
  fi
  echo "Docs look up to date."
  exit 0
fi

"${GIT[@]}" checkout "$BASE" -- "$DOCS_DIR"   # remove this line if you hand-write docs on branches

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
