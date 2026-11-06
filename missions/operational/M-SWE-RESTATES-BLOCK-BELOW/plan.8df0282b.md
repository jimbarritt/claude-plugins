# Plan: software-english#30 — a sentence that restates what the block below it plainly is

## The ask (verbatim)

Title: "Rule: a sentence that restates what the block below it plainly is"

> A caption above a table restated what the table plainly is, in the shape of a scope preamble. Both tiers passed it.
>
> A neutral example, directly above a list:
>
> > This section lists every value the installation requires, in the order it requires them.
>
> The sentence adds nothing the list does not already show. It describes the artefact to its own reader.
>
> The meta-remark rules cover remarks about the writing itself, such as a phrase announcing that a shorter account follows. None covers a sentence that restates what the next block plainly is.
>
> Fix direction: fire on a sentence whose subject is the containing document or section. The trigger is a statement of what that block contains.

URL: https://github.com/jimbarritt/software-english/issues/30

## Reading

Checked against `spec/SPEC.md` (§5.3, §7.1, §7.6, §7.12, §8.3) and the matching `rules/core-rules.toml` entries:

- §5.3 `no-remark-about-the-writing` already exempts a cross-reference such as "§4 lists the retry limits", and its judge method keys on navigational/copular phrasing ("this is where", "is for", "comes in"), not on a plain declarative with the document/section as subject and a content verb ("This section lists..."). Folding this fault in would mean writing an exception to its own exception.
- §7.6 `vacuous-classification-property` is specifically about a number word at the head of a sentence (count signpost) or a cardinality/exclusivity property near a taxonomy definition. The issue's example has no count and names a table/section, not a set property. Does not fit the existing trigger family.
- §7.1 `summary-before-detail` already owns the whole-document form of this fault (an opening paragraph that states only what the document covers). The issue's fault is the same shape one level down: a section or a block inside the body, not the document's own opening paragraph.
- §7.12 `no-entailed-restatement` is the general, backward-looking sibling (a clause derivable from a fact already stated earlier). The issue's fault is forward-looking: a sentence describes a block that follows it, before the reader has seen it.

## Decision 1 — where the fault belongs

**A new standalone rule, §7.23 `no-scope-preamble`, appended at the end of §7.** Its trigger (document/section/block as subject + content verb) belongs to none of the existing rules; each sibling already states "report under X only" for its own near-miss case, so a new id with its own trigger keeps one owner per sentence. Appending at the end (§7.23) avoids renumbering rules the catalogue and SPEC Contents cite by number — the precedent §7.21/§7.22 followed the same reasoning.

## Decision 2 — id, tier, severity, triggers

- id: `no-scope-preamble`
- SPEC heading: `### 7.23 No scope preamble (Inference-based)`
- tier/check: `inference-based` / `model-judgement` — a parser can find "this section lists", but only judgement tells whether the block after it already shows everything the sentence claims.
- severity: `warning` (matches §5.3, §7.1, §7.6, §7.12 — redundant, not false)
- trigger_phrases:
  ```
  "this section lists", "this section describes", "this section shows",
  "this section covers", "this section contains", "this page lists",
  "this list", "this table", "the table below", "the list below",
  "the following table", "the following list"
  ```

## Decision 3 — drafted prose

### `spec/SPEC.md` — new §7.23, inserted after §7.22, before `## 8. Register rules`

```markdown
### 7.23 No scope preamble (Inference-based)

A scope preamble is a sentence whose subject is the document, the
section, or the block it is in, and whose verb states what that block
contains. Where the block after it shows the same content, the
sentence adds no fact. A reader reads the block and has the content.

Fault, directly above a list:

> This section lists every value the installation requires, in the
> order it requires them.

Fault, directly above a table:

> The table below shows each region and its default queue.

Fix: delete the sentence and start with the block. Where the sentence
states a fact the block does not show, keep that fact and cut the
description:

> The installer reads these values in order, and stops at the first
> missing one.

Test: delete the sentence. If a reader who reads the block loses no
fact, the sentence was a scope preamble.

Judge in two steps. First, find each sentence in body prose whose
subject is the document, the section it is in, or the block directly
after it (`this section`, `this page`, `this list`, `this table`, `the
table below`, `the following list`), and whose verb states content
(`lists`, `shows`, `describes`, `contains`, `covers`, `gives`,
`names`). Then compare the sentence with the block directly after it,
or with the rest of its section. Report a finding only where that
block shows everything the sentence states.

These are not this fault:

- a cross-reference that names another part of the document: `§4
  lists the retry limits` (§5.3 also excludes it);
- a sentence that states a fact the block does not show, such as a
  source, a unit, an order a mechanism reads, or a part of a larger
  set: `The table lists only the regions that accept writes.`;
- a sentence that states where a section's rule comes from: `This
  section is Software English's own rule, not Diátaxis's wording.`;
- an instruction about the section in a template;
- a heading (§7.17 judges a heading);
- quoted material (§6.3).

Other rules have a nearby claim:

- §7.1: an opening paragraph that states only what the document
  covers is a §7.1 finding. Report it under §7.1 only. This rule
  covers a sentence in the body, at the start of a section or above a
  block.
- §7.6: a sentence that starts with a number word and states only how
  many items follow it is a count signpost. Report it under §7.6 only.
  A sentence with the block as its subject that also states a count
  (`This list names the three values the installer reads.`) is a
  finding under this rule only.
- §5.3: a navigational announcement states where the document turns
  to a subject, or what a part of it is for (`That is what the next
  section is for.`). Report it under §5.3 only. This rule covers a
  plain statement of what the block contains.
- §8.3: a clause about the document's layout joined to a sentence that
  states a fact is a §8.3 finding. This rule covers a sentence that
  states only the block's content.
- §7.12: an entailed restatement repeats a fact the text before it
  states. A scope preamble describes the block after it.

A parser can find a sentence whose subject is `this section` or `the
table below`. Whether the block after it shows everything the
sentence states needs judgement, so this stays inference-based.
```

