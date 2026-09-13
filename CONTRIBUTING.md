# Contributing a plugin

## Add a plugin to this marketplace

1. Create `<plugin-name>/.claude-plugin/plugin.json`, with at least a
   `name` field.
2. Add the plugin's content: `skills/`, `agents/`, `hooks/`, or an MCP
   server config, as needed.
3. Add an entry to
   [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json):

```json
{
  "name": "<plugin-name>",
  "source": "./<plugin-name>"
}
```

## Repository layout

```text
claude-plugins/
  .claude-plugin/
    marketplace.json    - lists every plugin in this repo
  <plugin-name>/
    .claude-plugin/
      plugin.json        - minimal manifest: { "name": "<plugin-name>" }
    skills/
      <skill-name>/
        SKILL.md
    agents/
    hooks/
```

A plugin needs only a `plugin.json` with a `name` field. `skills/`,
`agents/`, `hooks/`, and an MCP server config are each optional.
