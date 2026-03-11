# Dash

Lightweight issue tracking for solo devs and small teams. Dash lives inside your git repo as a `.dash/` directory, uses GitHub Issues as the source of truth, and keeps a local history log automatically via git hooks. AI features are delivered through slash commands in your editor — Dash never calls an API directly.

## Install

Copy `dash.sh` into your repo and initialize:

```sh
curl -fsSL https://raw.githubusercontent.com/ajames/dash/main/dash.sh -o dash.sh && chmod +x dash.sh && ./dash.sh init
```

This creates the `.dash/` directory structure, installs git hooks into `.git/hooks/`, scaffolds a config, and sets up AI slash commands.

### Requirements

- [`gh`](https://cli.github.com/) CLI, authenticated (`gh auth login`)
- Git
- POSIX shell (`/bin/sh`)

## Usage

```sh
./dash.sh start "add rate limiting"    # create GitHub issue + branch + active file
./dash.sh status                       # show in-flight issues with progress
./dash.sh note "blocked on upstream"   # log a note (defaults to current branch's issue)
./dash.sh done                         # close issue, clean up (defaults to current branch)
./dash.sh context plan 42              # print slash command context to stdout
```

### Quick workflow

```
./dash.sh start "add rate limiting"   # creates GH issue, branch 42-add-rate-limiting, active file
... write code, commit normally ...   # hooks track commits and branch switches automatically
./dash.sh status                      # see progress: GH-42: add rate limiting [2/4] (0d ago)
./dash.sh done                        # closes GH-42, archives active file
```

For larger work, use `/plan 42` after `dash start` to have your AI tool generate a spec with tasks.

## Commands

| Command | Description |
|---|---|
| `init` | Create `.dash/` structure, install git hooks, scaffold `config.yaml`, install slash commands |
| `start "description"` | Create GitHub issue, active file, branch, and PL log entry |
| `status` | Show active issues with task progress, staleness flags, and current branch highlight |
| `done [issue]` | Tick all todos, append IC to log, close GitHub issue, delete active file |
| `note [issue] "text"` | Append note to history log and active file's Log section |
| `context <cmd> [args]` | Print assembled slash command context to stdout for pasting into any AI chat |

When `[issue]` is omitted, commands default to the current branch's issue number.

## What `init` installs

### Git hooks

All hooks are installed to `.git/hooks/` (repo-local, not global). They fire automatically during normal git usage:

- **post-commit** — logs each commit (`CM`) to `history.log` with the commit message
- **post-checkout** — logs branch switches (`SW`) so you can see context changes
- **post-merge** — ticks all remaining todos in the active file, logs the merge (`MG`)
- **prepare-commit-msg** — prepends `GH-{issue}` to commit messages automatically

Hooks extract the issue number from the branch name. Supported formats: `42-slug`, `feat/42-slug`, `fix/42-slug`.

### AI slash commands

Installed to `.claude/commands/` for use in Claude Code (or print via `./dash.sh context` for any AI tool):

- `/plan {issue}` — reads the GitHub issue, generates a spec file with tasks in `.dash/active/`
- `/ask "question"` — answers questions using project history, active files, and decision records
- `/release {tag}` — summarizes closed issues into release notes, creates a GitHub release

## Project structure

```
.dash/
  config.yaml          # project name, repo, AI role (~3 lines)
  history.log          # append-only event log, maintained by hooks
  active/              # one markdown file per in-flight issue
    42.md
  decisions/           # human-authored decision records (optional)
    001-auth-strategy.md
```

### history.log

Pipe-delimited, append-only. Maintained automatically by git hooks and CLI commands.

```
PL|26-03-09|42|token bucket rate limit
CM|26-03-10|42|add middleware skeleton
SW|26-03-11|43
MG|26-03-12|42
IC|26-03-12|42
NT|26-03-15|43|blocked on upstream API
RL|26-03-20|v1.2.0|42,43
```

Type codes: `PL` plan, `CM` commit, `SW` switch, `MG` merge, `IC` issue closed, `NT` note, `RL` release.

### Active files

Each in-flight issue gets a markdown file tracking its spec, tasks, and log:

```markdown
# GH-42: Rate Limiting

## Spec
- Token bucket algorithm for /api/v1/* endpoints
- 100 requests/min per API key
- Return 429 with retry-after header

## Tasks
- [x] Add middleware skeleton
- [x] Write tests
- [ ] Implement retry-after header

## Log
- 26-03-09: Created from issue
- 26-03-11: Middleware done, 3 commits
```

### Decision records

Drop markdown files in `.dash/decisions/` to capture architectural decisions. The `/ask` slash command matches keywords from your question against decision filenames and loads relevant ones into context.

## Design

- **GitHub Issues = backlog.** No local duplication of issue metadata.
- **Git hooks do the bookkeeping.** You never manually update tracking files.
- **AI via slash commands, not API calls.** Dash assembles context; your AI tool handles the rest.
- **Single shell script, no dependencies beyond `gh`.** No build step, no runtime, no package manager.
- **Active files are temporary.** They exist while work is in flight and are deleted on `done`.
- **History log is permanent.** Compact format optimized for both humans and token-constrained AI.

## License

MIT
