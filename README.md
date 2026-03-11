# Dash

AI-first issue tracking for solo devs and small teams. Lives inside your git repo as a `.dash/` directory, uses GitHub Issues as the source of truth, and keeps a local history log via git hooks. Everything is driven through AI slash commands — the only direct command is `./dash.sh init`.

## Install

Copy `dash.sh` into your repo and initialize:

```sh
curl -fsSL https://raw.githubusercontent.com/ajustinjames/dash/main/dash.sh -o dash.sh && chmod +x dash.sh && ./dash.sh init
```

This creates the `.dash/` directory structure, installs git hooks, scaffolds a config, and sets up AI slash commands.

### Requirements

- [`gh`](https://cli.github.com/) CLI, authenticated (`gh auth login`)
- Git
- POSIX shell (`/bin/sh`)
- [Claude Code](https://claude.ai/code) (or any AI tool that supports slash commands)

## Usage

After `init`, everything happens through slash commands in your AI tool:

```
/issue "add rate limiting"    → creates GH issue #42, logs PL entry
/refine 42                    → generates spec + tasks in .dash/active/42.md
/status                       → shows active issues with progress
/note "blocked on upstream"   → logs note to history + active file
/review                       → checks spec coverage against branch diff
/done                         → checks tasks, then closes issue
/ask "what's the auth strategy?" → answers from project context
```

### Quick workflow

```
/issue "add rate limiting"    # creates GH-42
/refine 42                    # generates spec with tasks
... write code, commit ...    # hooks auto-prepend GH-42 to commits
/status                       # GH-42: add rate limiting [2/4] (0d ago)
/review                       # checks spec coverage, suggests next steps
/done                         # checks tasks, closes GH-42, removes active file
```

For small fixes, skip `/refine`.

## Slash Commands

| Command | Description |
|---|---|
| `/issue "description"` | Create GitHub issue and log PL entry |
| `/refine {issue}` | Fetch GH issue, generate spec + design (if UI) + tasks in `.dash/active/` |
| `/status` | Show active issues with task progress and staleness |
| `/review [issue]` | Check spec/task coverage against branch diff |
| `/done [issue]` | Check for incomplete tasks, then close GH issue and delete active file |
| `/note [issue] "text"` | Log note to history and active file |
| `/ask "question"` | Answer questions using project history, active files, decisions |

When `[issue]` is omitted, commands detect the issue from the current branch.

## What `init` installs

### Git hooks

- **prepare-commit-msg** — prepends `GH-{issue}` to commit messages automatically

Hooks extract the issue number from the branch name. Supported formats: `42-slug`, `feat/42-slug`, `fix/42-slug`.

### AI slash commands

Seven commands installed to `.claude/commands/`: `issue`, `refine`, `ask`, `status`, `review`, `done`, `note`.

### Utility script

`dash.sh` provides utility functions that slash commands call: `status`, `done`, `note`, `log-pl`. These are not intended to be called directly by users.

## Project structure

```
.dash/
  config.yaml          # project name, repo, AI role (~3 lines)
  history.log          # append-only event log
  active/              # one markdown file per in-flight issue
    42.md
  decisions/           # human-authored decision records (optional)
    001-auth-strategy.md
```

### history.log

Pipe-delimited, append-only:

```
PL|26-03-09|42|token bucket rate limit
IC|26-03-12|42
NT|26-03-15|43|blocked on upstream API
```

Type codes: `PL` plan, `IC` issue closed, `NT` note.

### Active files

Each in-flight issue gets a markdown file tracking its spec, tasks, and log:

```markdown
# GH-42: Rate Limiting

## Spec
- Token bucket algorithm for /api/v1/* endpoints
- 100 requests/min per API key
- Return 429 with retry-after header

## Design
- Components: RateLimitBanner > [UsageBar, ResetTimer]
- States: normal, warning (>80%), throttled (429)
- Responsive: banner collapses to icon on mobile

## Tasks
- [x] Add middleware skeleton
- [x] Write tests
- [ ] Implement retry-after header

## Log
- 26-03-09: Created from issue
- 26-03-11: Middleware done, 3 commits
```

### Decision records

Drop markdown files in `.dash/decisions/` to capture architectural decisions. The `/ask` command matches keywords from your question against decision filenames and loads relevant ones into context.

## Design

- **GitHub Issues = backlog.** No local duplication of issue metadata.
- **AI slash commands are the interface.** `dash.sh` is just the utility layer.
- **Git hooks do the bookkeeping.** Tracking is automatic.
- **Single shell script, no dependencies beyond `gh`.** No build step, no runtime.
- **Active files are temporary.** Deleted on `/done`.
- **History log is permanent.** Compact format for humans and AI.

## License

MIT
