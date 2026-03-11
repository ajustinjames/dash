# Dash — Implementation Spec

## What You're Building

Dash is a lightweight issue tracking layer for solo devs and small teams. It lives inside your git repo as a `.dash/` directory, uses GitHub Issues as the source of truth, and adds just enough local state to plan work and keep a history. Git hooks handle bookkeeping automatically. AI is used sparingly for planning and queries.

## Architecture Principles

- **GitHub is the source of truth**: Issues = backlog. Dash reads/writes via `gh` CLI. No local duplication of issue metadata
- **Repo-light**: `.dash/` holds a config, one log file, per-issue spec files, and human-authored decision records
- **Self-maintaining**: Git hooks keep history.log updated as a side effect of normal git work
- **Shell-native**: v1 is a sourced shell script (`dash.sh`) with a `dash` function. No build step, no dependencies beyond `gh`
- **AI-agnostic**: AI integration is via slash command files that AI tools consume natively (Claude Code `.claude/commands/`, Cursor, etc.). Dash never calls an API directly — `dash init` installs the command files, the dev invokes them from their AI tool

## Directory Structure

```
.dash/
  config.yaml        # project settings (~5 lines)
  history.log        # append-only event log, machine-managed
  active/            # one markdown file per in-flight issue
    42.md
    43.md
  decisions/         # human-authored decision records, loaded on demand
    001-auth-strategy.md

# Installed by `dash init` into AI tool command directories:
.claude/commands/    # Claude Code slash commands
  plan.md
  ask.md
  release.md
```

## File Formats

### config.yaml

```yaml
project: my-api
repo: user/my-api
ai_role: terse solo-dev assistant. no fluff. short answers.
```

### history.log

Pipe-delimited append-only log. One line per event. Date format is YY-MM-DD.

Type codes: `PL`=plan, `CM`=commit, `SW`=switch, `MG`=merge, `IC`=issue_closed, `NT`=note, `RL`=release

```
PL|26-03-09|42|token bucket rate limit
CM|26-03-10|42|add middleware skeleton
CM|26-03-11|42|middleware tests passing
SW|26-03-11|43
CM|26-03-11|43|fix schema migration
SW|26-03-12|42
MG|26-03-12|42
IC|26-03-12|42
NT|26-03-15|43|blocked on upstream API
RL|26-03-20|v1.2.0|42,43
```

### active/{issue_number}.md

Human-readable markdown. Created by `dash plan`, updated by hooks and commands. Deleted by `dash done` after archiving to history.log.

An active file has three lifecycle states, reflected by its content:
- **spec'd** — file exists with spec and tasks, no commits yet
- **in-progress** — commits logged, some tasks checked off
- **done** — all tasks checked, `dash done` archives and removes file

```markdown
# GH-42: Rate Limiting

## Spec
Token bucket algorithm for /api/v1/* endpoints.
- 100 requests/min per API key
- Return 429 with retry-after header
- Storage: Redis with in-memory fallback

## Tasks
- [x] Add middleware skeleton
- [x] Write tests
- [ ] Implement retry-after header
- [ ] Update API docs

## Log
- 26-03-09: Created from issue
- 26-03-11: Middleware done, 3 commits
- 26-03-12: Tests passing, found edge case with concurrent requests
```

### decisions/{number}-{slug}.md

Standard markdown, human-authored. No special format. Only loaded into AI context on demand (e.g., `dash ask "why did we pick redis"` — matched by grepping keywords against decision filenames).

## Git Hooks

Installed by `dash init` into `.git/hooks/`. Lightweight, never call AI. All use macOS-compatible commands.

Branch naming convention: `{issue}-slug` or `{type}/{issue}-slug` (e.g., `42-rate-limit`, `feat/42-rate-limit`). All hooks extract the issue number using `sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p'` which strips any prefix before `/` then captures leading digits.

### post-commit

Extracts issue number from branch name, appends CM line to history.log.

```bash
#!/bin/sh
ISSUE=$(git branch --show-current | sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p')
[ -n "$ISSUE" ] && echo "CM|$(date +%y-%m-%d)|$ISSUE|$(git log -1 --oneline | cut -c9-)" >> .dash/history.log
```

### post-checkout

Logs branch switches. Only fires on branch changes (not file checkouts).

