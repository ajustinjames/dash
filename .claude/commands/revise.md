Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

$ARGUMENTS is an optional issue number followed by a description of what changed. If no issue number is provided, detect from current branch.

Read .dash/active/{issue}.md.

Update the Spec and Tasks sections in place to reflect the changes described. Preserve the Log section intact.

Append to the Log section:
- {today's date as YY-MM-DD}: Revised: {brief description of what changed}

Write the updated file back to .dash/active/{issue}.md.

Run: ./dash.sh note {issue} "Revised: {brief description}"

Post the updated Spec section as a comment on the GitHub issue:
gh issue comment {issue} --body "{updated spec section}"

Report what was changed.
