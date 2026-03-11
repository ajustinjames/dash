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
