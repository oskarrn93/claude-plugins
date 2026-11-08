# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Personal Claude Code plugin marketplace (`oskarrn93-plugins`). It contains only JSON manifests and plugin components; there is no build step or test suite.

## Commands

```
claude plugin validate .
```

Run this after any change to a manifest or plugin component.

## Structure

- `.claude-plugin/marketplace.json` is the registry. A plugin under `plugins/<plugin>/` can't be installed until it has an entry here with `source: ./plugins/<plugin>`.
- Each plugin has its own `plugins/<plugin>/.claude-plugin/plugin.json`, with components (`skills/`, `commands/`, `agents/`, `hooks/`) alongside `.claude-plugin/`.
- A plugin's `name` and `description` appear in both `marketplace.json` and its `plugin.json`, so change them together. Users install with `/plugin install <plugin>@oskarrn93-plugins`, so renaming a plugin changes its install command.

## Hooks

Hooks in `plugins/golang/hooks/hooks.json` are inline shell one-liners that receive the event JSON on stdin and parse it with `jq`. They rely on these behaviors:

- Exit code 2 from the `Stop` hook sends stderr back to Claude, which makes it fix the lint errors before stopping.
- The `Stop` hook exits early when `stop_hook_active` is true, which prevents an endless lint-and-retry loop.
- The `Stop` hook exits 0 when `golangci-lint` is missing or no `.go` files have changed in git, so it doesn't block projects where it doesn't apply.
- The `PostToolUse` formatter always exits 0, so a formatting failure never blocks an edit.
