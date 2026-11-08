---
name: review
description: Review TypeScript code for correctness pitfalls, adherence to idiomatic TypeScript best practices, unnecessary complexity and over-engineering, then offer to apply the fixes. Reviews the current branch's changes unless given a PR, branch or path. Use whenever the user asks to review, audit or critique a TypeScript change, branch, package or PR, including React and Node code written in TypeScript, or to check a TypeScript codebase for over-engineering. Skip it for a quick question about a snippet or a request to simplify one function, which can be answered directly.
argument-hint: "[pr-number|branch|path]"
context: fork
agent: general-purpose
---

# TypeScript code review

Read `${CLAUDE_SKILL_DIR}/references/review-workflow.md` before doing anything else, and follow it from start to finish. It is the process, the language-independent checks and the report format. This file adds what is specific to TypeScript, under the same headings.

## 1. Determine the scope

Review `.ts`, `.tsx`, `.mts` and `.cts` files, `package.json`, `tsconfig*.json` and tests, plus JavaScript files if the project's `tsconfig` sets `allowJs`. Skip `node_modules/`, build output, lockfiles and generated code (a `@generated` or `DO NOT EDIT` header, or a generated `.d.ts`).

## 2. Gather context

The project manifest is the nearest `package.json`, and a workspace can hold several. For each affected project read:

- The resolved `typescript` version in the lockfile, and `engines` or `.nvmrc` for the runtime.
- The effective `tsconfig`: `strict`, `noUncheckedIndexedAccess`, `target`, `lib` and `module`. A claim about what the compiler catches depends on these. `lib` and the runtime together decide which built-ins exist.
- Dependencies, for the framework and test runner, and the lockfile or `packageManager` field, for the package manager.

Prefer the project's own `package.json` scripts, since they carry its flags. Otherwise run the tools directly with the project's package manager:

- Type check: the `typecheck` script, or `tsc --noEmit -p <tsconfig>` (`tsc -b` if the project uses references).
- Lint: the `lint` script, or ESLint or Biome if configured, limited to changed files when there is a base.
- Tests: the runner the project uses, limited to tests affected by the changed files (for a path, those under it).

ESLint configs, package scripts and test files are all code, and install scripts execute too, so never run an install for a PR from a fork. Its fresh worktree has no dependencies to check against, so run no checks for a fork and say so under Checks.

A fresh worktree has no `node_modules`. For anything other than a fork, install there from the lockfile (`npm ci`, `pnpm install --frozen-lockfile`, `yarn install --immutable`). Don't install in the user's checkout; if `node_modules` is missing there, copy the project to a temporary directory, install and run the checks in the copy, then delete it. Review findings still refer to the original paths.

## 3. Review

### Correctness

- **Floating promises.** A promise neither awaited, returned nor given a `.catch`, `async` callbacks passed to `forEach` or `map` whose result is dropped, `return promise` inside `try` where the `catch` was meant to handle it.
- **Partial failure and fan-out.** `Promise.all` where one rejection shouldn't abandon the rest, or over an unbounded list of network or database calls.
- **Type holes.** `as`, `any`, `!` and `@ts-ignore` covering a case that can really occur. A wrong assertion moves a compile error to a runtime crash somewhere else.
- **Trust boundaries.** `JSON.parse`, `response.json()`, `process.env`, request bodies and storage reads cast to a type without validation. The type says nothing about what arrived.
- **Unhandled union members.** A `switch` or `if` chain over a union with no exhaustiveness check, so a new member falls through silently.
- **Falsy values.** `||` or `if (x)` where `0`, `""` or `false` are valid, and `??` was meant.
- **Index access.** `arr[i]` or `record[key]` treated as defined when `noUncheckedIndexedAccess` is off.
- **Errors.** Empty `catch`, a `catch` that assumes `Error`, rethrowing without `cause`, an expected failure signalled by a value callers can ignore.
- **Mutation.** A shallow copy treated as deep, `sort` or `reverse` mutating a parameter or shared array, module-level state in a server shared across requests.
- **Fetch.** `response.ok` unchecked, since `fetch` only rejects on network errors.
- **Lifetimes.** Listeners, timers and subscriptions never removed, `AbortSignal` not passed to the work it should cancel.
- **Numbers.** Money in floats, 64-bit IDs through `number`, default `sort()` on numbers, which is lexicographic.
- **Security.** Unsanitized input to `innerHTML` or `dangerouslySetInnerHTML`, `exec` with interpolated input where `execFile` works, untrusted keys merged into objects (prototype pollution), user input in file paths or `new RegExp`.
- **Packaging.** A `devDependency` imported at runtime, ESM and CommonJS mismatches, `exports` or `types` not matching the build output.
- **React, if used.** Stale closures, effects missing cleanup or dependencies, state mutated in place, array index as the `key` of a list that reorders.

