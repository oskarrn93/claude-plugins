---
name: pull-request
description: Create a GitHub pull request whose title and description explain the outcome of the change from a product and business perspective, grouping the work by the larger picture instead of listing every change. Use whenever the user asks to open, create, raise, submit or draft a PR or pull request, or to write, rewrite or fix a PR title or description, even if they don't mention the business perspective.
argument-hint: "[base-branch]"
---

# Pull request

The diff already records every change. The title and description's job is to tell someone who won't read the diff (a product manager, a stakeholder, a reviewer getting oriented) what is different for the people affected, and why that was worth doing.

## 1. Preflight

Find the remote (usually `origin`), run `git fetch <remote> --prune`, and get the default branch from `git symbolic-ref --short refs/remotes/<remote>/HEAD`.

Stop and tell the user if HEAD is detached or the current branch is the default branch, since there's nothing to propose yet. If the working tree has uncommitted changes, ask whether they belong in this PR, because the description must match what actually ships. If they do, commit them in the repository's commit style before continuing.

Check for an existing PR with `gh pr view --json number,url,state,title,body,baseRefName`. Only `OPEN` counts, because `gh` also returns closed and merged PRs for the branch, and those should be treated as no PR at all. If one is open, update it in step 5 instead of creating a second PR. Its existing body may contain context from humans, so keep anything still accurate.

Determine the base, taking the first of these that gives an answer: the base the user named, the base of the open PR, the default branch. A branch can target something other than the default branch, and comparing against the wrong base would describe commits that aren't part of this PR.

If `git rev-list --count <remote>/<base>..HEAD` is 0, stop and say so, because there's nothing to open a PR for.

Run `gh stack view --json` on its own, without a pipe, so its exit code is visible. Exit 0 means the branch is part of a stack, so also follow "Stacked branches" at the end of this skill. Exit 2, or an error because the extension isn't installed, means it's an ordinary branch. For any other exit code, report it and stop, because the branch might still be in a stack.

## 2. Find out why the change exists

Read `git log <remote>/<base>..HEAD` and `git diff <remote>/<base>...HEAD`, enough to understand what the branch does in practice.

The diff shows what changed but rarely why. Look for the reason in the current conversation, commit message bodies, the branch name, and any linked issue or ticket (`gh issue view <number>`).

Describe only what these sources support. An invented benefit or number misleads exactly the readers who can't check it against the code, so leave out metrics, customer demand and revenue effects unless a source states them. If the reason matters and can't be found, ask the user one short question. If they don't know either, describe the observable effect and stop there.

## 3. Group by outcome

Sort the changes into the few outcomes they serve, usually one to three and rarely more than four. A theme is something a person would notice or care about, such as "Customers can pay by invoice", not a layer of the code, such as "Backend changes" or "Database".

Everything that merely enables a theme folds into that theme: the migration, the refactor it needed, the new tests, the config. Don't give these their own entries, and don't mention them at all unless step 4 calls for it.

Match the outcome to who actually benefits. Internal work like refactoring, CI or tooling has real outcomes for the team, such as faster releases, fewer incidents or less manual work, and should say so plainly. Stretching it into customer value makes the description less credible.

If the themes turn out to be unrelated, mention to the user that the PR might be better split, then continue unless they want to split it.

## 4. Write the title and description

**Title:** state the outcome in under about 70 characters, following the commit style in `git log <remote>/<base>` if it has one (for example `feat: let customers pay by invoice`). The branch's own commits may be work in progress, and on squash-merging repositories the title often becomes the commit subject on the base.

If the `conventional-commit` skill is available, follow it for the prefix, because the squash commit subject can drive automated releases. A type prefix still names the kind of change, so a refactor stays `refactor:` even when its outcome is faster releases. With several outcomes, name what they share or the most important one, rather than joining them with "and". On an existing PR, keep a title that already states the outcome, since someone may have chosen it deliberately, and replace one that doesn't.

**Description:** if the repository has a PR template (`.github/PULL_REQUEST_TEMPLATE.md` or similar), fill in its headings with the same perspective. Otherwise use:

```markdown
## Summary
<One to three sentences: the problem or opportunity, and what is different now.>

## What changes
- **<Outcome>:** <what people can now do or what now happens, and why it matters.>

## Before you merge
- <Anything with consequences beyond the code: breaking behaviour, a required rollout or migration step, a known limitation, a dependency on another team.>

## Test plan
- [x] <What was actually verified, in terms of behaviour.>
- [ ] <What still needs checking.>
```

