Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

$ARGUMENTS is an optional issue number. If omitted, detect from current branch.

Read .dash/active/{issue}.md and check for unchecked tasks (lines matching `- [ ]`).

If unchecked tasks exist:
- List them
- Ask the user to confirm closing with incomplete tasks, or to keep working

If all tasks are checked (or user confirms):
- Run: ./dash.sh done $ARGUMENTS
- Report what was closed.
