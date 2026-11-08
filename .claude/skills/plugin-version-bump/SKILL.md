---
name: plugin-version-bump
description: Work out which plugins in this marketplace need a version bump for the current branch or PR, and whether each should be patch, minor or major. Use whenever the user asks if a bump is needed, what version a plugin should go to, or why the version check failed in CI, and before opening or finishing a PR that touches plugins/ or shared/, even if they don't mention versions.
---

# Plugin version bump

Consumers stay on their cached copy of a plugin until its `version` in `plugins/<plugin>/.claude-plugin/plugin.json` changes. A missed bump means they silently never get the change. The size of the bump tells them how carefully to read what changed.

## 1. Find the base

Use the PR's base branch if there is one (`gh pr view --json baseRefName`), otherwise `main`. Run `git fetch origin <base>` and compare against `origin/<base>`, because a stale local `main` gives wrong answers.

## 2. Find which plugins need a bump

Run `scripts/check-plugin-versions.sh origin/<base>`. It is what CI runs, so its answer on committed work is final: every plugin it names needs a bump, and any plugin it doesn't name is either unchanged or already bumped.

The script only sees commits. If `git status` shows uncommitted changes under `plugins/` or `shared/`, work those out by hand and add them to the result:

- A change under `plugins/<plugin>/` affects that plugin.
- A change under `shared/` affects every plugin with a symlink to the changed file. List the links with `find plugins -type l -exec ls -l {} +`. A file in `shared/` that nothing links to affects no plugin.

These don't need a bump, because they never reach consumers: `scripts/`, `.github/`, `.claude/`, `README.md`, `CLAUDE.md`, and changes to the `marketplace.json` entry alone. `gh-stack` is upstream and has no version here. If a plugin's `plugin.json` has no `version` on the base branch, the PR is introducing versioning, so whatever version it sets is fine.

## 3. Choose the level

Read the actual diff for each affected plugin (`git diff origin/<base> -- plugins/<plugin> <linked shared files>`). Judge by what a consumer experiences, not by how many lines moved. If a plugin has several changes, the highest level wins.

| Level | The change | Examples |
|-------|------------|----------|
| major | Something consumers invoke or rely on is gone or works differently | Removing or renaming a skill, command, agent or plugin hook; a skill that now produces a different kind of result; a hook that newly blocks work it used to allow; a new required external tool |
| minor | Consumers gain something, and existing use keeps working | A new skill, command, agent or hook; a new check or workflow step in an existing skill |
| patch | Same capabilities, working better | Typos and rewording, sharper descriptions for triggering, clearer instructions, fixing a broken hook or skill |

When a change sits between two levels, pick the higher one and say why in a clause. Over-signalling costs a consumer a moment's reading; under-signalling can surprise them.

## 4. Compute the new version

Apply the level to the version on the **base** branch, not the one on this branch. A PR is one release, so a branch that has already gone from 1.0.0 to 1.0.1 and then adds a skill should end at 1.1.0, not 1.1.1 or 1.2.0. If the branch's version already matches the target, it needs nothing. If it's lower than the target, say so even though the script passes, since the script only checks that the version went up.

Minor resets patch, and major resets minor and patch: 1.4.2 goes to 1.5.0 or 2.0.0.

In a stacked PR, the base is the PR directly below, so each layer bumps past its parent and merges as its own release. Don't save the bump for the top PR: lower layers would fail CI and ship nothing. If a parent's version changes during a rebase, re-apply this layer's level to the parent's new version. The script won't catch a stale version that's still higher than the parent.

## 5. Report

Give one row per affected plugin, then stop unless asked to apply:

```
| Plugin     | Current | Base  | Needed | Level | Why                         |
|------------|---------|-------|--------|-------|-----------------------------|
| golang     | 1.0.0   | 1.0.0 | 1.1.0  | minor | adds a new review check     |
| typescript | 1.0.1   | 1.0.0 | —      | patch | already bumped; typo fix    |
```

If nothing needs a bump, say that in one line and give the reason, such as "only CI changed".

If the user asked you to make the bump, edit only the `version` field in each `plugin.json`. Leave `marketplace.json` alone: setting a version in both makes `claude plugin validate` warn. Then run `claude plugin validate .`. Commit before re-running the script, as it won't see the edit until then.
