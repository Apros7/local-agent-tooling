# local-agent-tooling

## gen-docs scripts

`scripts/gen-docs-claude.sh` and `scripts/gen-docs-copilot.sh` are meant to be run at
the end of a PR branch, just before opening it. Each diffs the branch against a base
branch, hands that diff to an AI coding CLI (Claude Code or GitHub Copilot CLI
respectively) scoped to read/edit/write only, and asks it to update `docs/` to match
the code changes - then commits the result if anything changed.

```
./scripts/gen-docs-claude.sh [base-branch]
./scripts/gen-docs-copilot.sh [base-branch]
```

### Using these in another repo

Both scripts are self-contained and have no dependency on anything else in this
repo - copy whichever one(s) you want into `scripts/` (or anywhere) in any other
project and it works as-is, no setup required. They each resolve the base branch
and the docs directory the same way:

1. base branch: `[base-branch]` argument -> `base_branch=...` in `.gen-docs.conf`
   at the repo root -> the remote's default branch, auto-detected from
   `origin/HEAD` -> `origin/main` as a last resort
2. docs dir: `docs_dir=...` in `.gen-docs.conf` -> `docs`, relative to the repo root

`.gen-docs.conf` is entirely optional - most repos need neither setting (a normal
`origin/HEAD` and a top-level `docs/` just work) and can skip it entirely. Copy
`.gen-docs.conf.example` in as `.gen-docs.conf` only if you need to override one -
every line in it starts commented out, so copying it as-is changes nothing.

This repo is the one exception that actually needs an override: its docs live
under the vendored `tinygrad/docs`, not at the top level, so its own `.gen-docs.conf`
sets `docs_dir=tinygrad/docs`. That file is specific to this repo's layout - don't
copy it elsewhere; copy `.gen-docs.conf.example` instead.

### Installing GitHub Copilot CLI

`gen-docs-copilot.sh` needs the standalone `copilot` CLI, which is a separate install
from the Copilot extension in VS Code. Requires Node.js 22+. Pick one:

```
npm install -g @github/copilot              # npm, all platforms
brew install --cask copilot-cli             # Homebrew, macOS/Linux
winget install GitHub.Copilot               # WinGet, Windows
curl -fsSL https://gh.io/copilot-install | bash   # install script, macOS/Linux
```

Then authenticate once with `copilot login` (or the `/login` prompt on first launch).
An "Access denied by policy settings" error on first run usually means either an
organization admin has disabled Copilot CLI specifically (distinct from Copilot in
the IDE), or the account's Copilot plan doesn't include CLI/agentic access - check
<https://github.com/settings/copilot>, logging in again won't fix either case.

`tinygrad/` vendors a snapshot of [tinygrad/tinygrad](https://github.com/tinygrad/tinygrad)
(commit `b5be082207835b2d82b23e3c9ed2c5415d8b1671`, MIT licensed, see `tinygrad/LICENSE`)
as a real-world target to demo the scripts against.