Verify the third "not this fault" bullet's wording against the real line in `templates/reference.md`/`templates/design.md` during implementation, and quote it exactly or swap in a neutral instruction.

### `rules/core-rules.toml` — new entry, appended after `no-remark-about-the-writing`, before `[exemptions]`

```toml
[[rules]]
id = "no-scope-preamble"
tier = "inference-based"
check = "model-judgement"
severity = "warning"
trigger_phrases = [
  "this section lists", "this section describes", "this section shows",
  "this section covers", "this section contains", "this page lists",
  "this list", "this table", "the table below", "the list below",
  "the following table", "the following list",
]
description = "A sentence whose subject is the document, the section, or the block it is in, and whose verb states what that block contains, adds no fact where the block after it shows the same content (SPEC §7.23). Fault, directly above a list: 'This section lists every value the installation requires, in the order it requires them.' Fault, directly above a table: 'The table below shows each region and its default queue.' Fix: delete the sentence and start with the block; where the sentence states a fact the block does not show, keep that fact and cut the description ('The installer reads these values in order, and stops at the first missing one.'). Test: delete the sentence; if a reader who reads the block loses no fact, it was a scope preamble. Judge in two steps: first find each sentence in body prose whose subject is the document, the section it is in, or the block directly after it ('this section', 'this page', 'this list', 'this table', 'the table below', 'the following list'), and whose verb states content ('lists', 'shows', 'describes', 'contains', 'covers', 'gives', 'names'); then compare the sentence with the block directly after it, or with the rest of its section. Report a finding only where that block shows everything the sentence states. Not this fault: a cross-reference that names another part of the document ('§4 lists the retry limits'); a sentence that states a fact the block does not show, such as a source, a unit, an order a mechanism reads, or a part of a larger set ('The table lists only the regions that accept writes.'); a sentence that states where a section's rule comes from ('This section is Software English's own rule, not Diátaxis's wording.'); an instruction about the section in a template; a heading, which no-withholding-heading (SPEC §7.17) judges; quoted material (SPEC §6.3) or a literal token (SPEC §6.2). Distinct from summary-before-detail (SPEC §7.1): an opening paragraph that states only what the document covers is a finding under that rule only; this rule covers a sentence in the body. Distinct from vacuous-classification-property (SPEC §7.6): a sentence that starts with a number word and states only how many items follow it is a count signpost, reported under that rule only; a sentence with the block as its subject that also states a count ('This list names the three values the installer reads.') is a finding under this rule only. Distinct from no-remark-about-the-writing (SPEC §5.3): a navigational announcement ('This is where the signing certificate comes in.', 'That is what the next section is for.') is a finding under that rule only; this rule covers a plain statement of what the block contains. Distinct from no-distributive-tail (SPEC §8.3): a clause about the document's layout joined to a sentence that states a fact is a finding under that rule only. Distinct from no-entailed-restatement (SPEC §7.12), which covers a repeat of a fact the text before it states; a scope preamble describes the block after it. A parser can find a sentence whose subject is 'this section' or 'the table below', but whether the block after it shows everything the sentence states needs judgement, so this stays inference-based."
```

### Reciprocal cross-references (small edits)

- SPEC §5.3 nearby-claim list: add `§7.23: a sentence whose subject is the section or block it is in, and that states only what the block contains, is a §7.23 finding. Report it under §7.23 only.` + matching sentence in the `no-remark-about-the-writing` TOML description.
- SPEC §7.6 "Distinct from" paragraph: add `Distinct from §7.23: a sentence with the block as its subject that states a count is a §7.23 finding. This rule covers a number word at the head of the sentence.` + matching TOML sentence in `vacuous-classification-property`.
- SPEC §7.1 nearby-claim list: add `§7.23 covers the same subject-only sentence inside the body, at the start of a section or above a block.` + matching TOML sentence in `summary-before-detail`.
- §8.3: leave unchanged — the new rule already defers to it, and §8.3's own trigger cannot match a subject-is-the-block sentence.

