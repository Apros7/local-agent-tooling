# local-agent-tooling

## gen-docs scripts

`scripts/gen-docs-claude.sh` and `scripts/gen-docs-copilot.sh` are meant to be run at
the end of a PR branch, just before opening it. Each diffs the branch against a base
branch (default `origin/main`), hands that diff to an AI coding CLI (Claude Code or
GitHub Copilot CLI respectively) scoped to read/edit/write only, and asks it to update
`docs/` to match the code changes - then commits the result if anything changed.

```
./scripts/gen-docs-claude.sh [base-branch]
./scripts/gen-docs-copilot.sh [base-branch]
```

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
