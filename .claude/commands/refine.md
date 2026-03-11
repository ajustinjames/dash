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
