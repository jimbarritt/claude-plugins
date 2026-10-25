# claude-plugins#19: located candidates for no-unanchored-reference and no-unstated-presupposition

[Issue #19](https://github.com/jimbarritt/claude-plugins/issues/19), opened
by jimbarritt-pleo.

## The ask, verbatim

> Rules: no-unanchored-reference (SPEC §7.5), no-unstated-presupposition (SPEC §7.19)
> Verdict: false negative
>
> A document whose opening sentence was a verbless colon list of definite noun
> phrases, none introduced earlier, was recorded clean by /swe:lint-file. Shape:
>
>   "How orders are routed: the two queues, the three tiers, and the fields each
>   one sets."
>
> Both rules printed as inference pending with no located candidate, so on a
> long file the model pass had no pointer to the line. Other rules in the same
> run printed candidates elsewhere in the file.
>
> Proposed fix: emit located candidates by a lookup over the document's own
> tokens.
>
> - For each definite noun phrase ("the" + optional cardinal or number word +
>   head noun), check whether the head noun occurs earlier in the file, title
>   and headings included.
> - Where it does not, print
>   `candidate at line N: definite phrase "<phrase>" whose head noun first occurs here`.
> - Apply the same lookup to no-unstated-presupposition, where a cardinal is
>   already part of the trigger.
>
> This stays a candidate, not a finding: a synonym, the title, a link or a table
> can anchor a noun, so the model makes the decision.
>
> Optional high-precision check: a definite phrase in the first paragraph whose
> head noun first appears inside that phrase is an error the commit hook can
> block on.

## Reading

Both named rules are catalogue entries in `software-english`
(`rules/core-rules.toml`), not code in `claude-plugins`; the pin in
`swe/software-english.json` stays at `v0.0.26` throughout, since neither rule's
`check` value or trigger wording needs to change. The asked-for mechanism is
the same located-candidate pattern shipped for
[claude-plugins#18](https://github.com/jimbarritt/claude-plugins/issues/18)
(see
[tasks/issue-18-register-rule-candidate-detectors.md](issue-18-register-rule-candidate-detectors.md)):
`find_register_candidates()` in `swe/scripts/software_english_lint.py` prints
`candidate at line N: ...` lines inside the `===INFERENCE_ADVISED===` block,
at line 0, capped at 20 per rule per source, never entered into `findings` —
`error_total`, `--count`, and the exit code stay unaffected.

## The plan

From an Opus Plan subagent, which read the issue, `software_english_lint.py`,
the #18 task file, `rules/core-rules.toml`'s entries for both rules
(§7.5/§7.19), and `register_candidates_test.sh`, and prototyped the detector
against real prose in both repos before proposing thresholds.

**Code (`swe/scripts/software_english_lint.py` only; no `software-english`
change)**

- New constants beside the existing `CADENCE_*`/`PAIR_*` ones: a
  `DEFINITE_TOKEN` tokeniser (keeps hyphenated compounds and numbers as single
  tokens, so `two-phase` and `30-second` never read as cardinals), a
  `CARDINAL_WORDS` set (`two`..`twelve`, `twenty`, `both`; `one` excluded,
  since "the one that" is not a count), a `CARDINAL_NUMERAL` regex bounded to
  2-99 (excludes `the 404 response`, `the 2009 edition`), a `QUANTITY_HEADS`
  unit set (seconds, bytes, percent, and similar — a numeral cardinal over a
  unit head is a quantity, not a presupposition), and a short
  `GENERIC_DEFINITE_HEADS` stop set (`same`, `other`, `rest`, `way`, `case`,
  and similar heads that never need an antecedent), tuned from a corpus sweep
  the same way #18 tuned `COMMON_VERBS`.
- `definite_segments()`: splits `prose_lines()`'s unfiltered output into
  phrase-bounded segments (a paragraph, heading, bullet, or table row each
  start a new segment; a wrapped line inside one paragraph joins into the
  same segment). Works on `numbered_lines` directly rather than
  `register_blocks()`, since a heading's own text is both a source of earlier
  nouns and a place a candidate can fire.
- `find_definite_first_mentions()`: one forward pass building a `seen` set of
  `lemma_candidates()` for every token already read (title and headings
  included, per the ask); for each `the`/`these`/`those`/`both` + optional
  modifiers + head noun, reports a candidate when the head isn't in `seen`.
  Skips a phrase immediately followed by `:` or `(` (same-sentence
  enumeration — `the three routes: read, write, and delete` doesn't
  presuppose). Returns results already in document order, so an opening
  sentence is always within the first-20 cap.
- Wired into `find_register_candidates()`: partitions results by
  `has_cardinal` — a cardinal phrase reports under
  `no-unstated-presupposition` only (never also `no-unanchored-reference`,
  matching the catalogue's own stated precedence), everything else under
  `no-unanchored-reference`. Both ids added to `register_rule_ids` in
  `main()`.
- Detail text: `definite phrase "<phrase>" whose head noun first occurs here;
  judge whether an earlier sentence, the title, a link or a table names its
  referent` (unanchored), and the equivalent with `, with a count; judge
  whether an earlier sentence states that count` (presupposition).

**Not building:** the issue's "optional high-precision" blocking check. It
would break the #18 invariant that a candidate never enters `findings`, needs
a new deterministic `check` value and severity in `software-english` (a
separate spec change, tag, and pin bump), and the lookup can't see the
anchors the rule text already names as sufficient (a synonym, the title, a
link, a table) — the prototype's first-paragraph hits on this repo's own real
prose were mostly legitimate. Left for a follow-up issue once the candidates
have run on real use.

**Tests:** new `swe/tests/definite_phrase_candidates_test.sh` (the issue's
worked example as a true positive for both rules; true negatives for
title/heading/earlier-sentence/link/list/table anchoring, same-sentence
enumeration, a quantity, a name, a generic head, code/blockquote exclusion,
the precedence between the two rules, and the 20-cap). Existing
`register_candidates_test.sh` needs two edits since its fixtures now also
produce definite-phrase candidates: its real-file sweep assertion narrows to
the #18 rule ids only, and its "1 located candidate(s)" assertion becomes a
pattern match rather than an exact count. All seven existing suites rerun
unchanged against the fetched `v0.0.26` pin.

**Version:** `swe` `0.19.0` -> `0.20.0` (minor, new detector output, same
precedent as #18's `0.17.12` -> `0.18.0`).

**Docs:** the module docstring, `--advise-inference` help text,
`agent-guide.md` (detector count and a new "known limits" bullet: no synonym
or title-semantics anchoring, no code-block/blockquote anchoring, the
completed-act participle marker not detected, code-comment sources still get
candidates), and `lint-file/SKILL.md`'s example list.

## Outcome

Shipped, single pass, no escalation. Implemented largely as planned, with
one deviation from the brief, corpus-evidenced: bare `both` is excluded from
starting a phrase unless immediately followed by `the`. The literal
algorithm let a bare `both` absorb a following past-tense verb as a
"modifier" or head ("both existed here", "both match", "both enforced by
..." — all real sentences in this repo's and `software-english`'s own prose,
all correlative/pronoun uses, none a true determiner); with no verb lexicon
passed into the new detector (by design, only `connectives`/`qualities`),
there is no clean lexical way to tell these apart from "both options", so
`both` only starts a phrase as `both the <head>`. Two minor residual noise
cases accepted rather than special-cased, since there is no mechanism in a
no-POS-tagger design to fix them cleanly: a compound-noun head reads as its
first word ("the retry queue" -> head "retry", not "queue"), and one
elliptical "the two" picked up a following adverb as its head in the real
corpus sweep.

`find_definite_first_mentions()` makes one forward pass over
`definite_segments()` (phrase-bounded segments of `prose_lines()`'s
unfiltered output, split on a blank line, an hr, a heading, a table row, a
bullet, or a gap), tracking every token's lemma in one `seen` set across the
whole document (title and headings included). A phrase starting
`the`/`these`/`those`/`both the`, with an optional cardinal and up to two
adjective-shaped modifiers, is a candidate when its head noun hasn't
occurred earlier: with a cardinal, routed to `no-unstated-presupposition`;
otherwise to `no-unanchored-reference`, matching the catalogue's own stated
precedence between the two. Wired into the existing #18
`find_register_candidates()`/`===INFERENCE_ADVISED===` mechanism — same
`candidate at line N` format, same 20-per-rule cap, same never-a-finding
invariants.

New `swe/tests/definite_phrase_candidates_test.sh` (35 assertions, all
pass). `register_candidates_test.sh` needed two edits since both new rules
now legitimately fire on real prose by design (unlike #18's narrow
structural patterns): its true-negative sweep narrowed to the #18 rule ids
only, and its exact "1 located candidate(s)" text assertion relaxed to a
pattern (34 assertions, all pass, re-verified independently by this
session). All seven other existing suites rerun unchanged against
`SWE_SRC=/home/user/software-english` and pass (176 assertions total,
re-verified independently). No `software-english` change: both rules'
`check`/`severity`/precedence text already covered this signal, as
anticipated. The issue's own "optional high-precision" blocking check was
deliberately not built (see the plan above).

Corpus sweep (rough per-file candidate counts, unanchored/presupposition):
this repo's `README.md` 4/0, `CLAUDE.md` 12/1, `agent-guide.md` 21/1 (hit
the 20-cap), `lint-file/SKILL.md` 13/0, the output style 12/0;
`software-english`'s `README.md` 4/0, `COLOPHON.md` 14/1, `SPEC.md` 21/4
(hit the cap); all 15 `templates/` files 2-21 unanchored each
(`pull-request.md` hit the cap), 0-1 presupposition each. ~20 candidates
spot-checked by eye across files all read as genuinely plausible signals.

Version bumped `0.19.0` -> `0.20.0` (minor, new detector output, same
precedent as #18). Shipped on `main` at
[`cf3f6ca`](https://github.com/jimbarritt/claude-plugins/commit/cf3f6cad9fced264db2133db81f98c7b12784ddb),
which closed the issue automatically (`closes #19`), released as
[`swe-v0.20.0`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.20.0).
Commented on the issue with the summary; `agent:working` label removed,
`auto-fix-candidate` kept. `scripts/check-unshipped.sh` clean.
`claude-plugins`#20 and `software-english`#21 (both filed the same day, a
few minutes after #19, by the same author) left unclaimed — one issue per
run.
