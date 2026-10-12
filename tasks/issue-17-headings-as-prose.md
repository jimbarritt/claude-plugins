# Issue #17: check headings as prose in a distinct step

[Issue #17](https://github.com/jimbarritt/claude-plugins/issues/17), opened
by `jimbarritt-pleo`, a trusted collaborator. Claimed by the
self-maintaining-repo Routine.

## The ask, verbatim

> ## The gap
>
> Across several passes on one document, the body prose reached a clean
> state on both tiers while the headings still held faults the same rules
> would have caught in a sentence: a metaphor used as the section name, a
> heading defined by what the section does not cover rather than what it
> states, a rhetorical question in place of a claim, and headings that
> withhold their content so the reader must read the section to learn what
> it says.
>
> The deterministic tier reports a line number, so it does read heading
> lines. The gap is in the inference tier, where metaphor and contrastive
> framing are judged: nothing instructs the judging pass to treat headings
> as prose, and in a long document they are skipped over while paragraphs
> are judged.
>
> A heading is the highest-leverage prose in a document. It is what a
> reader scans, it is written last, and it is re-read least.
>
> ## Ask
>
> An explicit step, in the `lint-file` skill and in the output style: after
> the body is clean, extract the heading list on its own and apply the
> sentence-level rules to each heading as a sentence. A heading-only
> extraction is trivially producible, and reviewing headings as a
> contiguous list also surfaces faults invisible in place, such as
> inconsistent grammatical form across sibling headings.
>
> This is a procedural step, not a rule. The two heading-specific faults
> with no current home in the catalogue are proposed separately against
> the spec repository.

## Reading

Bounded, procedural ask: a second judging pass over the heading list,
added to `swe/skills/lint-file/SKILL.md`'s Step 4 and to
`swe/output-styles/software-english.md`. No code change, no new rule.

Checked against the pinned `software-english` tag (`v0.0.10`,
`rules/core-rules.toml`): two of the four named faults already have a
catalogue rule (`no-metaphor-or-analogy`, `no-contrastive-framing`); a
rhetorical question in place of a claim, and a heading that withholds its
content, have none yet — the issue itself says those two are proposed
upstream separately and are out of scope here. The new step therefore
judges headings only against the rules Step 3 already prints; it does not
name the ruleless faults, since that would add a rule through the back
door. Sibling grammatical-form consistency is the same case: no rule
exists, so the new text does not call it out as a fault to report.

## Plan (from an Opus Plan subagent's read of the real files)

1. `swe/skills/lint-file/SKILL.md`: replace the whole `## Step 4` section
   with two named passes (body, then headings-as-a-list), both against
   the same `inference pending` rules from Step 3. Keep it as one step
   (no renumbering — "Step 5", "Step 6" are referenced elsewhere in
   SKILL.md, `agent-guide.md`, and a code comment in
   `software_english_lint.py`). Also adjust Step 6's summary line to say
   "both passes".
2. `swe/output-styles/software-english.md`: append a new "Headings"
   section at the end (after "Longer explanations and documents"), so it
   can refer to "every rule above".
3. `swe/scripts/software_english_lint.py`: no change. `prose_lines()`
   (lines 568-585) already yields heading lines like any other prose
   line, so the deterministic tier already lints headings and reports
   their line numbers; the heading list for the inference pass is built
   from the same `Read` output Pass 1 already uses, not a new `--headings`
   flag.
4. `swe/docs/agent-guide.md`: small accuracy update — note the two-pass
   judgement in "When the inference tier runs", and a "Known limits"
   bullet naming the two ruleless heading faults the pass does not catch.
5. Tests: none added. The change is prose-only; a test that greps SKILL.md
   for new text would not verify behaviour. Before committing: run
   `swe/tests/skill_frontmatter_test.sh` and the other suites as a sanity
   check, fetch `software-english` data and run the real linter
   (`--force-inference --quiet-vocab`) against the edited SKILL.md itself
   (it is not `.swe-ignore`d), and hand-judge the new paragraphs against
   what it prints — the new step applied to its own file.
6. Version: `swe/.claude-plugin/plugin.json` is at `0.16.4`, released
   (`swe-v0.16.4` tagged). Bump to `0.17.0` (minor, matching #14's
   precedent for a behaviour change to a skill/output style).

Full plan text, including exact replacement markdown for both files, is in
this session's own agent transcript; implementation will write the exact
text directly rather than retype it here.

## Status

Planned. Proceeding to implementation on `main`.
