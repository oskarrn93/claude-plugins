---
name: review
description: Review Go code for correctness pitfalls, adherence to idiomatic Go best practices, unnecessary complexity and over-engineering, then offer to apply the fixes. Reviews the current branch's changes unless given a PR, branch or path. Use whenever the user asks to review, audit or critique a Go change, branch, package or PR, or to check a Go codebase for over-engineering. Skip it for a quick question about a snippet or a request to simplify one function, which can be answered directly.
argument-hint: "[pr-number|branch|path]"
context: fork
agent: general-purpose
---

# Go code review

Good Go is plain Go. The most valuable review comment is often "delete this": every abstraction has to pay for itself today, not in a future that may never come. The goal is a short list of findings a maintainer would act on, not an exhaustive list of everything that could be different.

## 1. Determine the scope

Find the remote (usually `origin`) and default branch, and run `git fetch <remote>`. Compare against `<remote>/<default>`, because the local default branch is often stale and would pull other people's commits into the diff.

- PR number: use `gh pr diff <number>`, and `gh pr view <number>` for its intent. Check the PR out in a temporary `git worktree` and do everything below there, so that file reads, call-site searches and checks see the PR's code rather than the local checkout.
- Branch: review the named branch against the default branch. If it isn't the current branch, use a temporary worktree as for a PR.
- Path: review the code at that path in full. There's no base, so every finding in it is in scope.
- Nothing given: review uncommitted changes plus the current branch's commits since its merge base with `<remote>/<default>`.

Review `.go` files, `go.mod` and tests. Skip `vendor/` and files headed `// Code generated ... DO NOT EDIT.`. If the scope contains no Go changes, say so and stop.

Except for a path, limit findings to code the change added or modified. Pre-existing code matters only when the change makes it wrong or when it's the context for a simplification of the new code.

## 2. Gather context

1. Find the nearest `go.mod` for each changed file, since a repository can hold several modules. Read its `go` directive, and only suggest language and library features available at that version. Run the commands below from each affected module's root. If there is no `go.mod`, skip those commands and say so in the report.
2. Read each changed file in full, not only its hunks. Whether an abstraction is justified depends on its callers, so search for call sites and implementations.
3. Check the project's CLAUDE.md, linter config and neighbouring code. An established project convention beats a general preference here.
4. Run `go build ./...` and `go vet ./...`. Run `go test -race -timeout 5m` on the changed packages (for a path, the packages under it), and `golangci-lint run` if it's installed, with `--new-from-rev=<base>` when there is a base. Don't restate what these tools already catch in the checks below.
   - `go test` executes the code under review. Skip it for a PR from a fork (`gh pr view <number> --json isCrossRepository`), since its author may be untrusted.
   - Drop `-race` if cgo isn't available. If tests need a service that isn't available, skip them. Note anything skipped in the report.
   - Report a failure as a finding only if the change caused it. List pre-existing failures under Checks.

## 3. Review, in priority order

### Correctness

Things that compile, pass review at a glance, and fail in production:

- **Goroutine lifetime.** Every `go` statement needs an answer to "how does this stop?". Watch for sends on an unbuffered channel whose receiver has left after a timeout or early return, and `wg.Add` called inside the goroutine.
- **Shared state.** Unsynchronized map or slice access, a struct containing a `sync.Mutex` copied by value, `append` to a slice that aliases another's backing array.
- **Context.** Not propagated to blocking calls, `context.Background()` created mid-request, missing `defer cancel()`, or a context stored in a struct.
- **Errors.** Ignored or shadowed errors, comparison with `==` where the error may be wrapped, handled twice (logged and returned), `panic` in library code for an ordinary failure.
- **Typed nil.** Returning a nil concrete pointer as an `error` or other interface, which is non-nil to the caller.
- **Resources.** Unclosed `resp.Body` or `sql.Rows`, missing `rows.Err()` check, `defer` inside a long loop, unbounded `io.ReadAll` on untrusted input.
- **Network defaults.** `http.DefaultClient` or `http.Server` with no timeouts on anything that faces the network.
- **Security.** SQL or shell commands assembled from input by string concatenation.
- **Loop variables.** Captured by closures when `go.mod` is below 1.22.
- **Modules.** A `replace` directive pointing at a local path, left in by accident.

### Over-engineering

Look at this hardest, since linters can't. Flag something only after confirming from the call sites that the complexity isn't earning its place:

| Pattern | Prefer |
| --- | --- |
| Interface with one implementation, defined next to that implementation | The concrete type; let the consumer define an interface when it needs one |
| Large interface mirroring a struct's methods | A one- or two-method interface at the point of use |
| Generic function or type used with one type argument | The concrete version |
| Functional options or a builder for a few fields, all set by every caller | Plain parameters or a config struct |
| Service, repository or manager layers that only forward calls | Call the underlying code directly |
| Factories, registries, strategies or plugin systems with one variant | A direct call or a `switch` |
| DI framework or container in a small program | Explicit wiring in `main` |
| Goroutines, channels or worker pools around work that is fast or sequential | A plain function call |
| Channels used only to guard state | `sync.Mutex` |
| Custom error type no caller inspects | `fmt.Errorf` with `%w`, or a sentinel if callers need `errors.Is` |
| Thin wrapper around a standard library call | The standard library call |
| Getters and setters on fields with no invariant | An exported field |
| Options, flags or config that nothing sets | Remove them and hard-code the value |
| Retries, fallbacks, caches or nil checks for cases that can't occur | Remove them |
| Packages split by kind (`models`, `utils`, `common`, `helpers`), or one package per type | Fewer packages, organized by what they provide |
| Exported identifiers used only inside their package | Unexported |
| New dependency for something the standard library or a few lines cover | Drop the dependency |

