# claude-plugins

Personal [Claude Code](https://code.claude.com) plugin marketplace.

## Install

```
/plugin marketplace add https://github.com/oskarrn93/claude-plugins.git
/plugin install <plugin>@oskarrn93-plugins
```

## Add a plugin

1. Create `plugins/<plugin>/.claude-plugin/plugin.json` and its components (`skills/`, `commands/`, `agents/`, `hooks/`).
2. Add an entry to `plugins` in `.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "<plugin>",
     "description": "What it does",
     "source": "./plugins/<plugin>"
   }
   ```

3. Run `claude plugin validate .` and push.
