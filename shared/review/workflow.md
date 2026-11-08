# Code review workflow

Language-independent process and best practices for code review. The language skill that sent you here supplies the rest under matching headings: which files count, which checks to run, and the checks specific to the language. Where the two conflict, the language skill wins.

Good code is plain code. The most valuable review comment is often "delete this": every abstraction has to pay for itself today, not in a future that may never come. The goal is a short list of findings a maintainer would act on, not an exhaustive list of everything that could be different.

## 1. Determine the scope

Find the remote (usually `origin`) and default branch, and run `git fetch <remote>`. Compare against `<remote>/<default>`, because the local default branch is often stale and would pull other people's commits into the diff.

- PR number: use `gh pr diff <number>`, and `gh pr view <number>` for its intent. Check the PR out in a temporary `git worktree` and do everything below there, so that file reads, call-site searches and checks see the PR's code rather than the local checkout.
- Branch: review the named branch against the default branch. If it isn't the current branch, use a temporary worktree as for a PR.
- Path: review the code at that path in full. There's no base, so every finding in it is in scope.
- Nothing given: review uncommitted changes plus the current branch's commits since its merge base with `<remote>/<default>`.

Review the file types the language skill lists, and skip generated and vendored code. If the scope contains no changes in this language, say so and stop.

Except for a path, limit findings to code the change added or modified. Pre-existing code matters only when the change makes it wrong or when it's the context for a simplification of the new code.

## 2. Gather context

1. Find the nearest project manifest for each changed file, since a repository can hold several projects. Read the language and runtime versions it declares, and only suggest language and library features available at those versions. Run the language skill's commands from each affected project's root.
2. Read each changed file in full, not only its hunks. Whether an abstraction is justified depends on its callers, so search for call sites and implementations.
3. Check the project's CLAUDE.md, linter config and neighbouring code. An established project convention beats a general preference here.
4. Run the language skill's checks. Don't restate what these tools already catch in the checks below.
   - Tests execute the code under review. Skip anything that executes the PR's code for a PR from a fork (`gh pr view <number> --json isCrossRepository`), since its author may be untrusted.
   - If a check needs a tool or service that isn't available, skip it. Note anything skipped in the report.
   - Report a failure as a finding only if the change caused it. List pre-existing failures under Checks.

## 3. Review

Work through these in priority order: correctness, over-engineering, simplification, idiom and tests, applying the checks below together with the language skill's checks for each.

### Correctness

Things that compile, pass review at a glance, and fail in production:

- **Security.** SQL or shell commands assembled from input by string concatenation.
- **Untrusted input.** Unbounded reads of request bodies, files or other data the caller controls.
- **Network defaults.** Outbound calls and servers with no timeouts on anything that faces the network.

### Over-engineering

Look at this hardest, since linters can't. Flag something only after confirming from the call sites that the complexity isn't earning its place:

| Pattern | Prefer |
| --- | --- |
| Generic function or type used with one type argument | The concrete version |
| Service, repository or manager layers that only forward calls | Call the underlying code directly |
| Factories, registries, strategies or plugin systems with one variant | A direct call or a `switch` |
| DI framework or container in a small program | Explicit wiring at the entry point |
| Concurrency or worker pools around work that is fast or sequential | A plain function call |
| Thin wrapper around a standard library call | The standard library call |
| Options, flags or config that nothing sets | Remove them and hard-code the value |
| Retries, fallbacks, caches or nil checks for cases that can't occur | Remove them |
| Packages or directories split by kind (`models`, `utils`, `common`, `helpers`) | Fewer of them, organized by what they provide |
| New dependency for something the standard library or a few lines cover | Drop the dependency |

A repository search can't see a library's outside callers. Apply the patterns that rest on "nothing uses this" (single-implementation abstractions, uninspected error types, unset options, exported names) only to applications, internal packages and libraries nothing outside the repository imports.

Some abstractions are correct even with one production implementation. Leave alone an interface at a real I/O boundary that tests fake, an interface required by another package, and a layer that enforces something such as transactions or authorization.

Small duplication is usually better than a helper. Don't suggest extracting code unless the copies must change together.

### Simplification

- Happy path at the left margin: guard clauses and early returns instead of nested `else`.
- Variables, parameters, branches and return values that serve no purpose.
- Hand-written code that a newer language or library feature replaces, if the project's version has it. Skip a replacement that makes the code shorter but harder to read.

### Idiom

Only where it hurts clarity or the package's API. The language skill lists what to look for.

### Tests

- Tests assert behaviour, not mock call sequences. A small hand-written fake usually beats a mocking framework.
- Table-driven or parameterized only when the cases really share a shape; a table full of flags and conditional setup should be separate tests.
- Sleeping for synchronization is a flaky test.
- Critical new logic with no test at all. Don't ask for tests of trivial code.

## 4. Verify each finding

Before reporting, re-read the code and drop anything that fails one of these:

- It's a real problem in this code, and the claim is confirmed. "Only one implementation" requires having searched for others.
- It describes a concrete consequence: the failure scenario, or the code that goes away.
- It proposes a specific replacement that works at this project's versions and keeps the behaviour and any exported API that others import, unless the behaviour is the bug.
- It isn't personal taste or something the project's formatter or linter already enforces.

## 5. Report

Group by severity and most important first. Omit empty sections. Replace `<language version>` with the language and version, as the language skill specifies.

```
<scope reviewed> (<language version>)

Must fix (bugs, races, leaks, security)
- path/to/file:42 — <problem and consequence>
  Fix: <specific change>

Simplify (over-engineering and unnecessary complexity)
- path/to/file:10 — <what isn't earning its place, and the evidence>
  Fix: <specific change> (about -<N> lines)

Consider (idioms and tests)
- path/to/file:88 — <problem>
  Fix: <specific change>

Checks: <results of each check, pre-existing failures, anything skipped and why>
```

If nothing survives verification, say the code looks good and give the check results. Don't invent findings to fill the report.

## 6. Hand back

Reviewing doesn't change code, so applying fixes is the user's decision. This skill runs in a forked context that can't ask the user anything, and only your final message reaches the main session, so make no edits and put the whole report in that message.

If you used a temporary worktree, remove it and end after the report, since the fixes would have nowhere to land. Otherwise end the message with this note for the main session, replacing `<recheck commands>` with the language skill's recheck commands, because the main session can't see this file:

> Review complete; no code has changed. Use AskUserQuestion to offer: apply everything, apply only "Must fix", or stop here. If they choose to apply, make the changes, rerun <recheck commands>, report what changed and any failures, and leave the changes uncommitted.
