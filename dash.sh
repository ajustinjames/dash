#!/bin/sh
# Dash — lightweight issue tracking for solo devs
# AI-first: slash commands are the primary interface, this script provides utilities.
# Only `init` is user-facing. Other commands are called by AI slash commands.

_dash_issue_from_branch() {
  git branch --show-current 2>/dev/null | sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p'
}

_dash_date() {
  date +%y-%m-%d
}

_dash_check_init() {
  if [ ! -d ".dash" ]; then
    echo "Error: .dash/ not found. Run './dash.sh init' first." >&2
    return 1
  fi
}

_dash_check_gh() {
  if ! gh auth status >/dev/null 2>&1; then
    echo "Error: gh is not authenticated. Run 'gh auth login' first." >&2
    return 1
  fi
}

_dash_init() {
  if [ ! -d ".git" ]; then
    echo "Error: not a git repository" >&2
    return 1
  fi

  # Warn if gh is not authenticated (non-blocking)
  if ! gh auth status >/dev/null 2>&1; then
    echo "Warning: gh is not authenticated. Run 'gh auth login' for full functionality." >&2
  fi

  # Create directory structure
  mkdir -p .dash/active .dash/decisions

  # Create history.log if it doesn't exist
  [ -f .dash/history.log ] || touch .dash/history.log

  # Scaffold config.yaml
  if [ ! -f .dash/config.yaml ]; then
    _project=$(basename "$(pwd)")
    _repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "owner/$_project")
    cat > .dash/config.yaml <<EOF
project: $_project
repo: $_repo
ai_role: terse solo-dev assistant. no fluff. short answers.
EOF
    echo "Created .dash/config.yaml"
  fi

  # Install git hooks
  cat > .git/hooks/prepare-commit-msg <<'HOOK'
#!/bin/sh
[ -f .dash/history.log ] || exit 0
# $2 is "merge" for merge commits, "commit" for amend
[ "$2" = "merge" ] && exit 0
[ "$2" = "commit" ] && exit 0
ISSUE=$(git branch --show-current | sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p')
[ -n "$ISSUE" ] && sed -i '' "1s/^/GH-$ISSUE /" "$1"
exit 0
HOOK
  chmod +x .git/hooks/prepare-commit-msg

  # Install slash command files
  mkdir -p .claude/commands
  _dash_install_commands

  echo "Dash initialized. Hooks installed. Use /issue to create your first issue."
}

_dash_install_commands() {
  cat > .claude/commands/issue.md <<'CMD'
Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

$ARGUMENTS is a short description of the issue to create.

Create a GitHub issue using:
gh issue create --title "$ARGUMENTS" --body ""

Extract the issue number from the URL returned.

Run: ./dash.sh log-pl {issue number} "{description}"

Print the issue number and URL.
CMD

  cat > .claude/commands/refine.md <<'CMD'
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
CMD

  cat > .claude/commands/ask.md <<'CMD'
Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

Read .dash/history.log for project activity. If history.log exceeds 50 lines, read only the last 50 lines.

Determine the current branch's issue number. Read that issue's active file in full from .dash/active/.
For other active files, read only the `# GH-{n}: {title}` line. If keywords from the question match
another file's title or spec, read that file in full too. If more than 5 active files exist, load only
titles and task counts for non-current issues.

Check if any filenames in .dash/decisions/ match keywords from the question.
If so, read those decision files too.

Answer this question concisely: $ARGUMENTS

Answer in 1-5 sentences unless the question requires a longer explanation.
CMD

  cat > .claude/commands/status.md <<'CMD'
Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

Run: ./dash.sh status

Present the output to the user.
CMD

  cat > .claude/commands/done.md <<'CMD'
Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

$ARGUMENTS is an optional issue number. If omitted, detect from current branch.

Read .dash/active/{issue}.md and check for unchecked tasks (lines matching `- [ ]`).

If unchecked tasks exist:
- List them
- Ask the user to confirm closing with incomplete tasks, or to keep working

If all tasks are checked (or user confirms):
- Run: ./dash.sh done $ARGUMENTS
- Report what was closed.
CMD

  cat > .claude/commands/review.md <<'CMD'
Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

$ARGUMENTS is an optional issue number. If omitted, detect from current branch.

Read .dash/active/{issue}.md for the spec and tasks.

Run: git diff main...HEAD --stat
Also read the full diff for changed files relevant to the spec.

For each spec bullet, assess: covered, partially covered, or not started.
For each task, assess whether the diff evidence supports marking it done.

Present a summary:
- Spec coverage (which bullets are addressed)
- Task status (which could be checked off)
- Gaps or concerns
- Suggested next steps
CMD

  cat > .claude/commands/note.md <<'CMD'
Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

$ARGUMENTS is [optional issue number] followed by the note text.

Run: ./dash.sh note $ARGUMENTS

Confirm the note was added.
CMD
}

