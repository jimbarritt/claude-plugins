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

Applied the plan as drafted, no deviation on scope.

- `rules/core-rules.toml`: rewrote `vacuous-classification-property`'s
  `description` to name two faults (taxonomy property, count
  signpost), each with a Fault/Fix pair and stated exceptions.
  `trigger_phrases` left unchanged, no TOML comment added above it
  (no other rule in the file carries an inline comment).
- `spec/SPEC.md` §7.6: mirrored the same two-fault structure, heading
  text unchanged so the TOC entry and `#76-...` anchor both stay
  valid.

One correction found while reading, not anticipated going in: the
issue's third example, "Two things changed.", already fires today —
`vocabulary/banned.tsv`'s "Announcing the shape of the text" group
bans `two things`/`three things`/`what follows` as literal phrases.
Only the first two examples were genuinely uncaught. Stated plainly in
the closing comment rather than silently absorbed.

Verified against the real linter, not just reasoned about: copied the
edited `rules/core-rules.toml` into `claude-plugins/swe/data/`
(gitignored; `swe` is not installed as a skill in this session, and
`.fetched-tag` was set to the pinned tag so `fetch-software-english-data.sh`
did not overwrite it), then ran `software_english_lint.py` against
both the pre-edit and post-edit `spec/SPEC.md`. Deterministic tier:
19 errors both before and after, the identical set of findings,
line-shifted only by the inserted text (confirmed by diffing the
sorted finding lines after normalising the two temp filenames) — zero
new deterministic findings from the new prose. Warnings rose 2529 ->
2613, expected (`vocabulary-membership` scales with word count, and is
advisory-only). Also ran `--force-inference` on a scratch file built
from the issue's own three examples plus the three new exceptions
(a partial-set count, a summary count, a quantity) and manually judged
each against the new description: both previously-uncaught examples
now read as a clear count-signpost fault, and all three exceptions
correctly do not. `python3 -I` with `tomllib` confirmed the file still
parses and all 26 rule ids stay unique. Restored `swe/data/` to empty
afterwards (it is gitignored and not meant to persist).

All six `claude-plugins` test suites pass (142 assertions, unchanged).
`claude-plugins`'s own `git status` stayed clean throughout (no code
change needed there per the Reading section above); confirmed with a
second read, not just the Reading section's reasoning, since
`check_line`'s line-at-a-time model can't express a trigger spanning
a sentence head and the list that follows it without new
paragraph-aware code, out of scope for a wording-only issue.

Committed on `software-english`'s `main`:
[`03b3f31`](https://github.com/jimbarritt/software-english/commit/03b3f31),
message ends `closes #9`. Pushed. Released: `release.yml` run
[39392367837](https://github.com/jimbarritt/software-english/actions/runs/39392367837)
with `version: 0.0.18` (newest prior tag v0.0.17), success, tag
[v0.0.18](https://github.com/jimbarritt/software-english/releases/tag/v0.0.18).

Because the change touches `rules/core-rules.toml` (a file `swe`
fetches): bumped `claude-plugins/swe/software-english.json`'s `tag` to
`v0.0.18` and `swe`'s own `plugin.json` version `0.17.8` -> `0.17.9`,
commit
[`59c831f`](https://github.com/jimbarritt/claude-plugins/commit/59c831f)
on `claude-plugins` `main`, pushed, ran `release-plugin.yml` with
`plugin: swe` — run
[39392521316](https://github.com/jimbarritt/claude-plugins/actions/runs/39392521316),
success, tag
[swe-v0.17.9](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.9).
Confirmed with `scripts/check-unshipped.sh` before (flagged version
ahead of tag, as expected pre-release) and after (clean, matches).

Commented on #9 with the correction, the commit, and both release
links; removed `agent:working`, kept `auto-fix-candidate`. Issue
auto-closed by the `closes #9` commit before the comment landed
(`closed_by: jimbarritt`, `state_reason: completed`). No other open
issue, on either tracker, is resolved by this change.

One process note, not a deviation: the first `software-english`
commit was made without the required attribution footer
(`Co-Authored-By`/`Claude-Session`); caught before pushing by reading
the commit back with `git log`, fixed with `git commit --amend` since
it had not been pushed yet.

Single pass, no escalation.
