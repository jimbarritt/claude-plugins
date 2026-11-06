# Plan: software-english#28

## The ask (verbatim)

Title: "Inference tier misses a contrast pair split across short sentences"

> A full inference pass judged every unit in a document and recorded it clean. One list item still reads as model-generated. The shape is a run of three short sentences. Sentence one names two things and orders them. Sentence two states a general property of the first. Sentence three states the contrasting property of the second, in comparative form.
>
> A neutral example with the same shape:
>
> > The index is separate from the cache and the job rebuilds it overnight. The cache stores recent results. The index will be larger and will be built from the full table.
>
> The middle sentence exists only to set up the comparison in the third. Read alone, each sentence states a plausible fact, so each unit passes. The cadence is the fault, and it is visible only across the three together.
>
> Related rules: `no-contrastive-framing`, `no-clipped-sentence-run`, `no-entailed-restatement`. None fired.
>
> Fix direction: this is a question of scope more than of wording. Judge a list item or a paragraph as one unit, or add a worked example for a comparison pair split across consecutive short sentences.

URL: https://github.com/jimbarritt/software-english/issues/28

## Reading of the issue

The example states a comparison across three sentences, each with a named subject (no pronoun chain). Each sentence is a complete, true fact read alone. The fault is the relation between the sentences: sentence two exists only to supply the comparand that sentence three's comparative word ("larger") needs, and a reader must carry that comparand across a sentence boundary.

None of the three named rules cover this, each for a specific reason checked against the current rule text:

- **`no-clipped-sentence-run`** (SPEC §3.6) fires only on one fact split into pieces and rejoined by a pronoun chain with a changing referent. Its own "Not this fault" list excludes this example twice over: "a run of short sentences that each state a separate, complete fact with a named subject" and "a list item (§3.4), which is short by design."
- **`no-contrastive-framing`** (SPEC §5.7) needs a sentence that states what does *not* happen, answering an objection the reader has not raised. Here both sides of the comparison are stated plainly; there is no unstated case being defended against.
- **`no-entailed-restatement`** (SPEC §7.12) needs a clause that *follows from* a fact already stated. Sentence two is not entailed by sentence one — it cannot be derived, so cutting it loses a fact. The problem is placement, not redundancy.
- **`no-cadence-device`** (SPEC §8.1) needs a *restatement* of a fact the sentence before it already states. Each sentence here states a different fact, so this rule does not apply either, and its own "Not this fault" list specifically protects a parallel pair like "A read takes a shared lock. A write takes an exclusive lock." — the new rule must not catch that pair.

## Decision

Add a new inference-based rule, `no-split-contrast-pair`, catalogued as a new **SPEC §8.4** (an addition to §8, Register rules — this is a pattern a reader recognises as model-generated, like its siblings §8.1–§8.3). Do not widen `no-clipped-sentence-run`: its pronoun-chain trigger and list-item exclusion are correct for the fault it targets, and removing either to catch this shape would raise false positives across every short-sentence run that is not this fault.

This is a **software-english-only** change: `rules/core-rules.toml` and `spec/SPEC.md`. No `claude-plugins` code change is needed — the plugin's lint-file worklist already treats each top-level list item as one unit (`/home/user/claude-plugins/swe/skills/lint-file/SKILL.md`), and `software_english_lint.py` reads every inference rule from the TOML generically, with no per-rule detector code required for a new rule. Because the change touches `rules/core-rules.toml`, it does trigger a `swe` plugin pin bump and release per the briefing's step 7 (software-english issue, rule data touched).

## Plan steps

1. Add the `no-split-contrast-pair` rule block to `rules/core-rules.toml`, inserted after the `no-distributive-tail` block and before `no-withholding-heading` (preserving file order, which tracks SPEC section order).
2. Add a one-sentence cross-reference to the new rule at the end of the "Not this fault" discussion in `no-clipped-sentence-run`'s TOML description, so the two rules point at each other.
3. Add the SPEC.md Contents entry for "8.4 No split contrast pair" after the 8.3 entry.
4. Add the matching cross-reference sentence to SPEC §3.6's "Not this fault" list in SPEC.md.
5. Add the new SPEC §8.4 section in full, after §8.3 and before "## Appendices", mirroring the TOML description's content in SPEC's prose-plus-blockquote style.
6. Record the decision in `COLOPHON.md` (every rule-adding commit in this repo keeps a decision record there).
7. Update the two rule-count mentions in the intro deck (`docs/public/presentations/intro/intro-to-software-english.md`, and its built HTML) from 35/41 to 36/42 inference/total rules, matching every prior rule-adding commit's convention. Rebuild the PDF if the toolchain is available; otherwise edit the HTML by hand and note in the commit that the PDF was not rebuilt.
8. Validate: TOML parses, and the rule count is 42 `[[rules]]` blocks, 36 of them inference-based. Lint every touched prose file with the swe lint procedure.
9. Commit on `main`, with `Closes #28`, and push.
10. Release `software-english` (`release.yml`, next patch tag). Since the change touches `rules/core-rules.toml`, move the `swe` plugin's pin in `claude-plugins`: update `swe/software-english.json`'s tag, bump `swe`'s `plugin.json` version, push `claude-plugins` `main`, and run `release-plugin.yml -f plugin=swe`.
11. Close the loop on the issue: comment with commit and release tags, close the issue, remove `agent:working`.