```bash
#!/bin/sh
# $3 is 1 for branch checkout, 0 for file checkout
[ "$3" = "1" ] || exit 0
ISSUE=$(git branch --show-current | sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p')
[ -n "$ISSUE" ] && echo "SW|$(date +%y-%m-%d)|$ISSUE" >> .dash/history.log
```

### post-merge

Ticks all remaining todos in the active file and logs the merge.

```bash
#!/bin/sh
ISSUE=$(git branch --show-current | sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p')
if [ -n "$ISSUE" ] && [ -f ".dash/active/$ISSUE.md" ]; then
  sed -i '' 's/\[ \]/[x]/g' ".dash/active/$ISSUE.md"
  echo "MG|$(date +%y-%m-%d)|$ISSUE" >> .dash/history.log
fi
```

### prepare-commit-msg

Auto-prepends issue number to commit messages. Skips merge commits and amends.

```bash
#!/bin/sh
# $2 is "merge" for merge commits, "commit" for amend
[ "$2" = "merge" ] && exit 0
[ "$2" = "commit" ] && exit 0
ISSUE=$(git branch --show-current | sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p')
[ -n "$ISSUE" ] && sed -i '' "1s/^/GH-$ISSUE /" "$1"
```

## CLI Commands

Implemented as a `dash()` shell function in `dash.sh`, sourced via `.bashrc`/`.zshrc`.

### Local Commands (no API calls)

| Command | Action |
|---|---|
| `dash init` | Create `.dash/` structure, install hooks to `.git/hooks/`, scaffold `config.yaml` |
| `dash start "description"` | Create GH issue via `gh issue create`, create minimal active file (title + empty Spec/Tasks/Log sections), create and checkout branch `{issue}-{slug}`, append PL line to history.log |
| `dash status` | Parse active files, print issue list with task progress (e.g., `GH-42: Rate Limiting [2/4]`). Highlight current branch's issue with `*`. Show time since last activity per issue (from history.log). Flag stale issues with no activity in 2+ days |
| `dash done [issue]` | Tick all todos in active file, append IC to history.log, run `gh issue close`, delete active file. Issue defaults to current branch if omitted |
| `dash note [issue] "text"` | Append NT line to history.log. If the issue has an active file, also append to its `## Log` section. Issue defaults to current branch if omitted |
| `dash context {command} {args}` | Print assembled context for the given slash command to stdout, for pasting into any AI chat |

## Slash Commands (AI Integration)

AI features are delivered as slash command files installed into the dev's AI tool. `dash init` installs them for the detected tool (initially Claude Code, extensible to Cursor/Copilot). No API keys, no curl, no model selection — the AI tool handles all of that.

### How it works

1. `dash init` copies command markdown files into `.claude/commands/` (or equivalent for other tools)
2. Dev invokes from their AI tool: `/plan 42`, `/ask "why redis?"`, `/release v1.2.0`
3. The command file tells the AI what context to read and what to output
4. The AI tool handles the LLM call, streaming, error handling — all of it

### .claude/commands/plan.md

Accepts an issue number as `$ARGUMENTS`. Reads the GH issue, generates a spec file.

```markdown
Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

Fetch GitHub issue $ARGUMENTS using: gh issue view $ARGUMENTS --json title,body,comments

Read titles and spec bullets of other files in .dash/active/ for awareness of parallel work.

Generate a spec file and write it to .dash/active/$ARGUMENTS.md in this format:

# GH-{number}: {title}

## Spec
2-5 bullet points covering: what to build, key technical decisions, constraints.
Derive these from the issue body and comments.

## Tasks
Generate 3-8 tasks. Each should be completable in under 2 hours.
Checklist of concrete implementation steps. Each item should be a single action
a developer can complete and check off.

## Log
- {today's date as YY-MM-DD}: Created from issue

After writing the file, post the Spec section as a comment on the GitHub issue using:
gh issue comment $ARGUMENTS --body "{spec section}"

Append to .dash/history.log:
PL|{YY-MM-DD}|{issue number}|{short description}
```

### .claude/commands/ask.md

Accepts a freeform question as `$ARGUMENTS`.

