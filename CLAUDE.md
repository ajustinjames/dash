# Dash

Lightweight issue tracking for solo devs. Lives in `.dash/`, uses GitHub Issues as source of truth, git hooks for bookkeeping, AI slash commands for planning/queries.

## Structure

```
.dash/
  config.yaml          # project, repo, ai_role
  history.log          # append-only pipe-delimited event log
  active/{issue}.md    # per-issue spec/tasks/log (deleted on done)
  decisions/*.md       # human-authored decision records
.claude/commands/
  refine.md            # /refine {issue} — generate spec + tasks from GH issue
  ask.md               # /ask "question" — query project context
  release.md           # /release {tag} — summarize + tag + GH release
```

## CLI (`dash.sh`)

| Command | What it does |
|---|---|
| `init` | Create `.dash/`, install git hooks, scaffold config, install slash commands |
| `start "desc"` | Create GH issue + active file + branch + PL log entry |
| `status` | Show active issues with task progress, staleness, current branch `*` |
| `done [issue]` | Tick todos, IC log, `gh issue close`, delete active file |
| `note [issue] "text"` | NT log + append to active file's Log section |
| `context cmd [args]` | Print slash command context to stdout |

Issue defaults to current branch when omitted.

## Git Hooks (installed by `init`)

- **post-commit** — appends CM line to history.log, amends commit to include it
- **post-checkout** — appends SW line on branch switches
- **post-merge** — ticks all todos in active file, appends MG line
- **prepare-commit-msg** — prepends `GH-{issue}` to commit messages

Branch naming: `{issue}-slug` or `{type}/{issue}-slug`. Issue number extracted via `sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p'`.

## history.log format

```
PL|YY-MM-DD|{issue}|{description}
CM|YY-MM-DD|{issue}|{commit message}
SW|YY-MM-DD|{issue}
MG|YY-MM-DD|{issue}
IC|YY-MM-DD|{issue}
NT|YY-MM-DD|{issue}|{text}
RL|YY-MM-DD|{tag}|{issue,issue,...}
```

## active/{issue}.md format

```markdown
# GH-{n}: {title}

## Spec
- bullet points

## Tasks
- [ ] task

## Log
- YY-MM-DD: entry
```

## Lifecycle

```
dash start "desc" → /refine {issue} → git work (hooks auto-track) → dash done → /release {tag}
```

For small fixes, skip `/refine`. Use `dash note` and `/ask` during implementation.
