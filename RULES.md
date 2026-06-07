# Project Rules

## Git and Repository Changes

- Do not commit changes unless the user gives a direct, explicit instruction to commit.
- Do not push changes unless the user gives a direct, explicit instruction to push.
- Creating files, editing files, building, packaging, and testing do not imply permission to commit or push.
- If a change is ready but no commit/push instruction was given, leave the working tree dirty and report the changed files.
- Before any commit, check `git status --short --branch` and make sure only intended files are staged.
- Never include generated build output in commits unless the user explicitly asks for it.

## Commit Message Rules

Use Conventional Commits format:

```text
<type>(optional-scope): <short summary>
```

Allowed types:

- `feat`: a new feature
- `fix`: a bug fix
- `docs`: documentation-only changes
- `style`: formatting changes that do not affect behavior
- `refactor`: code changes that neither fix a bug nor add a feature
- `test`: adding or updating tests
- `build`: build system, packaging, or dependency changes
- `chore`: maintenance changes
- `ci`: CI configuration changes

Examples:

```text
docs: add project rules
fix(preview): render RTL paragraphs correctly
feat(mermaid): add fullscreen diagram viewer
build: package app as DMG
```

Keep commit messages:

- lowercase after the type prefix, unless a proper noun or acronym is required
- imperative and concise
- under 72 characters for the summary when practical
- focused on one logical change
