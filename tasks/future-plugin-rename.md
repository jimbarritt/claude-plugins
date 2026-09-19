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

## Scope (not yet confirmed — check when this is picked up)

- `.claude-plugin/marketplace.json`: `name` and `source` path.
- `software-english-lint/.claude-plugin/plugin.json`: `name` (may need
  the directory itself renamed too, or just the manifest field — check
  which one drives the `<plugin-name>:` prefix).
- Directory rename: `software-english-lint/` -> `swe/`, or keep the
  directory and only change `plugin.json`'s `name` field — check which
  is idiomatic before doing either.
- Each `skills/swe-*/SKILL.md`: directory name and frontmatter `name`
  field, dropping the `swe-` prefix (`swe-feedback` -> `feedback`,
  `swe-send-feedback` -> `send-feedback`, `swe-lint-file` -> `lint-file`).
- Every place a command is referenced by its current long name:
  `README.md`, `docs/agent-guide.md`, and each `SKILL.md`'s own
  cross-references (e.g. `swe-feedback` mentions `/swe-send-feedback`
  and vice versa).
- Whether renaming breaks anyone's existing muscle memory or scripts
  that call `/swe-feedback` etc. by name — ask Jim if this matters
  before shipping, since it is a breaking rename for an installed
  plugin.

## Status

Not started. Recorded for later, not this session.
