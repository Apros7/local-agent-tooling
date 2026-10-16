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

## tinygrad demo

`tinygrad/` vendors a snapshot of [tinygrad/tinygrad](https://github.com/tinygrad/tinygrad) (commit `b5be082207835b2d82b23e3c9ed2c5415d8b1671`, MIT licensed, see `tinygrad/LICENSE`) as a real-world target to demo the scripts against.