```markdown
Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

Read .dash/history.log for project activity. If history.log exceeds 50 lines, read only lines since the last RL entry.

Determine the current branch's issue number. Read that issue's active file in full from .dash/active/.
For other active files, read only the `# GH-{n}: {title}` line. If keywords from the question match
another file's title or spec, read that file in full too. If more than 5 active files exist, load only
titles and task counts for non-current issues.

Check if any filenames in .dash/decisions/ match keywords from the question.
If so, read those decision files too.

Answer this question concisely: $ARGUMENTS

Answer in 1-5 sentences unless the question requires a longer explanation.
```

### .claude/commands/release.md

Accepts a tag name as `$ARGUMENTS`.

```markdown
Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

Read .dash/history.log. If history.log exceeds 50 lines, read only lines since the last RL entry.
Find all IC (issue closed) lines since the last RL (release) line.
Use CM lines from history.log to understand what was committed per issue. Do not run `git log`.

Write release notes summarizing what shipped. Group into Features, Fixes, and Other
sections as applicable. Keep release notes under 30 lines.

Then run these commands:
1. git tag $ARGUMENTS
2. gh release create $ARGUMENTS --title "$ARGUMENTS" --notes "{release notes}"
3. Append to .dash/history.log: RL|{YY-MM-DD}|$ARGUMENTS|{comma-separated issue numbers}
```

### Supporting other AI tools

The slash command files are plain markdown with instructions. To support another tool:
- Cursor: `dash init` could copy equivalent files to `.cursor/commands/` or include them in `.cursorrules`
- Copilot: instructions could be added to `.github/copilot-instructions.md`
- Manual: `dash context {command} {args}` prints assembled context to stdout for pasting into any chat

## Issue Lifecycle

```
gh issue create                    # raise an issue on GitHub (normal workflow)
  ↓                                  — OR —
dash start "description"           # fast path: create issue + active file + branch in one step
  ↓
/plan {issue}                      # slash command: AI generates spec + tasks → .dash/active/{issue}.md
  ↓
  ... normal git work ...          # hooks maintain history.log automatically
  dash note "context"              # capture decisions/blockers as you go (defaults to current branch)
  dash status                      # see all in-flight issues
  /ask "question"                  # slash command: query project context
  ↓
dash done                          # close issue, archive active file (defaults to current branch)
  ↓
/release {tag}                     # slash command: AI summarizes, tags, creates GH release
```

For small fixes, `dash start` + work + `dash done` is the full workflow. For larger work, add `/plan` after `dash start`. The tool stays out of the way.

## Implementation Order

Build in this sequence, testing each phase before moving on:

### Phase 1: Foundation (no AI)
1. `dash init` — directory creation, hook installation, config scaffolding
2. `dash start "description"` — create issue, active file, branch, PL log entry
3. All four git hooks — verify history.log populates correctly through normal git usage
4. `dash status` — parse and display active files with task progress, staleness, current branch highlight
5. `dash done [issue]` — tick todos, append IC to log, `gh issue close`, delete active file
6. `dash note [issue] "text"` — append NT line to history.log and active file's Log section
7. `dash context {command} {args}` — print assembled slash command context to stdout
8. Manually create a couple active files to test the local workflow end-to-end

### Phase 2: Slash Commands
9. Write `.claude/commands/plan.md`, `ask.md`, `release.md`
10. `dash init` installs command files into `.claude/commands/`
11. Test each slash command end-to-end in Claude Code

### Phase 3: Polish
12. Edge cases: no issue number in branch name, `.dash/` doesn't exist, `gh` not authenticated

## Key Design Decisions

- GitHub Issues = backlog. No local duplication of issue metadata.
- Active files are per-issue, not per-sprint. They exist while work is in flight and are deleted when done.
- History.log is the permanent record. Compact pipe-delimited format for minimal token use.
- Active files are human-readable markdown, not compressed formats. Readability > token savings for files humans actually read.
- Git hooks do the bookkeeping. The developer never manually updates tracking files.
- AI integration via slash command files, not API calls. Dash assembles context; the dev's AI tool does the rest.
- Shell function over a CLI framework. No build step, no dependencies beyond `gh`.
- Decisions directory is the only human-authored content in `.dash/`. Everything else is machine-managed.
- No sprints, no velocity, no pointing. Issues flow through a simple lifecycle: plan → implement → done → release.
