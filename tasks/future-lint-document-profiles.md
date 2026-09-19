# Future task: document-type profiles for the full lint

No GitHub issue filed yet. Raised by Jim in conversation, while
discussing how the inference tier actually runs (see
[future-inference-tier-rework.md](future-inference-tier-rework.md) —
that discussion is still open, this idea was captured separately so it
does not get lost while it continues).

## Ask

Jim, verbatim: "the command to run a full lint should accept a document
type from a specific list which will be profiles that can be
specialised eg 'rfc' based on our list if doc types. The inference
rules and deterministic rules can be laboured and fikreed by document
type"

Read as: the full-lint command (`/swe:lint-file`, and by extension
`--force-inference`/the deterministic tier generally) should accept a
document-type argument from a fixed list (a "profile"), for example
`rfc`. Each profile can specialise which deterministic and
inference-based rules apply, layering or filtering the base rule set
by document type rather than always applying the same fixed set to
everything. "our list of doc types" and "laboured and fikreed" are
Jim's own typing; the two readings above (layer, filter) are this
session's best-effort guess at "fikreed" and have not been confirmed.

## Status

Idea captured only. Not scoped, not designed, not started. No
document-type list exists yet to build profiles from — "our list of
doc types" refers to something not yet identified in this
conversation. Needs a follow-up conversation with Jim before any design
work: what the doc-type list is, what "layered" vs "filtered" means
for a rule set, whether a profile is plugin-owned
(`rules/plugin-rules.toml`-style) or spec-owned
(`software-english` repo), and whether this only affects
`/swe:lint-file` or the automatic hooks too.
