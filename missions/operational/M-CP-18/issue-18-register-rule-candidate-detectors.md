# claude-plugins#18: register-rule candidate detectors

[Issue #18](https://github.com/jimbarritt/claude-plugins/issues/18), opened
by jimbarritt.

## The ask, verbatim

> Software English SPEC §8 (software-english#8, shipped in v0.0.17) adds two
> `model-judgement` rules to `rules/core-rules.toml`: `no-cadence-device` and
> `no-mechanical-repetition`. Two of the patterns they cover have cheap
> structural signals the deterministic pass in
> `swe/scripts/software_english_lint.py` could locate, without deciding the
> fault itself.
>
> The first is a sentence with no verb immediately after a sentence of
> about 15 or more words. With the linter limited to the Python standard
> library (no part-of-speech tagger), this means a closed verb/auxiliary
> list (for example `vocabulary/operations.tsv` plus common auxiliaries)
> rather than real tagging.
>
> The second is three or more consecutive markdown lists in which every
> bullet opens with a bold span, plus adjacent sentences with matching
> token-class shape (candidate for the matched-pair half of
> `no-cadence-device`).
>
> Neither signal decides the fault on its own: whether the flagged sentence
> or bullet actually adds no fact still needs judgement. So the asks are
> detectors that attach located candidates to the existing model-judgement
> pass for `no-cadence-device` and `no-mechanical-repetition`, not a new
> deterministic rule or `check` value. The goal is fewer missed findings and
> lower model cost on long documents, the same shape as the existing
> deterministic-tier fixed lists that gate `anthropomorphism-fixed-list` and
> `abstract-location`.
>
> Scope: new code in `swe/scripts/software_english_lint.py`, new tests under
> `swe/tests/`, a `swe` `plugin.json` version bump, and a
> `release-plugin.yml` run. No change needed in `software-english` unless a
> new `check` value in the catalogue schema turns out to be useful alongside
> the located-candidate approach.

## Reading

Two structural signals (a verbless fragment after a long sentence; a run of
three or more bold-lead-in bullet lists) get surfaced as advisory "located
candidate" lines attached to the existing `===INFERENCE_ADVISED===` block,
never as findings: they never enter `findings`, never affect `error_total`
or the exit code, and never gain a real (≥1) line number, since the
published hook contract treats line ≥1 as a real finding. The issue's own
rule text also names a third signal, matched-pair sentences for the other
half of `no-cadence-device`; the plan includes it as explicitly in scope,
not a stretch goal, since the issue's wording names it as one of the two
asks.

## Plan (from an Opus Plan subagent, which read the real linter, the real
pinned `v0.0.20` catalogue and TSVs, the real docs/tests, and prototyped
all three detectors against all 33 real `.md` files in both repos)

### Output shape

Candidate lines live inside the existing block, directly after the
`inference pending` line for the rule they belong to, at line 0 (never a
real line), with the real location named in the text:

```
doc.md:0: [warning] [no-cadence-device] candidate at line 42: verbless sentence "No silent drops." follows a 19-word sentence; judge whether it states a fact that sentence does not.
```

Finding-shaped (survives the `grep -E ":\s*\[(error|warning)\]"` idiom), but
line 0 and the fixed `candidate at line N:` phrase keep them out of
`findings`/exit code and out of the "real finding" contract
`docs/agent-guide.md` already publishes. A cap of 20 candidates per
rule per source, with an "N more omitted" line past the cap. The
`[inference-pending]` summary line gains a trailing
" N located candidate(s) above are not findings." only when N > 0, so it is
byte-identical to today's text when nothing fires (existing
`commit_check_test.sh` glob assertions keep passing).

### New code (`swe/scripts/software_english_lint.py`)

- `register_blocks(numbered_lines)`: groups `prose_lines()`'s unfiltered
  output into paragraph/list/heading/table/hr blocks, since wrapped prose
  spans multiple lines and `check_line()` only sees one line at a time.