A repository search can't see a library's outside callers. Apply the patterns that rest on "nothing uses this" (single-implementation interfaces, uninspected error types, getters, unset options, exported identifiers) only to `main` packages, `internal/` packages and modules nothing outside the repository imports.

Some abstractions are correct even with one production implementation. Leave alone an interface at a real I/O boundary that tests fake, an interface required by another package, and a layer that enforces something such as transactions or authorization.

Small duplication is usually better than a helper. Don't suggest extracting code unless the copies must change together.

### Simplification

- Happy path at the left margin: guard clauses and early returns instead of nested `else`.
- Variables, parameters, branches and return values that serve no purpose.
- Bare `return` in anything longer than a few lines. Named results are fine, and necessary when a `defer` changes the returned error.
- Hand-written code that a newer language or library feature replaces, if the module's Go version has it:

  | Go | Available |
  | --- | --- |
  | 1.18 | `any`, `strings.Cut` |
  | 1.20 | `errors.Join`, `context.WithCancelCause` |
  | 1.21 | `min`, `max`, `clear`, `slices`, `maps`, `log/slog` |
  | 1.22 | `for i := range n`, `cmp.Or`, method and wildcard patterns in `http.ServeMux` |
  | 1.23 | `slices.Collect`, `slices.Sorted`, `maps.Keys`, range-over-func iterators |
  | 1.24 | `t.Context`, `b.Loop`, `strings.SplitSeq`, the `omitzero` JSON tag |
  | 1.25 | `sync.WaitGroup.Go` |
  | 1.26 | `errors.AsType`, `new(expr)` |

  Skip a replacement that makes the code shorter but harder to read.

### Idiomatic Go

Only where it hurts clarity or the package's API:

- Errors wrapped with useful context and `%w` when callers may inspect them, `%v` to deliberately hide an implementation detail. Messages lowercase, no `failed to` chains that repeat at every level.
- Stutter (`user.UserService`), `Get` prefixes on getters, inconsistent receiver names, mixed pointer and value receivers on a type.
- Zero values made useful, so no constructor is needed where a struct literal works.
- `ctx context.Context` as the first parameter. Accept interfaces where that helps, and return concrete types.
- Doc comments on exported identifiers that say something the signature doesn't.

### Tests

- Tests assert behaviour, not mock call sequences. A small hand-written fake usually beats a mocking framework.
- Table-driven only when the cases really share a shape; a table full of flags and conditional setup should be separate tests.
- `t.Helper`, `t.Cleanup` and `t.TempDir` where they apply. `time.Sleep` used for synchronization is a flaky test.
- Critical new logic with no test at all. Don't ask for tests of trivial code.

## 4. Verify each finding

Before reporting, re-read the code and drop anything that fails one of these:

- It's a real problem in this code, and the claim is confirmed. "Only one implementation" requires having searched for others.
- It describes a concrete consequence: the failure scenario, or the code that goes away.
- It proposes a specific replacement that works at this Go version and keeps the behaviour and any exported API that others import, unless the behaviour is the bug.
- It isn't personal taste or something the project's formatter or linter already enforces.

## 5. Report

Group by severity and most important first. Omit empty sections.

```
<scope reviewed> (Go <version>)

Must fix (bugs, races, leaks, security)
- path/file.go:42 — <problem and consequence>
  Fix: <specific change>

Simplify (over-engineering and unnecessary complexity)
- path/file.go:10 — <what isn't earning its place, and the evidence>
  Fix: <specific change> (about -<N> lines)

Consider (idioms and tests)
- path/file.go:88 — <problem>
  Fix: <specific change>

Checks: <build, vet, test, lint results, pre-existing failures, anything skipped and why>
```

If nothing survives verification, say the code looks good and give the check results. Don't invent findings to fill the report.

## 6. Hand back

Reviewing doesn't change code, so applying fixes is the user's decision. This skill runs in a forked context that can't ask the user anything, and only your final message reaches the main session, so make no edits and put the whole report in that message.

If you used a temporary worktree, remove it and end after the report, since the fixes would have nowhere to land. Otherwise end the message with this note for the main session:

> Review complete; no code has changed. Use AskUserQuestion to offer: apply everything, apply only "Must fix", or stop here. If they choose to apply, make the changes, rerun `go build ./...`, `go vet ./...` and the tests for the changed packages, report what changed and any failures, and leave the changes uncommitted. If a Stop hook reports lint errors before they've chosen to apply, relay the errors and don't edit code.
