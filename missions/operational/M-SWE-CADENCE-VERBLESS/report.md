# Report: claude-plugins#25, `no-cadence-device` reports a sentence with a finite verb as verbless

## Outcome

Fixed and released.

- Commit: `6dcc6fa` on `jimbarritt/claude-plugins` main — "swe: a code span and a verb-before-pronoun count in no-cadence-device", `closes #25` (auto-closed the issue).
- Release: `release-plugin.yml` run [40735916154](https://github.com/jimbarritt/claude-plugins/actions/runs/40735916154), completed successfully, tag `swe-v0.24.3`.
- Issue comment posted naming the commit, the release tag, and what changed; `agent:working` label removed.

## What changed

`swe/scripts/software_english_lint.py`:

- `strip_noise(line, keep_code=False)` / `prose_lines(..., keep_code=False)`: new optional parameter to skip blanking inline code spans, while still blanking link targets/URLs/HTML tags. Existing callers unaffected (default `False`).
- `main()` now also builds a code-preserving `code_lines` stream per source (Markdown-file, `--text`, `--reply-file`, `--transcript` paths), threaded through a 3-tuple `candidate_input = (numbered_lines, only_lines, code_lines)` (was a 2-tuple). The comment-file path passes `code_lines=None` (comment text is never blanked, so it already has backticks).
- `find_register_candidates(..., code_lines=None)` and `find_cadence_fragments(blocks, verbs, code_lines=None)` take the new parameter and pass it through.
- `split_sentences(paragraph, mirror=None)`: new optional `mirror` parameter — a same-offsets, code-kept version of the same paragraph. Sentence boundaries are still found on the blanked text (so punctuation inside a code span can't create a false boundary); each returned sentence is read from the mirror at the same offsets, stripped independently.
- New `CADENCE_TOKEN` regex: a code span is one token, not blank space, for the fragment's word-count cap and for `sentence_has_verb()`'s tokenising.
- `sentence_has_verb()`: a code token is now opaque (never a verb/auxiliary/determiner, its contents never looked up); a word directly before an object pronoun ("them", "it", "these", "those", "him", "her", "us", "me", "itself", "themselves"), with a subject token before it, now counts as a finite verb even outside the closed verb lexicon, unless the word itself is a preposition/conjunction/negator/quantifier/focusing-adverb/determiner (new `NON_VERB_BEFORE_OBJECT` set).

`swe/tests/register_candidates_test.sh`: 7 new assertions — both issue shapes verbatim, 4 additional verbs outside the lexicon in the same two positions (unlisted verb before a pronoun; unlisted verb with a code-span subject), a multi-line wrapped regression of shape 2, plus true-positive regression coverage (a preposition/negator before a pronoun still gives no verb; a code-span-only fragment and a code-span-verb-word fragment still fire; the reported detail text now quotes the code span's own text rather than blanks).

`swe/docs/agent-guide.md`: updated both places that documented the closed-verb-list limitation, to record the two narrowings (code span as a noun-phrase token; verb-before-pronoun) without overclaiming the lexicon gap itself is gone. This file is listed in `.swe-ignore`, so `/swe:lint-file` correctly reported "No sources to check" for it — no lint action was needed.

`swe/.claude-plugin/plugin.json`: version 0.24.2 → 0.24.3.

## Found along the way

- The planning agent confirmed, by running the locator in-process against the pinned `software-english` vocabulary (tag v0.0.28), that the issue's own two example sentences don't actually reproduce today (`read` is in `operations.tsv`, `tell` is in `COMMON_VERBS`). The defect is real and general, not specific to those two words: it fires on any verb outside the closed lexicon in the same position, e.g. "Every client trusts them.", "...distinguish them." The fix and its tests target the general defect, with the issue's own sentences kept as the primary regression fixtures.
- Correction to the issue's own diagnosis: code spans were indeed blanked, but a lexicon verb directly after the blanks was already recognised before this fix (the word before "tell" is "and", not a determiner). The real failure was the closed verb list combined with the length gate ignoring code spans, not the subject-recognition path as such — both are now addressed.
- claude-plugins#27 (also open, also about the `--force-inference` worklist's text extraction breaking on link/code-span stripping) is a related but distinct code path (the judged-unit text, not the register-candidate locators) and is **not** resolved by this change.

## Verification

- Full `swe/scripts/software_english_lint.py` syntax check: clean.
- Direct unit-level checks of `sentence_has_verb()` and `find_cadence_fragments()` against both issue shapes, 4 additional unlisted-verb variants, and 5 true-fragment variants: all matched expectation.
- All 13 `swe/tests/*.sh` suites pass with `SWE_SRC=/home/user/software-english` (real pinned vocabulary/rules data), including the 46-assertion `register_candidates_test.sh` (39 pre-existing + 7 new).
- `scripts/check-unshipped.sh` confirmed the version bump is pending-release before the workflow ran, and the release workflow completed successfully with tag `swe-v0.24.3` created.
