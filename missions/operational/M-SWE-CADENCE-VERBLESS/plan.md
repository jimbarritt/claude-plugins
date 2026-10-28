# Plan: claude-plugins#25, `no-cadence-device` reports a sentence with a finite verb as verbless

## 1. The ask (issue #25, verbatim)

Issue title: "no-cadence-device candidate: sentence with a finite verb reported as verbless"

> ## Verdict
>
> False positive, from the `no-cadence-device` candidate locator in
> `software_english_lint.py` (the `--force-inference` candidate lines).
>
> ## Shapes
>
> Two short sentences, each with a finite present-tense verb, each stating
> a fact the sentence before it does not, were reported as verbless.
>
> 1. A short sentence that ends in a pronoun object:
>
>    > The config file sets the retry limit and the timeout for each
>    > client, as two integers read once at startup. Every client reads
>    > them.
>
>    Reported as: verbless sentence "Every client reads them." follows a
>    N-word sentence.
>
> 2. A subject made mostly of code spans:
>
>    > The catalogue lists each shirt once per variant, so a search by
>    > style returns many rows. The fields `colour`, `size`, `sleeve` and
>    > `fabric` tell them apart.
>
>    The locator's text has the code spans blanked out, so the sentence
>    it judges reads "The fields       ,     ,        and        tell
>    them apart." Reported as verbless.
>
> ## Expected
>
> No candidate for either sentence. Each has a finite verb ("reads",
> "tell").
>
> ## Proposed fix
>
> - Treat a code span as a noun phrase, not as blank space, when finding
>   the subject, so the verb after a code-span list is recognised.
> - Recognise a finite verb directly before a pronoun object ("them",
>   "it", "these").
>
> Add fixtures for both shapes, plus a true verbless fragment ("No silent
> drops.") that still reports a candidate.

## 2. Root cause

All paths are in `swe/scripts/software_english_lint.py`.

**What the locator does now**

- `find_cadence_fragments()` (lines 1226-1257) splits each paragraph block with `split_sentences()` (1168-1203).
- It keeps a fragment when all of these hold:
  - the sentence before it has at least `CADENCE_MIN_PRECEDING_WORDS` (15) words;
  - the fragment ends in `.` or `!`;
  - the fragment has 1 to `CADENCE_MAX_FRAGMENT_WORDS` (6) `WORD` matches;
  - `sentence_has_verb()` (1206-1223) returns False.
- `sentence_has_verb()` is a closed-list check. A word counts as a verb only when one of these holds:
  - it is a contraction;
  - it is in `AUXILIARY_VERBS` (658);
  - one of its `lemma_candidates()` (904) is in `load_verb_lexicon()` (849-854), i.e. `operations.tsv` plus `AUXILIARY_VERBS` plus `COMMON_VERBS` (670-677).
- Even then, the word does not count when the word just before it is in `NOUN_DETERMINERS` (682).
- So any finite verb outside that list, about 150 words, reads as "no verb".

**Code-span blanking**

- `strip_noise()` (878-881) replaces each `INLINE_CODE` match (600), and each link target, URL and HTML tag, with spaces of the same length.
- `prose_lines()` (884-901) yields those blanked lines, which flow through `main()` into `find_register_candidates()` and `find_cadence_fragments()`.
- Two results follow:
  - (a) Code spans add nothing to the word count, so a code-span-heavy sentence can wrongly drop under the 6-word cap.
  - (b) The locator has no tokens for the subject at all, so the only evidence left for a verb is the closed lexicon.

**The issue's own sentences do not reproduce on HEAD with the pinned data** (verified in-process against `software-english` vocabulary at pinned tag v0.0.28: `read` is in `operations.tsv`, `tell` is in `COMMON_VERBS`). The defect is real and general: it fires on any verb outside the closed lexicon, e.g. "Every client trusts them.", "Every client ignores it.", "The fields `colour`, `size`, `sleeve` and `fabric` distinguish them." These must stop firing. True fragments ("No silent drops.", "None of them.", "Not for these.", "Only `colour` and `size`.") must keep firing.

**Correction to the issue's own diagnosis:** code spans are indeed treated as blank space, but a lexicon verb directly after the blanks is already recognised (the preceding word "and" is not a determiner). The real failure is the closed verb list, combined with the length gate ignoring code spans — not the subject-recognition path as such.

`swe/docs/agent-guide.md` (~line 702-706) already documents this limitation.

## 3. Implementation plan

### Step 1. A second, code-preserving line stream, only for the cadence locator

Do not change `strip_noise()`'s existing behaviour for other callers (define-before-use, count-list-items, etc. rely on code spans being blanked).

- Add `keep_code=False` to `strip_noise(line, keep_code=False)`: when True, skip the `INLINE_CODE` substitution, still blank `LINK_TARGET`, `URL`, `HTML_TAG`. Every substitution preserves line length, so blanked and code-kept lines stay character-aligned.
- Thread `keep_code` through `prose_lines(text, exemptions, only_lines=None, keep_code=False)`.
- In `main()`, each input path (Markdown file, `--text`, `--reply-file`, `--transcript`) also builds `code_lines = list(prose_lines(text, exemptions, keep_code=True))`.
- Extend `candidate_input` to `(numbered_lines, only_lines, code_lines)`; the comment-file path passes `None` (comment text isn't blanked, so it already has backticks).
- `find_register_candidates(numbered_lines, only_lines, lexicon, rule_ids, code_lines=None)` passes `code_lines` through to `find_cadence_fragments(blocks, verbs, code_lines)`.

### Step 2. Split on blanked text, read code-kept text

- Build `blocks` once, from the blanked lines, so block/paragraph structure is unchanged.
- In `find_cadence_fragments`, when `code_lines` is given, build `code_by_line = dict(code_lines)` and a mirror list per paragraph.
- Add optional `mirror` to `split_sentences(paragraph, mirror=None)`: find sentence boundaries on the blanked text as now (so boundaries never move because of a stray `.`/`?` inside a code span), but return each sentence as the mirror slice at the same offsets, stripped independently.
- Run the preceding-sentence-length and terminal-punctuation checks on the blanked sentence as now; use the code-kept sentence for tokenising, the verb check, and the reported `detail` string (this also fixes the unreadable blanked-text quote in the current false-positive report).

### Step 3. A code span counts as one noun-phrase token

- Add `CADENCE_TOKEN = re.compile(r"`[^`]*`|[A-Za-z][A-Za-z']*")` beside `WORD`.
- In `find_cadence_fragments`, tokenise the fragment with `CADENCE_TOKEN` for the length cap, so a code span counts as one word (issue shape 2 then has 10 tokens and fails the length gate on its own).
- Leave `prev_words` (the preceding-sentence length check) on `WORD` over the blanked text — changing it would shift which sentences qualify as "preceding" at all, which is out of scope here.
- Change `sentence_has_verb()` to tokenise with `CADENCE_TOKEN` too: a code token is opaque (never a verb, auxiliary, or determiner; its contents are never looked up, so "The `read` path." stays verbless).

### Step 4. A word directly before an object pronoun counts as a finite verb

In `sentence_has_verb()`, after the existing checks, a token at index `i >= 1` counts as a verb when:

- the next token, lower-cased, is in `OBJECT_PRONOUNS = {"them", "it", "these", "those", "him", "her", "us", "me", "itself", "themselves"}` (excluding "this"/"that", which are also complementisers — "Not this." must keep firing);
- the token itself is a lowercase alphabetic word, not a code token;
- the token, lower-cased, is not in a new `NON_VERB_BEFORE_OBJECT` set covering common prepositions, conjunctions, negators/quantifiers, focusing adverbs, "worth", and `NOUN_DETERMINERS`.

The `i >= 1` guard requires a subject token first, so this fires on "Every client trusts them." but not "None of them.", "Not for these.", or "Both of them."

**Rejected alternative:** "any lowercase word right after a code-span subject is a verb" — rejected because it would misread "The `retry` limit." as verbed (code spans commonly modify nouns). A code-span subject instead relies on the lexicon, Step 4's pronoun rule, and Step 3's length gate.

### Step 5. Tests — add to `swe/tests/register_candidates_test.sh`

Match the existing file's conventions (`assert`, `has_cand`/`no_cand` helpers, `lint_file` for multi-line fixtures, `$L`, real data via `SWE_SRC`/pinned tag). Code-span fixtures must use single-quoted shell strings (double quotes trigger command substitution on a backtick).

New true-negative cases (must NOT fire `no-cadence-device`):
- issue shape 1 verbatim: `"$S1 Every client reads them."`
- a verb outside the lexicon before a pronoun: `"$S1 Every client trusts them."`, `"...ignores it."`, `"...copies these."`
- issue shape 2 verbatim: `"$S2 $F2"` (the `tell` sentence)
- a code-span subject with a verb outside the lexicon: `"$S2 $F2_UNLISTED"` (`distinguish`)
- the wrapped/multi-line form from the issue, via `lint_file`, asserting no `no-cadence-device` candidate at all

New true-positive cases (must still fire, regression guard):
- `"$S1 No silent drops."` (the issue's own example; already covered at the existing `$L No silent drops.` line — keep it)
- `"$S1 None of them."`, `"$S1 Not for these."` (preposition before a pronoun is not a verb)
- `"$S2 Only \`colour\` and \`size\`."` (code spans count as words, give no verb)
- `"$S2 The \`read\` path."` (contents of a code span are never read as a verb)
- a detail-string assertion that the reported quote contains the actual code-span text (backticks), not blanks

Must stay green: the existing real-prose sweep in the same file; `define_and_count_candidates_test.sh`; `definite_phrase_candidates_test.sh`; `unit_worklist_test.sh` (because of the `candidate_input` tuple shape change); all of `swe/tests/*.sh`, run with `SWE_SRC=/home/user/software-english`.

### Step 6. Docs and release

- Update `swe/docs/agent-guide.md` (~line 702-706, and optionally the no-cadence-device description ~174-176): the closed verb list still exists, but a word directly before an object pronoun now counts, and a code span now counts as one noun-phrase word rather than disappearing.
- Bump `version` in `swe/.claude-plugin/plugin.json` (0.24.2 → 0.24.3).
- Run `scripts/check-unshipped.sh`.
- Commit `closes #25`, push `main`, then run `release-plugin.yml -f plugin=swe`.

### Risks considered

- Sentence-boundary detection stays on the blanked stream, so a `.`/`?` inside a code span can't create a false boundary.
- Block/paragraph structure is built once, from the blanked stream, so it can't diverge between the two tokenisations.
- The matched-pairs locator does not receive the mirror stream and is unaffected.
- Comment files pass `code_lines=None`; the mirror falls back to the raw (unblanked) line, which already has backticks.

### Critical files

- `swe/scripts/software_english_lint.py`: `strip_noise` (878), `prose_lines` (884), `split_sentences` (1168), `sentence_has_verb` (1206), `find_cadence_fragments` (1226), `find_register_candidates` (1813), `main` candidate_input wiring (~2143-2199, ~2295)
- `swe/tests/register_candidates_test.sh`
- `swe/docs/agent-guide.md`
- `swe/.claude-plugin/plugin.json`
- `software-english` `vocabulary/operations.tsv` (reference only, pinned tag v0.0.28)