## Exact text for each file change

### `rules/core-rules.toml`

Insert after the `no-distributive-tail` block (ends `...so this stays inference-based."`), before `[[rules]]` / `id = "no-withholding-heading"`:

```toml
[[rules]]
id = "no-split-contrast-pair"
tier = "inference-based"
check = "model-judgement"
severity = "warning"
description = "A comparison between two things states both sides, and the relation between them, in one sentence (SPEC §8.4). A split contrast pair is a run of three consecutive sentences, in one paragraph or one list item, that states a comparison without naming it: the first sentence names two things, A and B; the second states a property of A alone; the third states a property of B with a comparative or a contrast word, and its comparand is the property the second sentence states. Each sentence states a plausible fact alone, so a judgement of one sentence at a time finds no fault. The fault is the cadence of the three together: the second sentence exists to set up the comparison in the third, and a reader must remember A's property from the sentence before to read the third. A reader recognises the cadence as a pattern of text generated by a language model; the rule judges the text, not its author. Fault: 'The index is separate from the cache and the job rebuilds it overnight. The cache stores recent results. The index will be larger and will be built from the full table.' The first sentence names the index and the cache. The second states a property of the cache alone. 'Larger' in the third names no comparand in its own sentence: the cache and its recent results are in the sentence before. Fix: state A's property where the text first names A, and state the comparison in one sentence that names both sides: 'The index is separate from the cache, which stores recent results. The job rebuilds the index overnight from the full table, so the index is larger than the cache.' Scope: one paragraph or one list item, judged as one unit. A list item is in scope, since the fault is a comparison split across sentences, not the length of the sentences. Judge in two steps: first find a run of three consecutive sentences in one paragraph or one list item where the first names two things, the second states a property of one of them with no comparative, and the third states a property of the other with a comparative ('larger', 'smaller', 'more', 'fewer', 'faster', 'slower') or a contrast word ('instead', 'by contrast', 'whereas'); then read the third sentence alone, and check whether its comparative or its contrast word names its comparand. Report a finding only where the comparand is only in the sentence before, and give the merged sentences as the fix. Not this fault: a comparison stated in one sentence that names both sides ('the index is larger than the cache'); two sentences in the same shape that each state a complete fact alone, with no comparative and no contrast word ('A read takes a shared lock. A write takes an exclusive lock.'); a third sentence that names its own comparand ('than the cache'); a table, or a list where each item states the property of one member; quoted material (SPEC §6.3) or a literal token (SPEC §6.2). Distinct from no-clipped-sentence-run (SPEC §3.6): that rule covers one fact split into pieces joined by a chain of pronouns, and excludes a list item; this rule covers a comparison split across sentences with named subjects, and includes a list item. Where one run has both faults, report each. Distinct from no-contrastive-framing (SPEC §5.7): that rule covers a contrast with a case the reader has not asked about; here the text states both sides of the comparison, and the fault is the split. Where the third sentence states what B does not do, report it under no-contrastive-framing only. Distinct from no-entailed-restatement (SPEC §7.12): the second sentence does not follow from the first, so cutting it loses a fact; the fix moves it. Distinct from no-cadence-device (SPEC §8.1): a cadence device restates a fact the sentence before it states; each sentence here states a different fact. Distinct from no-out-of-scope-comparand (SPEC §7.10): where the reader's task does not need A at all, report it under that rule only, since the fix cuts A. A parser can find a comparative word, but whether its comparand is in its own sentence, and whether the sentence before exists only to give it one, needs judgement, so this stays inference-based."
```

In `no-clipped-sentence-run`'s description, directly after "...a numbered sequence of steps in a Tutorial or a How-to guide (SPEC §7.8)." insert:

```
A run with named subjects that splits a comparison across its sentences is a no-split-contrast-pair finding (SPEC §8.4), in a paragraph or in a list item.
```

### `spec/SPEC.md`

Contents, after the "8.3 No distributive tail" entry:

```
  - [8.4 No split contrast pair](#84-no-split-contrast-pair-inference-based)
```

