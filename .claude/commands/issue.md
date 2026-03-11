Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

$ARGUMENTS is a description of the issue to create.

Construct a structured issue body:
- If $ARGUMENTS is a short one-liner (plain description, no structured content), place it in Background and leave Acceptance Criteria and Notes empty.
- Otherwise, derive Background, Acceptance Criteria (bullet list), and Notes from $ARGUMENTS.

Body template:
## Background
{description}

## Acceptance Criteria
{bullet list, or empty}

## Notes
{notes, or empty}

Create a GitHub issue using:
gh issue create --title "{title from $ARGUMENTS}" --body "{structured body}"

Extract the issue number from the URL returned.

Run: ./dash.sh log-pl {issue number} "{description}"

Print the issue number and URL.