## Decision 4 — `COLOPHON.md`

Add a new subsection (this is a new rule id, not a second fault folded into an existing one, so it follows the 7cc8331-style precedent, not the 03b3f31-style one):

```markdown
## Scope preamble: a new document rule at the end of §7

A caption above a table stated what the table showed, and both tiers
passed it. `no-remark-about-the-writing` (§5.3) judges a navigational
announcement, and it excludes `§4 lists the retry limits` on purpose,
since a reader can follow that reference to a fact. The caption had the
same grammar, with the block below it as the subject. The count
signpost in §7.6 needs a number word at the head of the sentence, and
the caption had none. §7.1 judges only the document's opening
paragraph.

`no-scope-preamble` catalogues the fault as §7.23: a sentence whose
subject is the document, the section, or the block it is in, and that
states only what the block after it shows. It is the body-level form
of §7.1's second fault. It goes at the end of §7 for the same reason
§7.21 and §7.22 did: an insertion would renumber rules the catalogue
and the Contents list cite by number.

The rule is inference-based. A parser can find `this section lists`,
but whether the block after it shows everything the sentence states
needs judgement. No phrase went into `vocabulary/banned.tsv`: `the
table lists only the regions that accept writes` states a fact the
table does not show.
```

## Decision 5 — `vocabulary/banned.tsv`

No new entries. None of the trigger strings is a fixed phrase that is always wrong ("this section lists" and "the table below" occur correctly where they state a fact the block doesn't show). The existing meta-commentary/text-shape headings already hold the genuinely fixed forms ("what follows", "see below", "two things", "three things").

## Decision 6 — lint and verify before shipping

1. Run `bash /home/user/claude-plugins/swe/scripts/fetch-software-english-data.sh`, then `python3 /home/user/claude-plugins/swe/scripts/software_english_lint.py <file> --cwd . --force-inference --quiet-vocab` on every touched prose file (`spec/SPEC.md`, `COLOPHON.md`, `docs/public/presentations/intro/intro-to-software-english.md` if its rule count is bumped), from `/home/user/software-english`. Fix every deterministic error, then judge the inference worklist against every rule including the new one (the fetched data is the released tag and won't contain `no-scope-preamble` yet, so judge the new section by hand against the working-tree `rules/core-rules.toml`). Re-run until clean, then record the verdict per the skill's step 5.
2. TOML parse check: `python3 -c "import tomllib;d=tomllib.load(open('rules/core-rules.toml','rb'));print(len(d['rules']))"` — expect 43 rule ids, none repeated.
3. Self-application sweep: grep SPEC.md, COLOPHON.md, docs/, templates/ for `this section|this page|this list|this table|the table below|the list below|the following (table|list)`; fix any real scope preamble found, or confirm a listed exclusion applies for each hit.
4. Check the new Contents anchor matches the heading slug (`#723-no-scope-preamble-inference-based`).
5. `scripts/check-unshipped.sh` does not apply here — it is a claude-plugins-repo script, and software-english has no version-bearing manifest; software-english ships via `release.yml` with a typed semver, and any downstream `swe` plugin pin bump is a later, separate step (only needed because this change touches `rules/core-rules.toml`).

## Decision 7 — ordered file edits

1. `spec/SPEC.md` Contents: add the §7.23 entry after the §7.22 line.
2. `spec/SPEC.md`: insert the new §7.23 section after §7.22, before `## 8. Register rules`.
3. `spec/SPEC.md` §5.3: add the §7.23 cross-reference bullet.
4. `spec/SPEC.md` §7.6: add the "Distinct from §7.23" sentence.
5. `spec/SPEC.md` §7.1: add the §7.23 cross-reference bullet.
6. `rules/core-rules.toml`: append the `no-scope-preamble` rule table.
7. `rules/core-rules.toml`: add the three reciprocal "Distinct from no-scope-preamble" sentences to `no-remark-about-the-writing`, `vacuous-classification-property`, `summary-before-detail`.
8. `COLOPHON.md`: append the new rationale subsection.
9. `docs/public/presentations/intro/intro-to-software-english.md`: bump the stated rule count from 42 to 43; regenerate build artefacts if the build toolchain is available, otherwise note the build as stale.
10. Self-application sweep: fix any real scope preamble the grep in Decision 6 step 3 turns up.
11. Verify: TOML parse check, then lint-file on every touched prose file until clean.
12. Commit on `main` with `closes #30`, push, then run `release.yml` with the next patch semver (step 7 of the briefing), and bump+release `swe` in claude-plugins only because this change touches `rules/core-rules.toml`.
