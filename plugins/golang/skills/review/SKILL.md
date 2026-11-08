---
name: review
description: Review Go code for correctness pitfalls, adherence to idiomatic Go best practices, unnecessary complexity and over-engineering, then offer to apply the fixes. Reviews the current branch's changes unless given a PR, branch or path. Use whenever the user asks to review, audit or critique a Go change, branch, package or PR, or to check a Go codebase for over-engineering. Skip it for a quick question about a snippet or a request to simplify one function, which can be answered directly.
argument-hint: "[pr-number|branch|path]"
context: fork
agent: general-purpose
---

# Go code review

Read `${CLAUDE_SKILL_DIR}/references/review-workflow.md` before doing anything else, and follow it from start to finish. It is the process, the language-independent checks and the report format. This file adds what is specific to Go, under the same headings.

## 1. Determine the scope

Review `.go` files, `go.mod` and tests. Skip `vendor/` and files headed `// Code generated ... DO NOT EDIT.`.

## 2. Gather context

The project manifest is the nearest `go.mod`, and its `go` directive sets the version. If there is no `go.mod`, skip the commands below and say so in the report.

Run `go build ./...` and `go vet ./...`. Run `go test -race -timeout 5m` on the changed packages (for a path, the packages under it), and `golangci-lint run` if it's installed, with `--new-from-rev=<base>` when there is a base.

Drop `-race` if cgo isn't available.

## 3. Review

### Correctness

- **Goroutine lifetime.** Every `go` statement needs an answer to "how does this stop?". Watch for sends on an unbuffered channel whose receiver has left after a timeout or early return, and `wg.Add` called inside the goroutine.
- **Shared state.** Unsynchronized map or slice access, a struct containing a `sync.Mutex` copied by value, `append` to a slice that aliases another's backing array.
- **Context.** Not propagated to blocking calls, `context.Background()` created mid-request, missing `defer cancel()`, or a context stored in a struct.
- **Errors.** Ignored or shadowed errors, comparison with `==` where the error may be wrapped, handled twice (logged and returned), `panic` in library code for an ordinary failure.
- **Typed nil.** Returning a nil concrete pointer as an `error` or other interface, which is non-nil to the caller.
- **Resources.** Unclosed `resp.Body` or `sql.Rows`, missing `rows.Err()` check, `defer` inside a long loop, unbounded `io.ReadAll` on untrusted input.
- **Network defaults.** `http.DefaultClient` or `http.Server` with no timeouts.
- **Loop variables.** Captured by closures when `go.mod` is below 1.22.
- **Modules.** A `replace` directive pointing at a local path, left in by accident.

### Over-engineering

| Pattern | Prefer |
| --- | --- |
| Interface with one implementation, defined next to that implementation | The concrete type; let the consumer define an interface when it needs one |
| Large interface mirroring a struct's methods | A one- or two-method interface at the point of use |
| Functional options or a builder for a few fields, all set by every caller | Plain parameters or a config struct |
| Channels used only to guard state | `sync.Mutex` |
| Custom error type no caller inspects | `fmt.Errorf` with `%w`, or a sentinel if callers need `errors.Is` |
| Getters and setters on fields with no invariant | An exported field |
| One package per type | Fewer packages, organized by what they provide |
| Exported identifiers used only inside their package | Unexported |

For the patterns that rest on "nothing uses this", an application or internal package means a `main` package, an `internal/` package or a module nothing outside the repository imports.

### Simplification

- Bare `return` in anything longer than a few lines. Named results are fine, and necessary when a `defer` changes the returned error.
- Newer features, if the module's Go version has them:

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

### Idiom

- Errors wrapped with useful context and `%w` when callers may inspect them, `%v` to deliberately hide an implementation detail. Messages lowercase, no `failed to` chains that repeat at every level.
- Stutter (`user.UserService`), `Get` prefixes on getters, inconsistent receiver names, mixed pointer and value receivers on a type.
- Zero values made useful, so no constructor is needed where a struct literal works.
- `ctx context.Context` as the first parameter. Accept interfaces where that helps, and return concrete types.
- Doc comments on exported identifiers that say something the signature doesn't.

### Tests

- `t.Helper`, `t.Cleanup` and `t.TempDir` where they apply.

## 5. Report

Use `Go <version>` as the language version.

## 6. Hand back

The recheck commands are `go build ./...`, `go vet ./...` and the tests for the changed packages.

Add this to the end of the note, because this plugin's Stop hook can fire before the user has chosen: "If a Stop hook reports lint errors before they've chosen to apply, relay the errors and don't edit code."
