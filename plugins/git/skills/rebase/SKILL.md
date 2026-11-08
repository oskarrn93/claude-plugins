---
name: rebase
description: Rebase the current branch onto its base, resolve all conflicts automatically, and update the branch's own changes to match what landed in the base (renamed APIs, new helpers, changed conventions). Infers the base and asks for confirmation when none is given. Use whenever the user asks to rebase, update or sync a branch or PR with main/master/develop, catch a branch up with its base, or fix a PR that has merge conflicts or has fallen behind, even if they don't say "rebase".
argument-hint: "[base-branch]"
---

# Rebase

A clean rebase only proves that git could combine the text. The branch can still call a function that was renamed upstream, re-implement a helper that now exists, or follow a convention the base has moved away from. The goal is a branch that reads as if it had been written on top of the current base.

## 1. Preflight

Check the repository state, and stop and tell the user if any of these hold:

- A rebase, merge or cherry-pick is already in progress.
- HEAD is detached.
- The working tree has uncommitted changes. Ask whether to stash them, since they aren't part of what was requested.

Then find the remote (usually `origin`) and run `git fetch <remote> --prune`. Everything below compares against `<remote>/<base>`, because the local base branch is often stale. Use the local branch only if the base doesn't exist on the remote.

Record the branch's current SHA with `git rev-parse HEAD`. It's the recovery point for the final report.

Run `gh stack view --json` on its own, without a pipe, so its exit code is visible. Exit 0 means the branch is part of a stack, so also follow "Stacked branches" at the end of this skill. Exit 2, or an error because the extension isn't installed, means it's an ordinary branch. For any other exit code, report it and stop, because the branch might still be in a stack.

## 2. Determine the base

If the user named a base, use it without asking.

Otherwise infer it, taking the first of these that gives an answer:

1. The base of the branch's open PR: `gh pr view --json baseRefName -q .baseRefName`. This is the only signal that reliably identifies stacked PRs.
2. The nearest long-lived branch. Take the default branch (`git symbolic-ref --short refs/remotes/<remote>/HEAD`) plus any of `main`, `master`, `develop`, `release/*` that exist on the remote, and pick the one with the lowest `git rev-list --count <remote>/<candidate>..HEAD`. On a tie, prefer the default branch.

The upstream tracking branch is normally the same branch on the remote, so it isn't evidence of the base.

Confirm an inferred base with AskUserQuestion before changing anything, because rebasing onto the wrong base pulls unrelated commits into the branch. Put the inferred base first as the recommended option, offer the runner-up candidates, and include in the question how it was inferred, how many commits will be replayed, and how many are incoming. If that tool isn't available, ask in plain text and wait for the answer.

If the current branch is the base, stop and say so. If there are no incoming commits (`<merge-base>` equals the tip of the base), report that the branch is already up to date and stop.

## 3. Survey the incoming changes

Do this before rebasing, while the two sides are still easy to tell apart. Get `<merge-base>` from `git merge-base HEAD <remote>/<base>`, then look at:

```
git log --oneline <merge-base>..HEAD                  # commits to replay
git diff --stat <merge-base> HEAD                     # what the branch touches
git log --format='%h %s' <merge-base>..<remote>/<base>   # incoming commits
git diff --stat <merge-base> <remote>/<base>          # what the base touches
```

If the commit list includes commits that aren't the author's work, such as a parent branch that was squash-merged, stop and ask. It probably needs `git rebase --onto` rather than a plain rebase.

Read the incoming diffs that can affect this branch, and note each thing the branch will need to adapt to. Don't read a large incoming diff end to end. Prioritize:

- **Files both sides touched.** These are the likely conflicts, and the place where intent matters most.
- **Symbols the branch relies on.** Renamed, moved, removed or re-signatured functions, types, routes, config keys and flags. Search the branch's added lines for them, because these are the breakages git won't report.
- **New shared code.** A helper, component or utility that does what the branch implemented by hand.
- **Changed conventions.** Error handling, logging, naming, test patterns, or a library swap. Commit messages and refactors that touch many files are the best clues. Check linter, formatter and CLAUDE.md-style config changes too.
- **Ordered or shared resources.** Migration numbers, registries, changelogs and enum values that may now collide.

## 4. Rebase and resolve conflicts

Run `git rebase <remote>/<base>`. Resolve every conflict yourself rather than handing it back to the user.

During a rebase the sides are the reverse of a merge: `ours`/`HEAD` is the base plus the commits replayed so far, and `theirs` is the branch commit being applied. Keep this in mind, particularly with `git checkout --ours/--theirs`.

For each conflicted file:

