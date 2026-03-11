# Dash

AI-first issue tracking for solo devs. Slash commands are the primary interface; `dash.sh` provides utility functions the AI calls.

## Slash Commands (primary interface)

| Command | What it does |
|---|---|
| `/issue "desc"` | Create GH issue with structured body + PL log entry |
| `/refine {issue}` | Generate spec + design (if UI) + tasks from GH issue |
| `/status` | Show active issues with progress |
| `/review [issue]` | Check spec/task coverage against branch diff |
| `/revise [issue] "what changed"` | Update spec/tasks mid-work, post comment to GH issue |
| `/done [issue]` | Check for incomplete tasks, then close issue |
| `/note [issue] "text"` | Add note to history + active file |
| `/ask "question"` | Query project context |

## dash.sh (utility layer)

| Command | What it does |
|---|---|
| `init` | **User-facing.** Create `.dash/`, install hooks, scaffold config, install slash commands |
| `status` | Show active issues with task progress, staleness, current branch `*` |
| `done [issue]` | IC log, `gh issue close`, archive active file |
| `note [issue] "text"` | NT log + append to active file's Log section |
| `log` | Print reverse-chronological history timeline |
| `log-pl {issue} "desc"` | Append PL entry to history.log |
| `context {cmd} [args]` | Assemble context for a slash command |

Issue defaults to current branch when omitted.

## Structure

```
.dash/
  config.yaml          # project, repo, ai_role
  history.log          # append-only pipe-delimited event log
  active/{issue}.md    # per-issue spec/tasks/log (archived on done)
  archive/{issue}.md   # completed issue files
  decisions/*.md       # human-authored decision records
.claude/commands/
  issue.md refine.md ask.md status.md review.md revise.md done.md note.md
```

## Git Hooks (installed by `init`)

- **prepare-commit-msg** — prepends `GH-{issue}` to commit messages

Branch naming: `{issue}-slug` or `{type}/{issue}-slug`. Issue number extracted via `sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p'`.

## history.log format

```
PL|YY-MM-DD|{issue}|{description}
IC|YY-MM-DD|{issue}
NT|YY-MM-DD|{issue}|{text}
```

## active/{issue}.md format

```markdown
# GH-{n}: {title}

## Spec
- bullet points

## Design (UI issues only)
- component breakdown, states, responsive, interaction, a11y

## Tasks
- [ ] task

## Log
- YY-MM-DD: entry
```

## Lifecycle

```
/issue "desc" → /refine {issue} → git work (hooks auto-track) → [/revise] → /review → /done
```

For small fixes, skip `/refine`. Use `/note` and `/ask` during implementation. Use `/revise` when implementation diverges from the original plan.