_dash_status() {
  if [ ! -d ".dash/active" ]; then
    echo "No active issues."
    return 0
  fi

  current_issue=$(_dash_issue_from_branch)
  today=$(date +%s)
  found=0

  for file in $(find .dash/active -name '*.md' 2>/dev/null); do
    [ -f "$file" ] || continue
    found=1

    issue=$(basename "$file" .md)
    title=$(head -1 "$file" | sed 's/^# //')

    # Count tasks
    total=$(grep -c '^\- \[' "$file" 2>/dev/null || echo 0)
    checked=$(grep -c '^\- \[x\]' "$file" 2>/dev/null || echo 0)

    # Find last activity from history.log
    last_date=$(grep "|${issue}|\\|${issue}$" .dash/history.log 2>/dev/null | tail -1 | cut -d'|' -f2)
    stale=""
    if [ -n "$last_date" ]; then
      # Convert YY-MM-DD to seconds for comparison (macOS date)
      last_epoch=$(date -j -f "%y-%m-%d" "$last_date" "+%s" 2>/dev/null)
      if [ -n "$last_epoch" ]; then
        days_ago=$(( (today - last_epoch) / 86400 ))
        age="${days_ago}d ago"
        [ "$days_ago" -ge 2 ] && stale=" [STALE]"
      else
        age="$last_date"
      fi
    else
      age="no activity"
      stale=" [STALE]"
    fi

    # Current branch marker
    marker="  "
    [ "$issue" = "$current_issue" ] && marker="* "

    echo "${marker}${title} [${checked}/${total}] (${age})${stale}"
  done

  [ "$found" -eq 0 ] && echo "No active issues."
  return 0
}

_dash_done() {
  issue="$1"
  [ -z "$issue" ] && issue=$(_dash_issue_from_branch)

  if [ -z "$issue" ]; then
    echo "Error: no issue number provided and can't detect from branch" >&2
    return 1
  fi

  _dash_check_init || return 1
  _dash_check_gh || return 1

  if [ ! -f ".dash/active/${issue}.md" ]; then
    echo "Warning: no active file for GH-${issue}" >&2
  fi

  # Append IC to history.log
  echo "IC|$(_dash_date)|${issue}" >> .dash/history.log

  # Close GitHub issue (warn but don't fail)
  if ! gh issue close "$issue" 2>/dev/null; then
    echo "Warning: could not close GH-${issue} on GitHub" >&2
  fi

  # Delete active file
  rm -f ".dash/active/${issue}.md"

  echo "Closed GH-${issue}"
}

_dash_note() {
  _dash_check_init || return 1

  # Parse args: if first arg is numeric, it's the issue number
  if echo "$1" | grep -qE '^[0-9]+$'; then
    issue="$1"
    shift
    text="$*"
  else
    issue=$(_dash_issue_from_branch)
    text="$*"
  fi

  if [ -z "$issue" ]; then
    echo "Error: no issue number provided and can't detect from branch" >&2
    return 1
  fi

  if [ -z "$text" ]; then
    echo "Usage: dash note [issue] \"text\"" >&2
    return 1
  fi

  # Append NT to history.log
  echo "NT|$(_dash_date)|${issue}|${text}" >> .dash/history.log

  # Append to active file's Log section if it exists
  if [ -f ".dash/active/${issue}.md" ]; then
    echo "- $(_dash_date): ${text}" >> ".dash/active/${issue}.md"
  fi

  echo "Note added to GH-${issue}"
}

_dash_log_pl() {
  _dash_check_init || return 1

  if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: dash.sh log-pl <issue> \"description\"" >&2
    return 1
  fi

  echo "PL|$(_dash_date)|$1|$2" >> .dash/history.log
  echo "PL logged for GH-$1"
}

command="$1"
shift 2>/dev/null
case "$command" in
  init)    _dash_init ;;
  status)  _dash_status ;;
  done)    _dash_done "$1" ;;
  note)    _dash_note "$@" ;;
  log-pl)  _dash_log_pl "$1" "$2" ;;
  *)       echo "Usage: ./dash.sh <init|status|done|note|log-pl>" >&2 ;;
esac
