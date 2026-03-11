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
