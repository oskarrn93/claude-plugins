---
name: conventional-commit
description: Write commit messages and pull request titles in Conventional Commits 1.0.0 format so that squash-merging drives the semver-release GitHub Actions workflow (feat → minor, fix/perf → patch, breaking → major). Use whenever the user asks to commit, write or amend a commit message, or choose, write or fix a PR title, and whenever you are about to run `git commit` or `gh pr create` yourself, even if they don't mention conventional commits or releases.
---

# Conventional commit

The release workflow (`oskarrn93/github-actions` → `semver-release.yml`) computes the next version from the commit **subjects** on the default branch since the last `vX.Y.Z` tag. With squash merging, the squash commit's subject is what it sees, and that subject comes from the PR title. A wrong title therefore ships the wrong version or no release at all, so the title matters more than the individual commits on the branch.

## What the workflow reads

It matches these patterns, which are stricter than the Conventional Commits spec:

| Bump | Matches |
|------|---------|
| major | subject `^[a-z]+(\([^)]*\))?!:` (any type with `!`), or a body line starting `BREAKING CHANGE:` or `BREAKING-CHANGE:` |
| minor | subject `^feat(\([^)]*\))?:` |
| patch | subject `^(fix\|perf)(\([^)]*\))?:` |
| none | anything else, including `docs`, `chore`, `refactor`, `test`, `ci`, `build`, `style` |

Consequences worth respecting:

- The type must be **lowercase**, directly followed by `:`. `Feat:` or `feat :` releases nothing.
- A scope can't contain `)`.
- Only `feat`, `fix` and `perf` release on their own, so choose the type by whether the change should reach users as a new version, not by what feels closest. A user-visible bug fix is `fix` even if the diff is a refactor; a pure refactor, CI or docs change is not a release.
- `refactor!:` or `chore!:` still produces a major bump. Use `!` only for a real breaking change.

## Format

Follow the [Conventional Commits 1.0.0 specification](https://www.conventionalcommits.org/en/v1.0.0/#specification). The workflow's patterns are a stricter subset of it, so a message that satisfies both is valid everywhere.

```
<type>[(scope)][!]: <description>

[body]

[footer(s)]
```

- **Type:** a noun. `feat` (new feature) and `fix` (bug fix) are the spec's required types. Others are allowed: `perf`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`, `style`, `revert`. The spec treats types as case-insensitive, but the workflow only matches lowercase, so always write lowercase.
- **Scope:** optional noun in parentheses describing a section of the codebase, e.g. `feat(parser):`. Follow scopes already used in `git log` rather than inventing new ones.
- **Description:** required, directly after the colon and one space. Imperative mood, lowercase start, no trailing period, subject under about 72 characters. In a PR title, `(#123)` gets appended on squash, so leave room.
- **Body:** optional. It starts one blank line after the description and is free-form, with any number of paragraphs. Use it for the *why*; skip it for small changes.
- **Footers:** optional. One blank line after the body (or after the description if there is no body). Each is `token: value` or `token #value`, with `-` in place of spaces in the token (`Reviewed-by: Z`, `Closes #12`). `BREAKING CHANGE` is the one token that keeps its space.
- **Breaking changes:** either `!` immediately before the colon (`feat(api)!: drop v1 endpoints`) or a `BREAKING CHANGE: <description>` footer, in uppercase (`BREAKING-CHANGE` is a synonym). With `!`, the footer may be omitted, and the description then has to say what broke. Use both when migration steps need more room than the subject allows. A breaking change can be of any type.

## Commits

Write each commit in this format, one logical change per commit. When the PR will be squash-merged, the individual commit subjects are discarded in the release calculation, but keeping them valid costs nothing and covers repositories that merge or rebase instead.

If the user didn't specify the change, run `git diff --staged` (or `git diff` if nothing is staged) and `git log -5 --format=%s` to match the existing style. If nothing is staged, ask which changes to include rather than staging everything.

## PR titles

The PR title is the future squash subject, so it must be a valid conventional subject describing the **whole PR**, not its last commit. When the PR mixes kinds of change, use the one with the highest release impact that the PR actually delivers (breaking > `feat` > `fix`/`perf` > the rest), so a PR that adds a feature and fixes a typo along the way is a `feat`.

Use the same format. If the user wants the broader PR title/description guidance (outcome-focused wording), the `pull-request` skill covers that and defers to this format for the prefix.

### Squash settings

Check how the repository builds the squash commit, because it decides where a breaking-change signal survives:

```
gh api repos/{owner}/{repo} --jq '{title: .squash_merge_commit_title, message: .squash_merge_commit_message}'
```

- `squash_merge_commit_title`: `PR_TITLE` always uses the PR title. `COMMIT_OR_PR_TITLE` uses the commit's subject instead when the PR has exactly one commit, so in that case the single commit's subject must be valid too.
- `squash_merge_commit_message`: `COMMIT_MESSAGES` lists the commits of a multi-commit PR as `* ` bullets, so a `BREAKING CHANGE:` footer in one of them no longer starts a line and the workflow misses it. `PR_BODY` keeps the PR description as the body, where a footer line is preserved.

Because of this, always mark breaking changes with `!` in the title. Treat the footer as documentation, and only rely on it when the setting is `PR_BODY` and the footer is in the PR description.

## Before finishing

For a PR title or commit that will be merged, state the release it will cause, using the table above (for example "minor: `feat`"), so the user can catch a mismatch before merging. If it releases nothing and the user expected a release, say so and suggest the type that would.
