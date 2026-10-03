# Agents

Entry point for AI agents working in this repo.

## Conversation Rules

- Use the user's language in conversation.
- Apply the clarity principles of [ASD-STE100](https://www.asd-ste100.org/) to all replies to the user, adapted naturally to the conversation language.
- Separate verified facts from assumptions and untested behavior.
- When reporting completed work, state what changed, why it matters and what was verified; include relevant limitations.

## Rules

Use English throughout the codebase, including identifiers, comments, user-facing text, logs and error messages.

| Task          | Rules                         |
| ------------- | ----------------------------- |
| Git           | `.agents/rules/git-style.md`   |
| Documentation | `.agents/rules/docs-style.md`  |

- Load only the rule files the task needs.
- Follow the rule files exactly.
- Ask before deviating if a rule conflicts with the current request.
