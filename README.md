# claude-plugins

A Claude Code plugin marketplace. It hosts plugins that install into Claude
Code (`~/.claude/`) and stay live across projects.

This is a different distribution model from
[ag-harness-library](https://github.com/jimbarritt/ag-harness-library), which
ships a flat zip a user unpacks once into an empty project folder. A plugin
here is a live install; a harness is a drop-in artefact.

## Layout

```
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

A plugin needs only a `plugin.json` with a `name` field. Add `skills/`,
`agents/`, `hooks/`, or an MCP server config as needed - none are required.

## Adding a plugin

1. Create `<plugin-name>/.claude-plugin/plugin.json`.
2. Add its content (`skills/`, `agents/`, `hooks/`, ...).
3. Add an entry to `.claude-plugin/marketplace.json`:

```json
{
  "name": "<plugin-name>",
  "source": "./<plugin-name>"
}
```

## Installing from this marketplace

```
/plugin marketplace add jimbarritt/claude-plugins
/plugin install <plugin-name>@jimbarritt-claude-plugins
```