### Over-engineering

| Pattern | Prefer |
| --- | --- |
| Interface or abstract class with one implementation | The class or function; structural typing lets a consumer declare an interface later |
| Class with no instance state, or only static methods | Module-level functions |
| Type parameter used only once in a signature | The concrete type, or `unknown` |
| Conditional, mapped or recursive types that serve a couple of call sites | A plain type spelled out |
| Mapper functions and DTO types copying an identical shape | Use the one type |
| Runtime validation of data the type system already guarantees | Validate at the trust boundary, once |
| `Result` or `Either` wrappers in code whose callers only unwrap them | Throw, or return a discriminated union where callers branch |
| Custom `Error` subclass no caller checks with `instanceof` | `new Error(message, { cause })` |
| Barrel `index.ts` files re-exporting internals of an application | Import from the source module |
| `export` on names used only in their own file | Drop the `export` |
| `useMemo`, `useCallback` or `memo` with no measured or referential need | Plain values and functions |
| Global store or context for state one component tree uses locally | `useState` or props |
| Utility library call for what a built-in does | The built-in |

For the patterns that rest on "nothing uses this", an application or internal package means a `"private": true` package, a module its package's `exports` doesn't expose, or a package nothing outside the repository imports.

### Simplification

Newer features, each usable only if the project's `typescript` version, `target`/`lib` and runtime all have it:

| Since | Available |
| --- | --- |
| TS 3.7, ES2020 | `?.`, `??` |
| TS 4.9 | `satisfies` |
| TS 5.0 | `const` type parameters |
| TS 5.2 | `using` declarations |
| TS 5.4 | `NoInfer` |
| TS 5.5 | Inferred type predicates, so `filter((x) => x != null)` narrows |
| ES2021 | `replaceAll`, `Promise.any`, `??=`, `\|\|=` |
| ES2022 | `.at()`, `Object.hasOwn`, `Error` `cause` |
| ES2023 | `toSorted`, `toReversed`, `with`, `findLast` |
| ES2024 | `Object.groupBy`, `Map.groupBy`, `Promise.withResolvers` |
| ES2025 | `Set` methods such as `union`, iterator helpers, `Promise.try`, `RegExp.escape` |
| Node 17 | `structuredClone`, `AbortSignal.timeout` |
| Node 18 | Global `fetch`, `node:test`, `util.parseArgs` |
| Node 20 | `AbortSignal.any`, `import.meta.dirname` (20.11) |
| Node 22 | `fs.glob` |

Also look for `async` wrappers that only return another promise, `await` chains rebuilt by hand with `.then`, and types restated where inference already gives the same result.

### Idiom

- Discriminated unions instead of a bag of optional fields whose valid combinations live only in comments.
- `unknown` plus narrowing instead of `any`. Type guards that really check what they claim.
- `satisfies` instead of an annotation or assertion when the literal type is worth keeping.
- `readonly` and `as const` where a value isn't meant to change.
- Explicit return types on exported functions of a published API.
- Doc comments on exports that say something the signature doesn't.

Leave `type` versus `interface`, named versus default exports and `enum` versus unions to the project's convention. They are taste unless the code is inconsistent with its neighbours or a compiler option such as `erasableSyntaxOnly` rules one out.

### Tests

- Mocking the project's own modules (`vi.mock`, `jest.mock`) where passing a fake would do.
- `expect(promise).rejects` or `.resolves` without `await`, and an async test that doesn't await its work: both pass regardless of the result.
- Real timers where fake timers apply.
- `.only` left in, and `.skip` with no reason.
- Snapshots so large that nobody reads a failing diff.

## 5. Report

Use `TypeScript <version>, <runtime and version>` as the language version.

## 6. Hand back

The recheck commands are the type check, the linter if it ran, and the tests for the changed files, written out as the exact commands you used.
