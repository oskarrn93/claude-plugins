# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Personal Claude Code plugin marketplace (`oskarrn93-plugins`). It contains only JSON manifests and plugin components; there is no build step or test suite.

## Commands

```
claude plugin validate .
```

Run this after any change to a manifest or plugin component.

## Structure

- `.claude-plugin/marketplace.json` is the registry. A plugin under `plugins/<plugin>/` can't be installed until it has an entry here with `source: ./plugins/<plugin>`. `gh-stack` is the exception: its entry points at the upstream `github/gh-stack` repo with `strict: false`, because that repo ships the skill but no plugin manifest.
- Each plugin has its own `plugins/<plugin>/.claude-plugin/plugin.json`, with components (`skills/`, `commands/`, `agents/`, `hooks/`) alongside `.claude-plugin/`.
- A plugin's `name` and `description` appear in both `marketplace.json` and its `plugin.json`, so change them together. Users install with `/plugin install <plugin>@oskarrn93-plugins`, so renaming a plugin changes its install command.
- `shared/` holds content used by more than one plugin. Plugins install separately, so a skill can't reach it with `../`. Symlink it into the plugin instead: installing from the marketplace replaces the link with a copy of the file.
- `shared/review/workflow.md` is the single source of truth for language-independent review process and best practices. Each `plugins/<language>/skills/review/references/review-workflow.md` is a symlink to it, and each language's `SKILL.md` adds only language-specific content under the same headings. Put a check in the shared file if it applies to every language.

## Skills

Invoke `/skill-creator:skill-creator` before creating, modifying, reviewing, or auditing a skill, including its description, its `references/`, and `shared/review/workflow.md`. Use it rather than editing or judging a skill by hand, and in preference to `plugin-dev:skill-development` or `plugin-dev:skill-reviewer`. The plugin is enabled in `.claude/settings.json`. This applies to work on a skill itself, not to running one: using a `review` skill to review code doesn't need it.

Keep skill-creator's `<skill-name>-workspace/` directories outside `plugins/`, even though it defaults to a sibling of the skill directory. Anything under a plugin ships to users on install.

## Hooks

Hooks in `plugins/golang/hooks/hooks.json` are inline shell one-liners that receive the event JSON on stdin and parse it with `jq`. They rely on these behaviors:

- Exit code 2 from the `Stop` hook sends stderr back to Claude, which makes it fix the lint errors before stopping.
- The `Stop` hook exits early when `stop_hook_active` is true, which prevents an endless lint-and-retry loop.
- The `Stop` hook exits 0 when `golangci-lint` is missing or no `.go` files have changed in git, so it doesn't block projects where it doesn't apply.
- The `PostToolUse` formatter always exits 0, so a formatting failure never blocks an edit.