In §3.6, after the three "These are not this fault" bullets, before "The 20-word limit (§3.2) is a ceiling...":

```
A run of short sentences with named subjects that splits a comparison
across its sentences is a §8.4 finding, in a paragraph or in a list
item.
```

New section, after §8.3 ends, before `## Appendices`:

```markdown
### 8.4 No split contrast pair (Inference-based)

A comparison between two things states both sides, and the relation
between them, in one sentence. A split contrast pair is a run of three
consecutive sentences, in one paragraph or one list item, that states
a comparison without naming it. The first sentence names two things.
The second states a property of the first thing alone. The third
states a property of the second thing with a comparative or a
contrast word, and its comparand is the property the second sentence
states:

> The index is separate from the cache and the job rebuilds it
> overnight. The cache stores recent results. The index will be
> larger and will be built from the full table.

Each sentence states a plausible fact alone, so a judgement of one
sentence at a time finds no fault. The fault is the cadence of the
three together. The second sentence exists to set up the comparison in
the third. "Larger" names no comparand in its own sentence: the cache
and its recent results are in the sentence before, so a reader must
remember them to read the third sentence.

State the first thing's property where the text first names it. State
the comparison in one sentence that names both sides:

> The index is separate from the cache, which stores recent results.
> The job rebuilds the index overnight from the full table, so the
> index is larger than the cache.

Scope: one paragraph or one list item, judged as one unit. A list item
is in scope. The fault is a comparison split across sentences, not the
length of the sentences, so §3.6's exclusion of a list item does not
apply.

Test: read the third sentence alone. If its comparative or its
contrast word names no comparand, and the comparand is only in the
sentence before, the run is this fault.

These are not this fault:

- a comparison stated in one sentence that names both sides ("the
  index is larger than the cache");
- two sentences in the same shape that each state a complete fact
  alone, with no comparative and no contrast word ("A read takes a
  shared lock. A write takes an exclusive lock.");
- a third sentence that names its own comparand ("than the cache");
- a table, or a list where each item states the property of one
  member;
- quoted material (§6.3) or a literal token (§6.2).

Distinct from §3.6: that rule covers one fact split into pieces joined
by a chain of pronouns, and excludes a list item. This rule covers a
comparison split across sentences with named subjects, and includes a
list item. Where one run has both faults, report each. Distinct from
§5.7: that rule covers a contrast with a case the reader has not asked
about. Here the text states both sides, and the fault is the split.
Where the third sentence states what the second thing does not do,
report it under §5.7 only. Distinct from §7.12: the second sentence
does not follow from the first, so cutting it loses a fact. The fix
moves it. Distinct from §8.1: a cadence device restates a fact the
sentence before it states. Each sentence here states a different
fact. Distinct from §7.10: where the reader's task does not need the
first thing at all, report it under §7.10 only, since the fix cuts it.

A parser can find a comparative word. Whether its comparand is in its
own sentence, and whether the sentence before exists only to give it
one, needs judgement, so this stays inference-based.
```

### `COLOPHON.md`

Append a decision record at the end, in the repo's existing style, summarising the gap and the §8.4 decision (drafted during Work, matching the actual change made).

### Intro deck rule counts

`docs/public/presentations/intro/intro-to-software-english.md` and its built HTML: both mentions of the rule count (currently 35 inference / 41 total) become 36 inference / 42 total.

## Verification performed before Work

Checked directly against the files, not just the subagent's report:

- `rules/core-rules.toml` currently has 41 `[[rules]]` blocks, 35 `tier = "inference-based"` — confirmed by direct grep, consistent with "42 total / 36 inference" after the addition.
- `no-distributive-tail` ends and `no-withholding-heading` begins exactly where the plan says (lines 285–297 / 298 in the pre-change file) — confirmed by direct read.
- SPEC.md §8.1–§8.3 exist at the stated positions, `## Appendices` immediately follows §8.3 — confirmed by direct grep/read.
- The TOC lists "8.3 No distributive tail" immediately before the "Appendices" top-level entry — confirmed.
- The shared-lock/exclusive-lock example the new rule's "Not this fault" list excludes is the same example already used by §8.1's own "Not this fault" list — confirmed by direct grep (SPEC.md:1887-1888, 2046).
- The rule referenced at SPEC §7.10 is `no-out-of-scope-comparand` — confirmed by direct grep, matching the "Distinct from" cross-reference used in the new rule's text.

No open question in the issue needed a `tsk decision add`; the issue states the fix direction itself ("judge a unit... or add a worked example") and the plan resolves that choice (new rule, not re-scoping the worklist unit, since the unit is already scoped correctly — the gap is purely in the rule data).
