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
