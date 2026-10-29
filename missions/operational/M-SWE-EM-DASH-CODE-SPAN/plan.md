# software-english#27: no-em-dash: an em dash inside a short inline code span of natural-language text gets no finding

[Issue #27](https://github.com/jimbarritt/software-english/issues/27), opened by jimbarritt-pleo on
2026-10-28. Claimed by the self-maintaining-repo Routine on 2026-10-29.

## The ask, verbatim

> ## Verdict
>
> False negative, `no-em-dash`.
>
> ## Shape
>
> A markdown table cell whose value is an inline code span with an em
> dash (U+2014) in it, where the span shows a sample display value in
> natural language, not code:
>
>     | Field | Example |
>     |---|---|
>     | Display name | `2 U+2014 Main Office` |
>
> (with the literal U+2014 character in place of the escape)
>
> The deterministic tier strips code spans before `no-em-dash` runs, so
> this dash gets no finding. An em dash in an ordinary table cell in the
> same kind of document is reported. A reader sees both dashes the same
> way.
>
> ## Proposed fix
>
> Report an em dash inside an inline code span at **warning** severity
> when the span reads as natural-language text, and keep the current
> exemption otherwise:
>
> - **Report:** the span contains a space and is mostly letters, digits
>   and spaces, for example a sample display name or a sample message.
> - **Exempt:** fenced code blocks; spans that read as code (no spaces,
>   or containing `(`, `=`, `/`, `.` between word characters, `::`,
>   `->`).
>
> Fixtures:
>
> - a span with a sample display name: warning;
> - a span with a CLI flag or an identifier: no finding;
> - a fenced block with an em dash: no finding.
>
> The threshold for "reads as natural-language text" is a design choice,
> so this is not labelled for the fix harness.

## Reading

Confirmed the issue's diagnosis by reading
`/home/user/claude-plugins/swe/scripts/software_english_lint.py` directly:
`strip_noise()` (line 922) blanks every `INLINE_CODE` match to spaces of
the same length unless `keep_code=True`; `lint_text()`'s only Markdown
entry point (line 1115) calls `prose_lines(text, exemptions, only_lines)`
with the default `keep_code=False`, so an em dash physically inside a
code span never reaches `check_line()`'s em-dash count (lines 1056-1059).
No lint implementation exists in `software-english`; the fix for the
false negative itself can only land in `claude-plugins`.

A fork emerged that the issue does not mention. SPEC §6.3
(`software-english/spec/SPEC.md`, around line 948) tells a writer to use
a code span as the sanctioned way to quote a fault example inline:
"edit the surrounding prose instead, or use a code span (§6.2) for a
short quoted fragment inline within a sentence." Running the issue's own
proposed heuristic, read-only, over every Markdown file in both repos
turns up three spans it would flag, none of which is a sample display
value:

- `software-english/docs/public/presentations/intro/intro-to-software-english.md:176`:
  `the Messages resource — the beating heart` — a quoted fault example in
  a table of the same shape as the issue's own example.
- `software-english/docs/public/presentations/intro/intro-to-software-english.md:180`:
  `It's not about which format is "best" — it's about ...` — also a
  quoted fault example.
- `software-english/templates/design.md:5`: `IEEE Standard for
  Information Technology—Systems Design—Software Design Descriptions` —
  the verbatim title of a standard, which a writer cannot change.

The heuristic cannot tell "a sample display value the writer chose" apart
from "someone else's exact words, quoted the way §6.3 says to quote
them". Both are inline code spans containing a space and mostly letters.
This is a materially different reading from the issue's own framing, and
the two readings lead to materially different work (Escalate: "Two
readings of the issue lead to materially different work"):

- **Reading A - implement as proposed.** Add a code-span-contents scan to
  `software_english_lint.py` at `warning` severity, distinct from the
  existing blanket `error` finding; add a `code_span_severity` field (read
  with `.get(..., "warning")` so an older pinned catalogue still works) to
  the `no-em-dash` entry in `software-english/rules/core-rules.toml`;
  rewrite SPEC §3.5 and add a sentence to §6.2 and §6.3 so the spec states
  the new partial exception and reconciles it with §6.3's sanctioned
  quoting pattern; decide what to do about the three existing hits
  (accept the new warnings, or add the skip marker to each line). This
  touches both repos: code and a new test in `claude-plugins`, three spec
  sections, the catalogue entry and (optionally) two documents in
  `software-english`.
- **Reading B - close as won't-fix, with a clarifying spec sentence
  only.** Keep the blanket code-span exemption for `no-em-dash`, because
  §6.3 already chose exemption for quoted words, and the issue's own
  argument ("a reader sees both dashes the same way") applies equally to
  a quoted fault example. Add one sentence to SPEC §3.5 or §6.2 stating
  plainly that the code-span exemption covers `no-em-dash`, and close the
  issue citing §6.3 and the three examples above. No code change, no
  catalogue change, no new test.

A secondary fact bearing on Reading A's value, independent of the fork: a
`warning` never blocks a hook (`main()` in `software_english_lint.py`
returns a non-zero exit only when `error_total` is above zero;
`report_and_maybe_block` in `swe/hooks/_lib.sh` returns early on a zero
exit). So Reading A's new finding is silent in every hook unless the same
file also carries an unrelated error; it shows only in a direct
`/swe:lint-file` run or the lint-file skill. This does not resolve the
fork, but it lowers the cost of either answer: implementing Reading A
changes little practical blocking behaviour, and deferring to Reading B
loses little in return.

## Plan

Dispatched an Opus `Plan` subagent with the issue text, the full
`no-em-dash` rule entry, the relevant `software_english_lint.py`
functions (`strip_noise`, `prose_lines`, `check_line`, the `INLINE_CODE`
pattern), SPEC.md §3.5/§6.2/§6.3, and a prior precedent
(`M-SWE-COUNT-SIGNPOST`, software-english#9) where a run declined to make
a `claude-plugins` code change from a software-english issue because
that issue's ask was wording-only. The subagent verified the code
findings directly against both repos, ran the proposed heuristic
read-only against both repos' Markdown, found the three-hit fork above,
and recommends escalating rather than picking a reading unilaterally. If
Reading A is chosen, the subagent returned a complete implementation
plan (exact regex/heuristic, the `check_code_span_em_dash()` helper and
`lint_text()` wiring, the `core-rules.toml` and SPEC.md text, and a new
test file `swe/tests/em_dash_code_span_test.sh` with fixtures); that plan
is preserved below for whichever reading the supervisor picks.

**This run stops here and escalates** (see Escalate in
MAINTAINER-RUN.md: "Two readings of the issue lead to materially
different work"). No task has been started yet beyond this read and
plan, so nothing is in a half-finished state in either repository.

### If Reading A is chosen (full implementation plan, as returned by the Plan subagent)

1. `software-english/rules/core-rules.toml`: add `code_span_severity =
   "warning"` to the `no-em-dash` entry; extend its `description` to state
   the code-span exception and the varying severity.
2. `software-english/spec/SPEC.md` §3.5: replace the "unconditional, no
   exception" paragraph with one documenting the new code-span exception,
   its exact code-reading heuristic, and the warning severity for the
   non-code case.
3. `software-english/spec/SPEC.md` §6.2: add one sentence cross-referencing
   §3.5's new exception.
4. `software-english/spec/SPEC.md` §6.3: add one sentence noting that a
   quoted fragment with an em dash in a code span gets the §3.5 warning,
   and that a blockquote is the way to quote it without triggering that.
5. Decide and record what happens to the three existing hits in
   `software-english` (accept the new warnings, or skip-mark each line).
6. `claude-plugins/swe/scripts/software_english_lint.py`: add
   `CODE_SPAN_CODE_SIGNAL` and `CODE_SPAN_TEXT_RATIO` near `INLINE_CODE`
   (line 600); add `code_span_reads_as_text()`; add
   `check_code_span_em_dash()`; change `lint_text()` to walk the
   `keep_code=False` and `keep_code=True` views of `prose_lines()` in
   lock-step so findings stay in line order and no character is ever
   double-counted (a dash inside a span is blanked on the `check_line()`
   view and only ever seen by the new path).
7. `claude-plugins/swe/tests/em_dash_code_span_test.sh` (new file,
   modelled on the scratch-catalogue half of `anthropomorphism_gate_test.sh`):
   fixtures for a natural-language span (warning), several code-reading
   spans (no finding: a flag, an identifier, a function call, `::`, `->`,
   a path, a low-ratio span), a fenced block (no finding), a mixed line
   with one error and one warning (no double count), a blockquote and a
   skip-marker line (no finding), and a catalogue-switch case proving the
   `.get(..., "warning")` default behaves correctly against an older pin
   with no `code_span_severity` field.
8. Run the new test plus `anthropomorphism_gate_test.sh`,
   `commit_check_test.sh`, `docs_hook_test.sh`, `unit_worklist_test.sh`,
   `lint_fail_open_test.sh`, `motion_idiom_test.sh` and
   `python_syntax_warnings_test.sh` by hand (no run-all runner exists; CI
   only runs `python_syntax_warnings_test.sh`).
9. Sequence the release: merge and tag `software-english` first (steps
   1-5), then land the `claude-plugins` code and test change (steps 6-8),
   optionally bumping `swe/software-english.json`'s pinned tag and `swe`'s
   `version` in the same commit, because the code reads the new catalogue
   field with a default and works against the older pin too.

### If Reading B is chosen

1. `software-english/spec/SPEC.md` §3.5 or §6.2: add one sentence stating
   that the code-span exemption (already structural, via `strip_noise`)
   covers `no-em-dash` too, the same as it covers vocabulary-membership.
2. Close software-english#27 as not planned, citing SPEC §6.3 and the
   three existing spans found above as the reason the proposed heuristic
   cannot tell a sample value apart from sanctioned quoted material.
3. No `claude-plugins` change, no catalogue change, no new test.