Scale it to the change. When there's a single theme, the summary already covers it, so drop "What changes". Drop "Before you merge" when nothing belongs there, rather than filling it with "None".

Write for a reader who knows the product but not the codebase. Avoid file names, function names, class names and library names, and translate technical facts into their effect: "search results load in about half the time" rather than "added an index on `orders.customer_id`", if a source supports the figure. Technical detail belongs here only when a reviewer has to act on it, and then it goes under "Before you merge". The exception is when the technical thing is the point of the PR, such as a dependency upgrade or a security fix: name it, and still say what it means for the people affected.

Whenever the description refers to something a reader could open, make it a link, so a reviewer can go straight there instead of looking it up:

- **Websites, docs, dashboards and tickets:** link the full URL from the source that mentioned it. Don't construct or guess a URL, because a dead link costs the reader more than no link.
- **Issues and PRs:** write `#412`, or `owner/repo#412` in another repository, which GitHub turns into links.
- **A place in the code:** use a descriptive markdown link to a permalink pinned to a commit, `<repo-url>/blob/<full-sha>/<path>#L10-L20`, with the repo URL from `gh repo view --json url -q .url`. A link to a branch drifts as the branch moves, so its line numbers stop matching. Use `git rev-parse HEAD`, take line numbers from the file at that commit, and pin to a commit that step 5 will have pushed. If the commit won't be pushed, because the user only wanted the text, describe the place in words instead. These links don't loosen the rule above: code references still appear only when a reviewer has to act on them.

The title doesn't render markdown, so keep links out of it.

Only tick test plan items that actually ran. If nothing was verified, leave the boxes unticked and say so.

**Example of the difference**, for the same branch. Don't write this, which lists the work:

```markdown
Title: feat: add InvoiceService and checkout changes

## Summary
- Add `InvoiceService` and `invoices` table migration
- Update `CheckoutForm.tsx` with new payment option
- Add webhook handler for payment confirmations
- Refactor `PaymentProvider` interface
- Add unit tests
```

Write this, which explains the outcome:

```markdown
Title: feat: let customers pay by invoice

## Summary
Business customers can now pay by invoice at checkout, which the sales team has
named as the main blocker in larger deals (#412).

## Before you merge
- Finance needs to enable invoice terms for each account, following the [rollout guide](https://wiki.example.com/invoice-rollout); until then the option stays hidden.
- Please check the [credit limit for new accounts](https://github.com/acme/shop/blob/4f9c2e1a7b3d8c6e5f0a1b2c3d4e5f6a7b8c9d0e/config/payments.yml#L12-L14), which is a placeholder until finance confirms it.

## Test plan
- [x] Placing an order by invoice, through to confirmed payment
- [ ] Invoice email renders correctly in production
```

## 5. Publish

If there's no open PR and the user only asked for a title or description, show both and stop, without pushing or creating anything.

Push with `git push -u <remote> <branch>` if the branch has no upstream or has local commits the remote doesn't, so that the PR contains what the description covers. If the user only asked to rewrite the title or description of an open PR, ask before pushing those commits. Never force-push here. If the push is rejected, report that and stop.

Pass the body on stdin with `--body-file -`, so no temporary file can end up committed.

- **Open PR:** run `gh pr edit <number> --body-file -`, adding `--title <title>` if step 4 replaced the title, and `--base <base>` if the user named a different base. If the user asked only about the title, leave the body alone, and the same the other way round.
- **No open PR:** run `gh pr create --base <base> --title <title> --body-file -`, adding `--draft` only if the user asked for a draft.

Report the PR URL, and flag any claim you couldn't confirm so the user can correct it.

## Stacked branches

Each layer becomes its own PR, so each one needs its own title and description covering only that layer.

Invoke the `gh-stack` skill if it's available (it may be listed as `gh-stack:gh-stack`), since it has the current command details and recovery paths. If it isn't, the commands below are enough for this workflow.

The numbered steps apply with these changes:

- **Base (step 1):** a layer's base is the layer below it, and the bottom layer's base is `trunk` from `gh stack view --json`. Comparing against the default branch would pull every lower layer into the description. The stack records these bases, so a different base from the user means restructuring the stack: stop and ask.
- **Steps 2 to 4:** do them once per layer, against that layer's base. Pin code links to that layer's tip commit.
- **Publish (step 5):** run `gh stack submit --auto` instead of `git push` and `gh pr create`, adding `--open` unless the user asked for drafts, because `--auto` otherwise creates drafts. It generates its own titles, so then set each layer's title and description with `gh pr edit <number> --title <title> --body-file -`. If the user only asked for titles or descriptions and no PRs exist, show them per layer and stop.
