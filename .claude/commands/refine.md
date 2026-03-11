Read the project config from .dash/config.yaml. Adopt the role described in `ai_role` from the config.

Fetch GitHub issue $ARGUMENTS using: gh issue view $ARGUMENTS --json title,body,comments

Read titles and spec bullets of other files in .dash/active/ for awareness of parallel work.

Generate a spec file and write it to .dash/active/$ARGUMENTS.md in this format:

# GH-{number}: {title}

## Spec
2-5 bullet points covering: what to build, key technical decisions, constraints.
Derive these from the issue body and comments.

## Design
Only include this section if the issue involves UI (pages, forms, components, dashboards, etc.).
Skip for non-UI work (APIs, CLI tools, infra, refactoring).
If included, cover whichever of these are relevant:
- Component breakdown: hierarchy of UI pieces
- States: empty, loading, error, populated, disabled
- Responsive: how layout adapts across breakpoints
- Interaction flow: user actions and resulting behavior
- Accessibility: keyboard nav, ARIA roles, focus management
Keep it to 3-6 bullets. Reference existing project design tokens or component libraries if present.

## Tasks
Generate 3-8 tasks. Each should be completable in under 2 hours.
Checklist of concrete implementation steps. Each item should be a single action
a developer can complete and check off. Each task should produce a verifiable outcome
(a passing test, a working command, a visible change).
If a Design section was generated, include at least one task for UI implementation.

## Log
- {today's date as YY-MM-DD}: Created from issue

After writing the file, post the Spec section as a comment on the GitHub issue using:
gh issue comment $ARGUMENTS --body "{spec section}"

Append to .dash/history.log:
PL|{YY-MM-DD}|{issue number}|{short description}
