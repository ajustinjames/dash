Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

$ARGUMENTS is a short description of the issue to create.

Create a GitHub issue using:
gh issue create --title "$ARGUMENTS" --body ""

Extract the issue number from the URL returned.

Run: ./dash.sh log-pl {issue number} "{description}"

Print the issue number and URL.
