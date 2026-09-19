# Future task: rename the plugin to shorten command names

No GitHub issue filed yet. Raised by Jim in conversation.

## Ask

Jim, verbatim: in the list of commands it shows up long form like
`software-English-lint:swe-feedback` — this is noisy. Rename the plugin
to `swe` and drop `swe` from the individual command names.

## Why

A plugin command's full name is `<plugin-name>:<command-name>`. With the
plugin named `software-english-lint` and each command already prefixed
`swe-` (`swe-feedback`, `swe-send-feedback`, `swe-lint-file`), the
picker shows `software-english-lint:swe-feedback` — the `swe`/
`software-english` label appears twice.

Renaming the plugin to `swe` and dropping the `swe-` prefix from each
command gives `swe:feedback`, `swe:send-feedback`, `swe:lint-file`
instead.

## Naming mechanics (confirmed by research, not yet applied)

- The `<plugin-name>:` prefix comes from `plugin.json`'s `"name"` field,
  not the plugin's directory name. Renaming the field is what changes
  the prefix; the directory does not have to move for that alone.
  Doing it anyway is a separate, cosmetic call — see below.
- For a skill-based command, the part after the colon comes from the
  skill's directory name under `skills/` (e.g. `skills/swe-feedback/`
  -> command `swe-feedback`), not from the `name:` frontmatter field
  inside `SKILL.md`. They do not have to match, but should, for
  anyone reading the file.
- `marketplace.json`'s own `"name"` field for the entry is independent
  — just a catalogue index key. Its `"source"` path does need to point
  at wherever the plugin directory actually lives.
- Renaming an already-installed plugin is a breaking change for anyone
  with it installed: they see the old namespace until they run
  `/plugin update` (or reinstall). Worth a version bump and a note in
  the commit/README about needing to update.

## Scope

- `.claude-plugin/marketplace.json`: entry `"name"` (optional, for
  consistency) and `"source"` path.
- `software-english-lint/.claude-plugin/plugin.json`: `"name"` ->
  `"swe"`. Version bump, since this breaks existing installs.
- Directory rename `software-english-lint/` -> `swe/`: not required by
  the mechanics above, but matches this repo's own convention
  (`<plugin-name>/` per the top-level `CLAUDE.md`) — do it, and update
  `marketplace.json`'s `source` to match.
- Each `skills/swe-*/` directory: rename to drop the `swe-` prefix
  (`swe-feedback` -> `feedback`, `swe-send-feedback` -> `send-feedback`,
  `swe-lint-file` -> `lint-file`), and update each `SKILL.md`'s own
  `name:` frontmatter to match.
- Every place a command is referenced by its current long name:
  `README.md`, `docs/agent-guide.md`, and each `SKILL.md`'s own
  cross-references (e.g. `swe-feedback` mentions `/swe-send-feedback`
  and vice versa) — update to `/swe:feedback`, `/swe:send-feedback`,
  `/swe:lint-file`. Also the install instructions in `README.md`
  (`/plugin install software-english-lint@...` ->
  `/plugin install swe@...`).
- Run both existing test suites afterwards
  (`tests/lint_fail_open_test.sh`, `tests/hooks_test.sh`) to catch any
  hardcoded path assumption the directory rename breaks.

## Status

Next up — Jim has picked this to go first, ahead of
`future-inference-tier-rework.md`. Not started yet: about to begin in a
fresh session after this one clears.
