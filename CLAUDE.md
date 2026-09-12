# claude-plugins

This repo is a Claude Code plugin marketplace. It hosts plugins a user installs
into Claude Code (`~/.claude/`) with `/plugin install`. Content stays live
across projects.

This differs from a harness repo (e.g. `ag-harness-library`), which ships a
flat zip unpacked once into an empty project folder. Do not confuse the two
models. A plugin here is a live install; a harness is a drop-in artefact.

## Structure

```text
claude-plugins/
  .claude-plugin/
    marketplace.json      - lists every plugin in this repo
  <plugin-name>/
    .claude-plugin/
      plugin.json          - minimal manifest: { "name": "<plugin-name>" }
    skills/<skill-name>/SKILL.md
    agents/
    hooks/
```

- A marketplace entry must point at a plugin directory. It cannot point
  directly at a skill.
- A plugin needs only a `plugin.json` with a `name` field. Add `skills/`,
  `agents/`, `hooks/`, or an MCP server config only as needed.
- A single-skill plugin can place `SKILL.md` at the plugin root instead of
  under `skills/<name>/`.
- One marketplace repo can mix plugin types: some entries skills-only, others
  full plugins with commands, agents, and hooks.

## Adding a plugin

1. Create `<plugin-name>/.claude-plugin/plugin.json`.
2. Add its content.
3. Add an entry to [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json):
   ```json
   { "name": "<plugin-name>", "source": "./<plugin-name>" }
   ```

## Conventions

- **Language:** British English throughout - code, comments, docs.
- **No anthropomorphic language.** State the mechanism, not an intent or
  feeling, for any system or component.
- **Prose:** state facts, no editorial commentary.
- **Simplified Technical English (STE)** applies to all prose output in this
  repo, per the user's global instructions.
