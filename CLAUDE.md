# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Core principles

- Make the smallest change that solves the problem. Avoid drive-by refactors.
- Match existing patterns in the file you're editing before introducing new ones.
- Read before you write. Skim related files to understand conventions.
- If a request is ambiguous, ask one question instead of guessing.
- Never invent APIs, library functions, or config keys. If unsure, check or say so.

## Code style

**Universal rules (any language):**
- Names describe intent, not type. `userCount` over `n`, `isReady` over `flag`.
- Functions do one thing. If you need "and" to describe it, split it.
- Keep functions short enough to read without scrolling. ~40 lines is a soft ceiling.
- No commented-out code. Delete it; git remembers.
- No dead code, unused imports, or unused variables.
- Prefer early returns over deep nesting.
- Comments explain *why*, not *what*. The code shows what.
- Errors are handled explicitly — never swallow exceptions silently.
- No magic numbers. Name the constant.
- use a venv if one exists use it, if not create one

**Formatting:**
- Use the project's existing formatter/linter config. Don't override it.
- If no formatter exists for a language, follow its standard community style
  (PEP 8 for Python, gofmt for Go, Prettier defaults for JS/TS, rustfmt for Rust).
- Indentation matches the file you're in. Do not mix tabs and spaces.

**Imports:**
- Group: stdlib → third-party → local. Blank line between groups.
- No wildcard imports unless the language idiom calls for it.

## Git workflow

**Commit after every small edit.** A "small edit" means: one logical change that
leaves the repo in a working state. Examples: a new function, a bug fix, a
refactor of one module, a config change, a doc update.

**For each edit:**
1. Make the change.
2. Verify it doesn't obviously break things (run tests/build if relevant and quick).
3. `git add` only the files related to this change — never `git add .` blindly.
4. Commit with a meaningful message (see format below).
5. `git push` to the current branch.

**If something fails** (tests, build, lint), fix it before committing. Do not
commit broken code with a "WIP" message unless explicitly asked.

## Commit message format

Follow Conventional Commits:

```
<type>(<scope>): <subject>

<body>
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `style`, `build`, `ci`

**Rules:**
- Subject line ≤ 72 characters, imperative mood ("add" not "added"), no period.
- Scope is optional but useful — typically the module or area touched.
- Body explains *why* the change was made and any non-obvious tradeoffs. Wrap at 72 chars.
- Skip the body for trivially obvious commits (typo fixes, formatting).
- Reference issues with `Closes #123` or `Refs #123` when applicable.

**Good examples:**
```
feat(auth): add refresh token rotation

Tokens were previously valid until expiry with no revocation path.
Rotation invalidates the previous token on each refresh, limiting
the blast radius if a token leaks.
```

```
fix(parser): handle trailing comma in object literals

Closes #142
```

```
refactor(db): extract connection pool into its own module
```

**Bad examples (do not use):**
- `update stuff`
- `fix bug`
- `wip`
- `changes`
- `asdf`

## What NOT to do

- Don't push directly to `main`/`master` if a feature branch is in use — check first.
- Don't force-push (`--force`) without `--force-with-lease`, and not on shared branches.
- Don't commit secrets, API keys, `.env` files, or large binary blobs.
- Don't commit generated files (build outputs, `node_modules`, `__pycache__`, `.DS_Store`).
- Don't rewrite history on branches others may have pulled.
- Don't bundle unrelated changes into one commit. Split them.

## Before pushing

Quick mental checklist:
- Does the diff contain only what I intended?
- Is the commit message clear to someone reading it in six months?
- Are tests still passing (if a quick test command exists)?
- Did I leave any debug prints, `console.log`, `print()`, or `TODO: remove` notes?
