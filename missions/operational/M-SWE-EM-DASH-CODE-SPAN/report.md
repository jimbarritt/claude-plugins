# software-english#27: no-em-dash: an em dash inside a short inline code span of natural-language text gets no finding

[Issue #27](https://github.com/jimbarritt/software-english/issues/27), opened by jimbarritt-pleo on
2026-10-28. Claimed, planned, escalated and shipped by the self-maintaining-repo Routine and a
live supervisor decision on 2026-10-29.

## Commits and releases

- `software-english` [`b43ce39`](https://github.com/jimbarritt/software-english/commit/b43ce399c1b95eadabdace21327900708dcb7a4c)
  ("no-em-dash: exempt a code span that reads as code, a tight-bound
  title/compound, an article-led phrase, or a quotation, closes #27"),
  released as [v0.0.32](https://github.com/jimbarritt/software-english/releases/tag/v0.0.32).
- `claude-plugins` [`d9af284`](https://github.com/jimbarritt/claude-plugins/commit/d9af284665ce09cb3906a5272427fca1be9d5e97)
  ("swe: a code-span em dash that reads as text gets a warning finding,
  pick up software-english v0.0.32"), released as
  [`swe-v0.24.10`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.24.10).

## What changed

`software_english_lint.py`'s `strip_noise()` blanked every inline code
span to spaces before the blanket, error-severity no-em-dash count ran
(`check_line()`), so an em dash physically inside a code span never got a
finding. A second check, `check_code_span_em_dash()`, now scans the
`keep_code=True` view of each line and reports a finding at the
catalogue's new `code_span_severity` field (`warning`, read with a
`.get(..., "warning")` default so an older pinned tag still works) when
the span's own text, via `code_span_reads_as_text()`, reads as a label or
a sample value: it has a space, is mostly letters/digits/spaces (an
0.8 ratio once the dash itself is excluded), and shows none of four
exemption signals. The two views (`blanked`/`kept`) never double-count a
character: `lint_text()` walks them in lock-step, and a dash inside a
span is blanked on the `blanked` view and only ever seen by the new path
on the `kept` view.

Exemption signals, matching `core-rules.toml`'s `no-em-dash.description`
and SPEC §3.5:

1. the text reads as code (`CODE_SPAN_CODE_SIGNAL`: `::`, `->`, a
   function call, a path or dotted name, a flag), or has no space at all
   — the issue's own proposed test;
2. no space touches the dash itself (`Word—Word`), a title's or a
   compound's own convention;
3. the text opens with "the", "a", or "an": a label or a value is a bare
   phrase, not a clause;
4. the text carries an inner quote mark, a quotation inside a quotation.

## What was found along the way, and the live decision

The Opus Plan subagent, before any code was written, ran the issue's own
proposed heuristic (signal 1 alone: has a space, is mostly
letters/digits/spaces) read-only over every Markdown file in both
repositories. It flagged three real spans, none of them a sample value:

- `software-english/docs/public/presentations/intro/intro-to-software-english.md:176`
  and `:180` — two rows of a table whose own stated purpose is to
  catalogue examples of banned writing habits (filler, metaphor,
  anthropomorphism, the em dash itself), each quoted inline in a code
  span because a blockquote cannot appear inside a table cell;
- `software-english/templates/design.md:5` — the verbatim title of IEEE
  Std 1016-2009, which a writer cannot change.

SPEC §6.3 already names the code span as the sanctioned way to quote a
fault example inline, for exactly the case a blockquote cannot reach
(inside a sentence, or inside a table cell). Implementing the issue's
heuristic as proposed would have started warning on this repository's
own teaching material and a standard's title: a real fork between
implementing as proposed and closing the issue as won't-fix, meeting the
Escalate criterion ("two readings of the issue lead to materially
different work"). This run escalated rather than picking a reading
unilaterally: wrote the fork into the plan document, raised Q-01 on this
mission, paused the thread, commented the question on the issue, and
swapped `agent:working` for `supervisor`.

Jim (the session's live supervisor) answered in the same session,
not via a GitHub comment: implement the fix, but add more nuance so the
three found spans stay exempt. Signals 2-4 above are the result, each
tied to a real distinguishing feature of the three spans (an unspaced
dash for the title; an opening article for the metaphor-habit row; an
inner quote mark for the contrast-habit row), not reverse-engineered
from them alone. The decision and the question's answer are both
recorded on this mission (`tsk decision add`/`tsk question answer`,
`--by jim`), since they did not arrive as a trusted GitHub comment the
way the Escalate section otherwise expects.

## Verification

- Manually, against a scratch catalogue built from the real,
  locally-edited `core-rules.toml`: the issue's own motivating example
  warns; the three real-repo spans, the issue's code-shape fixtures
  (flag, identifier, function call, `::`, `->`, path, a flag with a
  space in its value), a fenced block, a blockquote, and a skip-marker
  line all stay clean of `no-em-dash`; a mixed line gets exactly one
  error and one warning (no double count); the older-pin fallback
  (`code_span_severity` absent) defaults to warning.
- Added `swe/tests/em_dash_code_span_test.sh` (22 assertions, Part 1
  against real data via `SWE_SRC`/the pinned fetch, Part 2 against a
  scratch catalogue for the `code_span_severity` switch at `warning`,
  `error`, and absent).
- Ran every test file under `swe/tests/` (17 files) against the
  released `software-english` v0.0.32 data: all pass, no regressions.
- `scripts/check-unshipped.sh`: clean after the release
  (`swe: 0.24.10 is released and matches swe-v0.24.10. Up to date.`).
- `/swe:lint-file` on `software-english/spec/SPEC.md`: ran the
  deterministic tier and judged the changed sections (§3.5, §6.2, §6.3)
  against the located inference candidates on those lines; found and
  fixed two banned-word slips ("carries", "held" — twice) and three
  sentences over the 20-word limit (the per-line deterministic checker
  does not catch a long sentence wrapped across source lines, so these
  were fixed by inspection, not by the tool's own report) and one
  unanchored-reference candidate ("the title and compound convention"
  misread as a definite reference). Did not judge the full 566-unit,
  28-rule worklist against the whole 2300-line pre-existing file: that
  file is a rules specification that deliberately quotes banned and
  anthropomorphic phrasing throughout as its own illustrations (24
  pre-existing deterministic-tier findings on unrelated lines, all
  intentional), so a whole-file pass was out of proportion to a ~40-line
  change; scope was the changed sections only, consistent with Appendix
  B's own "changed lines only by default" enforcement model.
