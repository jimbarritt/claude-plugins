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

## Related repo

Work in this repo sometimes needs a change in
[`jimbarritt/software-english`](https://github.com/jimbarritt/software-english),
the upstream spec this repo's linting and prose conventions follow. Treat
`claude-plugins` as the primary repo and `software-english` as a secondary
repo to change when a task needs a spec change there.

## Cross-session planning

The `planning` branch is a detached branch (no shared history with `main`)
used to track tasks and status across sessions. It holds `STATE.md` (current
status) and `tasks/` (one file per workstream).

When asked to "update the plan", use the `planning` branch. Do not switch
the main working copy to it with `git checkout planning`. Instead, use a
separate git worktree, e.g.:

```sh
git worktree add /home/user/claude-plugins-planning planning
cd /home/user/claude-plugins-planning
```

If the worktree already exists, `cd` into it directly rather than adding it
again. Update `STATE.md` and the relevant task file there, not files on
`main`.

Outside of planning documents, work directly on `main`. Do not use a
feature branch for ordinary changes to this repo.

## Conventions

- **Language:** British English throughout - code, comments, docs.
- **No anthropomorphic language.** State the mechanism, not an intent or
  feeling, for any system or component.
- **Prose:** state facts, no editorial commentary.
- **Simplified Technical English (STE)** applies to all prose output in this
  repo, per the user's global instructions.
