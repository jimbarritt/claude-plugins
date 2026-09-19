# Future task: reconsider the Stop hook's reply check

No GitHub issue filed yet. Spun out of
[issue-2-per-hook-toggle.md](issue-2-per-hook-toggle.md) while discussing
that task's Q5. Not started — issue #2's config work finishes first.

## The concern

Jim, verbatim: less and less sure about the per-reply check. It's a
wasteful loop and fills the chat with duplication just to remove something
like an em dash. There are probably better ways to do this. Parked for
later.

## Context

`stop-check.sh`'s `--reply-file` path runs the deterministic tier over the
whole reply on every turn, blocks the turn on a violation via
`{decision: "block", reason: ...}`, and Claude rewrites the entire reply
to retry. A one-character fix (e.g. an em dash) re-runs and re-prints the
whole reply, which is the duplication Jim is pointing at.

## Status

Not scoped. No design work done yet.

## Next step

Return to this once issue #2 ships. Think about a lighter-weight
correction path for a small, mechanical, deterministic-tier violation
(e.g. an em dash) versus the full block-and-retry loop.

## Related: a forced output style

See [future-swe-output-style.md](future-swe-output-style.md). A plugin
output style with `force-for-plugin: true` could put Software English's
rules directly in the system prompt, cutting how often this block-and-
retry loop fires in the first place. Jim is keen to explore this one
first, right after issue #2.
