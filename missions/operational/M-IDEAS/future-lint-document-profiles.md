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

## A concrete case: the API Design type's fenced content

Raised in the API Design document type conversation
([future-api-design-doc-template.md](future-api-design-doc-template.md)),
2026-09-22, and folded in here at Jim's direction, since it is a
document-type-specific check, the same question this task already
asks.

`software_english_lint.py` skips every fenced or inline code span at
every check (`FENCE`, the `in_fence` skip). Every request/response
example, every message example, and every entity-schema `type`
declaration for that document type sits inside a fenced code block, so
none of it is checked today, whatever `core-rules.toml` says. Three
concrete checks were identified there that no current rule shape
covers:

1. **The literate-notation rule**: `type` only, no `interface`, inside
   a fenced TypeScript block.
2. **The examples-required style rule**: every endpoint or message
   subsection has at least one fenced example under it. A structural
   check (counting code blocks under a heading), not a sentence-level
   one; no current rule shape fits.
3. **Fence well-formedness**: an `http`-tagged block parses as an RFC
   9112 request or response; a `ts`-tagged block is syntactically
   valid `type` declarations. A parser call per fence language, not a
   regex; a different kind of check from every existing rule.

All three need the linter to look inside a specific fence language,
which is new scope, not a new entry in the existing rule shapes. This
is one instance of what a profile might need to express: a rule that
applies only within a document type's own fenced content, in a
language that type defines (`http`, `ts` for API Design; a different
set for another type).
