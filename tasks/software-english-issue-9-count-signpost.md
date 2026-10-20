# software-english#9: a bare count signposting the list below it

[Issue #9](https://github.com/jimbarritt/software-english/issues/9)
("vacuous-classification-property: a bare count announcing the list
below it matches no trigger"), opened by jimbarritt-pleo on
2026-09-29. Claimed by the self-maintaining-repo Routine on 2026-10-20.

## The ask, verbatim

> Neither tier catches a bare cardinality announcement introducing the
> list that immediately follows it:
>
> - "Three costs follow from that."
> - "Three routes drop an entry:"
> - "Two things changed."
>
> The count adds nothing. The reader can see how many items there are,
> because the items are directly below.
>
> The deterministic tier cannot find this today. The inference rule
> description scopes itself to a taxonomy definition, naming only
> trigger phrases of the form "defines N tiers / kinds / categories /
> levels". A plain count announcing the items below it matches no
> listed trigger, so the judging pass lets it through.
>
> This is a high-frequency signposting tic and one of the stated
> reasons for writing the spec.
>
> Two asks:
>
> 1. Widen the trigger set to a numeral or number word at the head of
>    a sentence, immediately preceding the items that enumerate it.
>    This is findable deterministically in markdown: a number word at
>    the head of a sentence followed by a colon, an ordered list, or N
>    sentences.
> 2. Name the fault in the rule description as signposting a count,
>    distinct from the taxonomy-property case the description
>    currently covers.

## Reading

Checked the issue's third example against the real deterministic
tier first: `vocabulary/banned.tsv`'s "Announcing the shape of the
text" group already bans `two things`, `three things`, and `what
follows` as literal phrases, so "Two things changed." already fires
today. Only the first two examples ("Three costs follow from that.",
"Three routes drop an entry:") are genuinely uncaught. The closing
comment on the issue should correct this.

`vacuous-classification-property` is `tier = "inference-based"`,
`check = "model-judgement"`. Its `trigger_phrases` array holds only
literal substrings ("exactly one", "mutually exclusive", and
similar); nothing in `claude-plugins/swe/scripts/software_english_lint.py`
ever reads that array — confirmed by reading the script directly
(`--advise-inference`'s block, built at line ~803, prints only each
rule's `description` field, filtered on `check == "model-judgement"`).
So widening `trigger_phrases` would change nothing a judging model
ever sees; the only field that reaches it is `description`. Ask #1's
trigger ("a number word at the head of a sentence, immediately
preceding the items it enumerates") is also positional, not a literal
substring, so it could not go in `trigger_phrases` as a flat string
even if that field were read.

"Findable deterministically in markdown" describes the shape of the
trigger, not a requirement to add Python code. `claude-plugins#18`
already owns adding located-candidate detectors to the deterministic
tier for two *other* register rules; this issue's ask is scoped to
`software-english` wording (both asks are about the rule's trigger
set and its description). The positional trigger here also spans
multiple lines (a sentence head plus the list that follows), which
`software_english_lint.py`'s current line-at-a-time `check_line` model
cannot express without new paragraph-aware code — out of scope for a
wording-only issue. Decision: no `claude-plugins` change in this
issue; note the gap as a closing-comment pointer toward #18 instead of
filing a third issue.

## Plan

Dispatched an Opus `Plan` subagent with the issue text, the full
`rules/core-rules.toml` entry, `spec/SPEC.md` §7.6 and its neighbours
(§7.5, §7.7, §7.12's two-fault sibling `no-work-breakdown-or-tracker-pointer`
as house style for a rule naming two faults under one id), and
`vocabulary/banned.tsv`. It recommended:

1. Keep the rule id `vacuous-classification-property` (it is
   referenced from `claude-plugins/swe/docs/output-taxonomy.md` and
   cross-referenced from §7.12); do not split it into two ids.
2. Rewrite the `description` to name two faults explicitly: the
   existing **taxonomy property** case, and a new **count signpost**
   case (a sentence starting with a numeral or number word, stating
   only how many items come directly after it — a colon plus a list,
   or the same number of one-item sentences). Each fault gets a
   worked Fault/Fix pair, in the `no-work-breakdown-or-tracker-pointer`
   style. Three explicit exceptions: a count that states a fact beyond
   the item count (a part of a larger set, or a mechanism's bound); a
   count whose items are not directly below it (e.g. a summary the
   body later expands); a number that is a quantity, not an item
   count. A pointer to the existing `banned.tsv` entries for "two
   things"/"three things" so the closing comment on the issue can cite
   it directly.
3. Leave `trigger_phrases` unchanged — it stays the taxonomy-only
   literal set, since the positional count-signpost trigger cannot be
   a literal substring and nothing reads that field regardless. No
   TOML comment added above it: no other rule in the file carries an
   inline comment, so none is added here either, to match the file's
   own convention (only the top-of-file header comment exists).
4. Mirror the same two-fault structure into `spec/SPEC.md` §7.6, same
   heading text (so the TOC entry and the `#76-...` anchor both stay
   unchanged), with matching Fault/Fix examples and the same three
   exceptions as a bulleted list.
5. No `COLOPHON.md` entry required (optional, skipped — the rule id
   and its mechanism are unchanged, only its scope is widened, unlike
   the#2/#13 "hold" ban which needed a rationale record for a judgement
   call).
6. No change to `claude-plugins`'s `swe` code (see Reading, above).

Full literal drafted text (the TOML `description` string and the
SPEC.md §7.6 replacement block) came from the Opus subagent; applied
with the wording below and the checks in Outcome.

## Outcome

(filled in after Step 5 work and Step 6 ship)
