#!/bin/sh
# Dash — lightweight issue tracking for solo devs
# Source this file in your .bashrc/.zshrc: source /path/to/dash.sh

_dash_issue_from_branch() {
  git branch --show-current 2>/dev/null | sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p'
}

_dash_date() {
  date +%y-%m-%d
}

_dash_slug() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g' | cut -c1-30
}

_dash_usage() {
  cat <<'EOF'
Usage: dash <command> [args]

Commands:
  init                Create .dash/ structure, install hooks, scaffold config
  start "description" Create issue, active file, branch, and PL log entry
  status              Show active issues with task progress
  done [issue]        Close issue, archive active file (defaults to current branch)
  note [issue] "text" Add a note to history log and active file
  context cmd [args]  Print assembled slash command context to stdout
EOF
}

_dash_init() {
  if [ ! -d ".git" ]; then
    echo "Error: not a git repository" >&2
    return 1
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
  cat > .git/hooks/post-commit <<'HOOK'
#!/bin/sh
# Guard against infinite loop from --amend below
[ -f .dash/.amending ] && exit 0
ISSUE=$(git branch --show-current | sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p')
if [ -n "$ISSUE" ]; then
  echo "CM|$(date +%y-%m-%d)|$ISSUE|$(git log -1 --oneline | cut -c9-)" >> .dash/history.log
  touch .dash/.amending
  git add .dash/history.log
  git commit --amend --no-edit
  rm -f .dash/.amending
fi
HOOK
  chmod +x .git/hooks/post-commit

  cat > .git/hooks/post-checkout <<'HOOK'
#!/bin/sh
# $3 is 1 for branch checkout, 0 for file checkout
[ "$3" = "1" ] || exit 0
ISSUE=$(git branch --show-current | sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p')
[ -n "$ISSUE" ] && echo "SW|$(date +%y-%m-%d)|$ISSUE" >> .dash/history.log
exit 0
HOOK
  chmod +x .git/hooks/post-checkout

  cat > .git/hooks/post-merge <<'HOOK'
#!/bin/sh
ISSUE=$(git branch --show-current | sed -n 's|.*/||;s/^\([0-9]*\).*/\1/p')
if [ -n "$ISSUE" ] && [ -f ".dash/active/$ISSUE.md" ]; then
  sed -i '' 's/\[ \]/[x]/g' ".dash/active/$ISSUE.md"
  echo "MG|$(date +%y-%m-%d)|$ISSUE" >> .dash/history.log
fi
HOOK
  chmod +x .git/hooks/post-merge

  cat > .git/hooks/prepare-commit-msg <<'HOOK'
#!/bin/sh
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

  echo "Dash initialized. Hooks installed. Run 'dash start \"description\"' to begin."
}

_dash_install_commands() {
  cat > .claude/commands/plan.md <<'CMD'
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

Read .dash/history.log for project activity. If history.log exceeds 50 lines, read only lines since the last RL entry.

Determine the current branch's issue number. Read that issue's active file in full from .dash/active/.
For other active files, read only the `# GH-{n}: {title}` line. If keywords from the question match
another file's title or spec, read that file in full too. If more than 5 active files exist, load only
titles and task counts for non-current issues.

Check if any filenames in .dash/decisions/ match keywords from the question.
If so, read those decision files too.

Answer this question concisely: $ARGUMENTS

Answer in 1-5 sentences unless the question requires a longer explanation.
CMD

  cat > .claude/commands/release.md <<'CMD'
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
CMD
}

_dash_start() {
  if [ -z "$1" ]; then
    echo "Usage: dash start \"description\"" >&2
    return 1
  fi

  if [ ! -d ".dash" ]; then
    echo "Error: .dash/ not found. Run 'dash init' first." >&2
    return 1
  fi

  description="$1"
  slug=$(_dash_slug "$description")

  # Create GitHub issue
  output=$(gh issue create --title "$description" --body "" 2>&1)
  if [ $? -ne 0 ]; then
    echo "Error creating issue: $output" >&2
    return 1
  fi

  # Extract issue number from URL (last path segment)
  issue=$(echo "$output" | grep -o '[0-9]*$')
  if [ -z "$issue" ]; then
    echo "Error: could not extract issue number from: $output" >&2
    return 1
  fi

  # Create active file
  cat > ".dash/active/${issue}.md" <<EOF
# GH-${issue}: ${description}

## Spec

## Tasks

## Log
- $(_dash_date): Created from issue
EOF

  # Append PL to history.log
  echo "PL|$(_dash_date)|${issue}|${description}" >> .dash/history.log

  # Create and checkout branch
  git checkout -b "${issue}-${slug}"

  echo "Started GH-${issue}: ${description}"
  echo "Branch: ${issue}-${slug}"
  echo "Active file: .dash/active/${issue}.md"
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

  if [ ! -d ".dash" ]; then
    echo "Error: .dash/ not found. Run 'dash init' first." >&2
    return 1
  fi

  # Tick all todos in active file
  if [ -f ".dash/active/${issue}.md" ]; then
    sed -i '' 's/\[ \]/[x]/g' ".dash/active/${issue}.md"
  fi

  # Append IC to history.log
  echo "IC|$(_dash_date)|${issue}" >> .dash/history.log

  # Close GitHub issue
  gh issue close "$issue" 2>/dev/null

  # Delete active file
  rm -f ".dash/active/${issue}.md"

  echo "Closed GH-${issue}"
}

_dash_note() {
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

_dash_context() {
  command="$1"
  shift
  args="$*"

  if [ -z "$command" ]; then
    echo "Usage: dash context <command> [args]" >&2
    return 1
  fi

  cmd_file=".claude/commands/${command}.md"
  if [ ! -f "$cmd_file" ]; then
    echo "Error: command file not found: $cmd_file" >&2
    return 1
  fi

  # Read and substitute $ARGUMENTS
  sed "s/\$ARGUMENTS/$args/g" "$cmd_file"
}

dash() {
  case "$1" in
    init)    _dash_init ;;
    start)   _dash_start "$2" ;;
    status)  _dash_status ;;
    done)    _dash_done "$2" ;;
    note)    shift; _dash_note "$@" ;;
    context) shift; _dash_context "$@" ;;
    *)       _dash_usage ;;
  esac
}
