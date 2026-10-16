# local-agent-tooling

Scripts that keep `docs/` in sync with your code, run right before you open a PR.

## gen-docs scripts

```
./scripts/gen-docs-claude.sh [--check] [base-branch]
./scripts/gen-docs-copilot.sh [--check] [base-branch]
```

What happens:

1. Diffs your branch against a base branch (everything except the docs dir)
2. Hands that diff to an AI coding CLI (Claude Code or GitHub Copilot CLI), scoped to read/edit/write only
3. Asks it to update the docs dir to match the code - nothing else
4. Commits the result, if anything changed

Each script is self-contained - copy either one into any repo and it works with no setup.

**`--check`**: reports whether docs look stale instead of updating them. Read-only -
no edits, no commit - and exits `1` if something looks out of date, so it works as
a CI gate (see below).

## tooling.conf

Optional. Put this at the repo root to override a default; most repos don't need it.

| Key | Default | Meaning |
|---|---|---|
| `base_branch` | the remote's default branch (`origin/HEAD`), else `origin/main` | The branch you'll open the PR against |
| `docs_dir` | `docs` | Where your docs live, relative to the repo root |

An explicit `[base-branch]` argument always wins over `tooling.conf`.

This repo's own `tooling.conf` is a worked example, needed because its docs live under the vendored `tinygrad/` copy instead of at the top level:

```
base_branch=origin/main
docs_dir=tinygrad/docs
```

## Installing GitHub Copilot CLI

`gen-docs-copilot.sh` needs the standalone `copilot` CLI - a separate install from the Copilot extension in VS Code. Requires Node.js 22+.

```
npm install -g @github/copilot              # npm, all platforms
brew install --cask copilot-cli             # Homebrew, macOS/Linux
winget install GitHub.Copilot               # WinGet, Windows
curl -fsSL https://gh.io/copilot-install | bash   # install script, macOS/Linux
```

Then authenticate once with `copilot login`. An "Access denied by policy settings" error usually means an org admin has disabled Copilot CLI specifically, or your plan doesn't include CLI access - check <https://github.com/settings/copilot>; logging in again won't fix either case.

## Automated docs-check on GitHub

`.github/workflows/docs-check.yml` runs on every PR once it's open and not a draft.
It builds two diffs against the PR's base (`code.diff` excluding `docs_dir`,
`docs.diff` for just `docs_dir`), asks Copilot CLI to compare them, and leaves the
result as a PR comment. Never edits or commits anything itself.

One-time setup, since the default `GITHUB_TOKEN` Actions provides isn't tied to a
Copilot seat and can't authenticate Copilot CLI:

1. From a GitHub account with an active Copilot subscription, create a
   fine-grained personal access token with the "Copilot Requests" permission
   (classic `ghp_` tokens aren't accepted).
2. Save it as a repository secret named `COPILOT_GITHUB_TOKEN`
   (Settings -> Secrets and variables -> Actions).

## Local docs-check on commit (`#docscheck`)

`.githooks/post-commit` does the same comparison as the GitHub check, but locally
and on demand: when a commit's message contains `#docscheck`, it diffs that commit's
branch against `tooling.conf`'s `base_branch`, asks Copilot CLI to compare the code
and docs changes, and creates a **separate follow-up commit** containing just
`.docs-check-report.md` - so it rides along in the branch for a reviewer to see.
Commits without the keyword are untouched; nothing here ever blocks a commit.

It has to work this way rather than rejecting bad commits, because of how git hook
timing actually works: a `commit-msg` hook can read the message but by the time it
runs, git has already fixed what tree the commit will contain, so files staged
from inside it land in the *next* commit, not the current one. `post-commit` runs
after the commit exists, so creating a small follow-up commit is the reliable way
to get a generated file into the branch's history (same reason the follow-up
commit's message never itself contains `#docscheck` - that's what stops it
re-triggering itself, not anything forced).

Works with any Git client, SmartGit included - hooks are a Git feature, not a
client one. One real SmartGit-specific gotcha: it doesn't inherit your shell's
PATH, so tools installed via mise/npm/homebrew may be invisible to the hook even
though they work from a terminal; the hook adds common install dirs to `PATH`
itself to work around this, but if `copilot` lives somewhere unusual, it'll log
"not found on PATH" to stderr and skip, rather than fail the commit.

Hooks aren't distributed by cloning a repo (git won't auto-run a cloned repo's
hooks for security reasons), so each person who wants this needs a one-time,
per-clone opt-in:

```
git config core.hooksPath .githooks
```

## tinygrad demo

`tinygrad/` vendors a snapshot of [tinygrad/tinygrad](https://github.com/tinygrad/tinygrad) (commit `b5be082207835b2d82b23e3c9ed2c5415d8b1671`, MIT licensed, see `tinygrad/LICENSE`) as a real-world target to demo the scripts against.