1. Work out what each side was trying to do. `git show REBASE_HEAD` gives the branch's intent, and `git log -p <merge-base>..<remote>/<base> -- <file>` gives the base's.
2. Write a result that keeps both intents, in the base's style. Taking one side wholesale is right only when the other side's change is truly obsolete, for example when the base already made the same fix.
3. Regenerate lockfiles and generated code with the project's tool instead of merging them by hand.
4. Check that no conflict markers remain, then `git add` the file.

Continue with `GIT_EDITOR=true git rebase --continue`, which avoids blocking on an editor. If a commit becomes empty because the base already contains it, `git rebase --skip` it and note that in the report.

If the two sides are truly incompatible, choose the option most consistent with the base and record it as a low-confidence resolution for the report. Run `git rebase --abort` only if no coherent result is possible, and explain what blocked it.

## 5. Align the branch with the base

Work through the notes from step 3 and fix what the rebase left behind: update stale references, replace hand-written code with the new shared helper, and follow the changed conventions.

Limit this to code the branch added or changed (`git diff <remote>/<base> HEAD` shows exactly that). Pre-existing code that doesn't follow a new convention isn't this branch's job, and fixing it would bury the PR's real change in noise. Likewise, leave a pattern alone if the base only used it once and it isn't clearly a new direction.

Put these edits in one separate commit, using the repository's commit message style (for example `refactor: align with changes in <base>`). A separate commit lets a reviewer see what changed beyond the rebase, and drop it if they disagree. If nothing needed aligning, don't create a commit.

## 6. Verify

Run the project's build, tests and linter, finding the commands from its docs, CI config, Makefile or package scripts. Fix failures the rebase or alignment caused. If a failure also occurs on the base, leave it and report it.

## 7. Report

Give the report in this format:

```
Rebased <branch> onto <remote>/<base> (<N> commits replayed, <M> incoming)

Conflicts: <file: how it was resolved>, or none
Low-confidence: <resolutions worth a human look>, omit if none
Aligned: <what changed to match the base and why>, or nothing needed
Skipped commits: <already in base>, omit if none
Verification: <what ran and the result>

To undo: git reset --hard <original SHA>
```

## 8. Offer to push

A rebased branch needs a force-push, which rewrites the remote's history, so it's the user's decision even when everything above went well. Once the report is shown, use AskUserQuestion to offer two options: push with `--force-with-lease`, or stop here and do nothing more. If that tool isn't available, ask in plain text and wait for the answer.

If they choose to push, run `git push --force-with-lease <remote> <branch>`, adding `-u` if the branch has no upstream. `--force-with-lease` refuses to overwrite commits the local clone hasn't seen. If it's rejected, someone else pushed to the branch, so report that and stop rather than falling back to `--force`.

If they choose to stop, end without running anything else.

## Stacked branches

A plain `git rebase` of one layer leaves every layer above it based on commits that no longer exist, so the whole stack has to move together. `gh stack` does that part, and this skill still does the survey, conflict resolution, alignment and verification.

Invoke the `gh-stack` skill if it's available (it may be listed as `gh-stack:gh-stack`), since it has the current command details and recovery paths. If it isn't, the commands below are enough for this workflow.

The numbered steps apply with these changes:

- **Base (step 2):** use `trunk` from `gh stack view --json` and skip the confirmation, because the stack already records it. If the user named a different base, stop and ask, since that means restructuring the stack rather than rebasing it.
- **Recovery point (step 1):** record the SHA of every layer, not only the current one.
- **Survey (step 3):** run it from the top of the stack so the commits to replay cover every layer. Commits from a squash-merged layer are expected here and aren't a reason to stop, because `gh stack rebase` skips them.
- **Rebase (step 4):** run `gh stack rebase` instead of `git rebase`. Exit 3 means a conflict: resolve it as in step 4, `git add` the files, then run `gh stack rebase --continue`, repeating for each layer that conflicts. Use `gh stack rebase --abort` where step 4 says to abort, which restores every layer. Avoid `gh stack sync`, because it pushes, and pushing is the user's decision in step 8.
- **Alignment (step 5):** fix each problem in the layer that introduced the code, so that each PR stays correct on its own. Use `gh stack checkout <branch>`, commit there, run `gh stack rebase --upstack`, and return with `gh stack top`. Only layers that needed changes get an alignment commit.
- **Verification (step 6):** verify every layer, because each one becomes its own PR. Check out each with `gh stack checkout <branch>`, bottom to top.
- **Report (step 7):** list conflicts and alignment per layer, and give the undo as one `git branch -f <branch> <original SHA>` per layer, or `git reset --hard <original SHA>` for the checked-out one.
- **Push (step 8):** offer `gh stack push` instead of `git push`. It uses `--force-with-lease` per branch and updates all layers atomically. If it's rejected, report that and stop.
