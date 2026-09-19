# Future task: a Software English output style for the plugin

No GitHub issue filed yet. Not started — queued after issue #2, and after
`future-stop-reply-check.md`, which this replaces or complements. Jim is
keen to start this as soon as issue #2 lands: "this sounds like exactly
the feature our plugin has been waiting for."

## What an output style is

Researched from [Output styles](https://code.claude.com/docs/en/output-styles),
Claude Code v2.1.269 (11 September 2026 changelog entry, which added
`/output-style [name]` for listing and switching, including over Remote
Control and in cloud/headless sessions).

An output style is a Markdown file (frontmatter plus instructions)
appended to the system prompt. It changes how Claude responds, not what
it knows. Relevant frontmatter:

- `keep-coding-instructions: true` — keeps Claude Code's built-in
  software-engineering behaviour, adds the style's instructions on top.
- `force-for-plugin: true` — **plugin output styles only.** Applies the
  style automatically whenever the plugin is enabled, with no user
  action, overriding the user's own `outputStyle` setting. If more than
  one enabled plugin sets this, Claude Code uses whichever loaded first.

A plugin ships one in an `output-styles/` directory at its root
(`software-english-lint/output-styles/`, alongside the existing
`skills/`, `hooks/`, `rules/`).

## Why this matters for software-english-lint

This is a second lever on the same problem `future-stop-reply-check.md`
raised: today Software English is enforced reactively, by the Stop hook
blocking a violating reply and making Claude retry the whole thing. An
output style with `force-for-plugin: true` would instead put the spec's
rules directly in the system prompt the moment the plugin is enabled —
Claude writes in-spec from the first token, rather than being caught and
corrected after the fact.

This does not necessarily replace the Stop hook (deterministic checks
still catch what the model misses), but it could sharply cut how often
the block-and-retry loop fires, which is exactly what Jim's `future-
stop-reply-check.md` concern was about.

## Open questions (not yet asked)

- Does this replace the Stop hook's reply check, sit alongside it as a
  first line of defence, or fold the two tasks into one?
- `keep-coding-instructions: true` presumably yes, since Claude is still
  doing software engineering — confirm.
- What goes in the style's instructions: a condensed version of the
  Software English rules, or a pointer to fetch/read the spec, given the
  existing rule data already lives in `data/` (fetched, gitignored) and
  `rules/plugin-rules.toml`?
- Interaction with `force-for-plugin` and multiple plugins: does Jim run
  other plugins that also force a style, and if so which should win?

## Status

Not scoped. Jim wants to start this as soon as issue #2's config work is
done — see `STATE.md` for priority ordering against the other two future
tasks.

## Next step

Once issue #2 ships: read `hooks/stop-check.sh`, `docs/agent-guide.md`'s
rule-tier section, and `rules/plugin-rules.toml` again with this in mind,
then bring a proposal back to Jim, one question at a time as usual.