- `split_sentences(paragraph)`: joins a paragraph's lines and splits on a
  sentence boundary that requires a capital next letter (`SENTENCE_BREAK`),
  avoiding false splits on "e.g.", "§8.", "claude-plugins#3.". Returns
  `(start_line, sentence_text)` pairs. Does not touch the existing
  line-at-a-time split in `check_line()`/`count_words_sentences()`.
- `load_verb_lexicon()`: `operations.tsv` + a hardcoded `AUXILIARY_VERBS` +
  a hardcoded `COMMON_VERBS` (verbs frequent in this repo's own prose but
  absent from `operations.tsv`: see, state, name, live, know, …). Without
  `COMMON_VERBS`, 18 of 33 real documents false-positive at a 6-word cap;
  with it, 1 (a genuine hit).
- `sentence_has_verb(sentence, verbs)`: a token counts as a verb via
  contraction suffix, an auxiliary lemma, or a lexicon lemma **unless** the
  preceding token is a determiner (`NOUN_DETERMINERS`), so "No retries." and
  "a read" read as nouns.
- `find_cadence_fragments(blocks, verbs)`: same-paragraph adjacent sentence
  pairs where the first is ≥15 words and not a question, the second is
  1-6 words, ends `.`/`!`, and has no verb by the rule above.
- `BOLD_LEAD` regex + list-run tracking: a list "qualifies" at ≥2 bold-led
  top-level bullets; a run of ≥3 qualifying lists (broken only by a
  non-qualifying list, not by paragraphs/headings between them) emits one
  candidate at the run's first bullet line, naming every list's start line.
  Single bold lists (9 of 33 real documents, all templates'
  required-section lists) deliberately do not fire.
- `word_class()`/`find_matched_pairs()`: adjacent 4-12-word sentences in one
  paragraph with an identical D/V/N/Q/O class sequence (via `connectives.tsv`,
  the verb lexicon, `structure.tsv`, `qualities.tsv`), containing a verb,
  neither starting with a quote/paren.
- `find_register_candidates()`: runs the above per source, for whichever of
  the two rule ids are present in the fetched catalogue; respects
  `only_lines` for `--diff --added-only`.
- Wiring: `sources` tuples gain a fourth element (numbered lines + only_lines
  for candidate detection); candidates computed lazily, only when the
  inference block is due; `format_inference_rules()` gains a `candidates`
  parameter. Nothing new ever touches `findings`.
- HTML sources (`--html-file`) get no candidates: text-node adjacency across
  tags is not real prose adjacency.

### Tests

New `swe/tests/register_candidates_test.sh`, following `motion_idiom_test.sh`'s
pattern (real pinned data via `SWE_SRC` or a fetch, `HOME` pointed at a
scratch dir, output captured before grepping under `pipefail`). Covers:
true positives (verbless fragment after a 15+-word sentence, including
wrapped across lines, and the determiner exception), true negatives (a
fragment with a verb, a too-short preceding sentence, an over-length
fragment, a list item/heading/fenced fragment, a question-ending preceding
sentence), the list-run detector (3+ qualifying lists fire once; 2 lists,
a broken run, a single 5-bullet list, wholly-bold bullets, and a fenced run
all stay silent), the matched-pair detector, the "not a finding" invariant
(exit 0, no real-line-numbered output, `--count` unaffected, the summary
suffix present, survives the findings-grep idiom), and a true-negative sweep
of this repo's own real prose files (`README.md`, `agent-guide.md`,
`output-taxonomy.md`, `lint-file/SKILL.md`, the output style, root
`CLAUDE.md`) that must report zero candidates. Existing suites
(`commit_check_test.sh`, `hooks_test.sh`, `motion_idiom_test.sh`,
`inference_eligible_test.sh`, `skill_frontmatter_test.sh`, `lint_fail_open_test.sh`)
must keep passing unchanged.

### Judgement calls taken (full table and reasoning in the subagent's
report; summarised here)

