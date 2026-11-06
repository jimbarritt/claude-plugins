# Plan: claude-plugins#27

## The ask (verbatim)

Title: Inference worklist: link and code-span stripping produces broken text, causing no-unanchored-reference false positives

> ## Verdict
>
> False positive, `no-unanchored-reference`, 2 reports (4 findings in one
> file). Same cause as #25: the prose extractor that builds the
> `--force-inference` worklist in `software_english_lint.py` changes a
> sentence's text before the model judges it.
>
> ## Shapes
>
> 1. **Markdown link.** Source:
>
>    > See [Rotating the signing key](#rotating-the-signing-key).
>
>    Worklist text:
>
>    > See [Rotating the signing key
>
>    The target is removed and the opening bracket is kept. The model
>    reads an unclosed bracket and reports an unresolved reference,
>    though the anchor resolves in the same document.
>
> 2. **Inline code span.** Source:
>
>    > Do **not** add `orders.write` to the read-only role.
>
>    Worklist text:
>
>    > Do **not** add              to the read-only role.
>
>    The span is replaced with spaces of the same width. The model reads a
>    sentence with no object and reports a missing referent.
>
> ## Expected
>
> No finding for either sentence: the link resolves, and the referent is
> named in the source.
>
> ## Proposed fix
>
> In the extractor that builds the inference worklist:
>
> - Replace `[text](target)` with `text`, brackets removed. Keep the
>   target out, or append it in a form the model reads as a link (for
>   example `text (link: #target)`).
> - Replace an inline code span with its own text, or with a placeholder
>   the model reads as a named thing (for example `<code>`), not with
>   blank space. Keep the blank-space form for the deterministic tier if
>   its column offsets depend on it.
>
> Fixtures: a sentence with an in-document link, a sentence whose object
> is a code span, and a sentence whose subject is a list of code spans
> (the #25 shape).

Issue: https://github.com/jimbarritt/claude-plugins/issues/27

## Reading of the code

`swe/scripts/software_english_lint.py`:

- `strip_noise(line, keep_code=False)` (around line 909) blanks links,
  URLs, HTML tags and (unless `keep_code`) inline code spans with
  same-length spaces.
- `prose_lines(...)` applies `strip_noise` while skipping fences,
  indented blocks, blockquotes and skip-marker lines.
- The `--force-inference` worklist has no separate extractor: it is
  built from `prose_units(numbered_lines)`, and `numbered_lines` is the
  same blanked stream the deterministic tier (`check_line`) reads.
  `prose_units` -> `register_blocks` -> heading/paragraph/list-item/table
  text taken straight from those blanked lines.
- claude-plugins#25 (mission `M-SWE-CADENCE-VERBLESS`, shipped as
  swe-v0.24.3) added a second, same-length "mirror" stream
  (`keep_code=True` -> `code_lines`) used only by `split_sentences`'s
  cadence-device locator, via character-offset slicing. Its own mission
  report states explicitly that #27 is "a related but distinct code path
  (the judged-unit text, not the register-candidate locators)" and is
  "not resolved by this change."
- The blanking is still required for the deterministic tier and for
  `split_sentences`'s offset-based mirror slicing (same-length
  constraint), so neither `strip_noise(keep_code=True)` nor
  `code_lines` can change. The fix needs a **third**, worklist-only
  stream that is not constrained to be the same length as the source
  line.
- `find_definite_first_mentions` (the `no-unanchored-reference`
  candidate locator) still reads the blanked `numbered_lines`; that is
  unaffected and explicitly out of scope here, since the issue's
  findings come from the model judging units, not from the candidate
  locator's detail text.

## Steps

1. Add `READABLE_SPAN` regex and a `readable_line(line)` function next
   to `strip_noise`: keeps a code span verbatim with its backticks,
   rewrites `[text](target)` / `![alt](src)` to `text (link: target)`
   (or `(link: target)` if `text` is empty, or bare `text` if `target`
   is empty), and blanks HTML tags to one space. Bare URLs stay
   verbatim. Not same-length; never used by the deterministic tier or
   as a `split_sentences` mirror.
2. Give `prose_lines` a `readable=False` parameter: when true, yield
   `readable_line(line)` instead of running `strip_noise`, keeping the
   same skip logic (so line numbers match `numbered_lines` exactly).
3. Give `prose_units` an optional second stream (`text_lines`) to read
   unit text from, falling back to the original blanked lines when not
   given. Block structure/line ranges still come from
   `register_blocks(numbered_lines)`, so unit counts are unchanged.
4. In `main()`, build a fourth `unit_lines = prose_lines(text,
   exemptions, readable=True)` stream alongside `code_lines`, thread it
   through `candidate_input`, and pass it into the `prose_units(...)`
   call that builds the `--force-inference` worklist. Do not touch
   `lint_text`, `strip_noise`'s default blanking, `code_lines`, or
   `split_sentences`.
5. Update the SKILL.md / agent-guide.md doc lines that describe unit
   `<text>` rendering, to say a link renders as `text (link: target)`
   and a code span stays verbatim.
6. Add fixtures to `swe/tests/unit_worklist_test.sh`: an in-document
   link, a code span as the sentence object, a list of code spans as
   the sentence subject (the #25 shape), a link inside a code span
   (must stay verbatim), and a deterministic-tier regression check
   (code contents must still be excluded from vocabulary checks).
7. Run every test under `swe/tests/`, with particular attention to
   `register_candidates_test.sh` (regression guard for #25's mirror)
   and the new/updated `unit_worklist_test.sh`.
8. Bump `swe/.claude-plugin/plugin.json` version (patch), run
   `scripts/check-unshipped.sh`, commit with `closes #27` plus
   attribution, push `main`.
9. Run `release-plugin.yml` for `swe` via `actions_run_trigger`, poll
   until it finishes, confirm the new tag exists.
10. Comment on the issue with commit + tag, close it if not already
    closed by the commit, remove `agent:working`. Write the report
    document, mark the mission done.

## Out of scope

`find_definite_first_mentions` (the `no-unanchored-reference` candidate
locator) still reads the blanked stream; a follow-up issue can be
raised separately if that detail text also needs cleaning up, but it is
not needed to resolve the false positives reported in #27.