- Candidate line number is 0, with the location named in the text, to
  respect the published "real finding = line ≥1" contract.
- The 15-word preceding-sentence threshold is a new constant, not
  `sentence-length.max_words` (20): the catalogue rule's own example
  sentence is 19 words, so reusing the existing constant would miss it.
- The fragment word cap is 6 (the rule's own examples are 3 words); verb
  lexicon needs the extra `COMMON_VERBS` set beyond the issue's own
  suggestion (`operations.tsv` + auxiliaries) or real prose floods with
  false positives — flagged in the plan as tuned on the available corpus,
  worth rechecking against one more real document set before shipping.
- Adjacency is same-paragraph only for v1; a fragment that is its own
  paragraph is out of scope (cannot be told apart from a caption/label from
  line structure alone) and named as a known limit.
- "Consecutive" lists tolerates paragraphs/headings between qualifying
  lists (matches the real machine pattern of heading/intro/bold-list
  repeated), but not a non-qualifying list in between.
- The matched-pair detector (the issue's own second named ask) is in scope
  for v1, not deferred.
- No new `software-english` catalogue `check` value needed.

### Docs to update

`agent-guide.md` (example block, a new explanatory paragraph, the regex
split list, the CLI section, four new known-limits bullets), `lint-file/SKILL.md`
(Steps 3, 4, 6), and the three hooks' advisory text
(`bash-check.sh`, `mcp-send-check.sh`, `artifact-check.sh`), plus the module
docstring and the two argparse `--help` strings.

### Version

`swe/.claude-plugin/plugin.json`: `0.17.12` -> `0.18.0` (minor bump,
matching prior feature-sized changes such as #17's 0.16.4 -> 0.17.0). No
`software-english` change (the pin stays at `v0.0.20`, which already has
both rules). No other version file touched, per CLAUDE.md.

## Status

Done. Single pass, no escalation.

Implemented exactly as planned, with the matched-pair detector kept in
scope (not deferred). `register_blocks()`, `split_sentences()`,
`sentence_has_verb()`, `find_cadence_fragments()`, `find_matched_pairs()`,
`find_bold_list_runs()`, `find_register_candidates()`, and
`load_verb_lexicon()`/`load_tsv_words()` added to
`swe/scripts/software_english_lint.py`; `format_inference_rules()` and
`main()`'s `sources` pipeline carry the plumbing. Verified directly
against the real linter and the pinned `v0.0.20` data throughout, not just
reasoned about: the catalogue's own `no-cadence-device` worked example
("No silent drops.") fires exactly as the plan predicted, including when
wrapped across lines; the determiner exception ("No retries.") fires; the
matched-pair example ("It never reads a file twice.") fires; the
bold-list-run detector fires on a real 3-list run and stays silent on 2
lists, a broken run, a single 5-bullet list (the shape this repo's own
templates and `CLAUDE.md` use for a required-sections list), wholly-bold
bullets, and the same content inside a fenced code block; a true-negative
sweep of this repo's own real prose (`README.md`, `agent-guide.md`,
`lint-file/SKILL.md`, the output style, root `CLAUDE.md`) reports zero
candidates. New `swe/tests/register_candidates_test.sh`, 34 assertions, all
pass; all six existing suites pass unchanged (142 assertions, 176 total).
`--diff --added-only` on the two edited docs reports zero
errors/warnings. `agent-guide.md`, `lint-file/SKILL.md`, and the three
hooks' advisory text updated. Version bumped `0.17.12` -> `0.18.0`. Shipped
on `main` at
[`a48875a`](https://github.com/jimbarritt/claude-plugins/commit/a48875a377a2adab6168f5a414bcce2da045d6de),
which closed the issue automatically, released as
[`swe-v0.18.0`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.18.0).
No `software-english` change: the located-candidate approach needed no new
catalogue `check` value, as the issue itself anticipated. No other open
issue resolved by this change.
