# software-english#19: a distributive tail coordinated onto a count

[Issue #19](https://github.com/jimbarritt/software-english/issues/19), opened
by `jimbarritt-pleo` (trusted collaborator), labelled `auto-fix-candidate`.

## The ask (verbatim)

> ## Verdict
>
> `false-negative`. No existing rule names this.
>
> ## The shape
>
> A sentence states a count or a set, then appends a coordinated clause that
> distributes a property over the members: `and each is ...`, `and both do
> ...`, `and every one of them ...`.
>
> Example of the fault:
>
> > Four checks run on upload, and each is a step below.
>
> Repaired:
>
> > There are four checks, described in the steps below.
>
> The repair loses a verb and a conjunction, and loses no fact. That is the
> test.
>
> ## Two faults at once
>
> **The coordination is false.** `and` joins clauses of the same kind, and
> these are not. The main clause makes a claim about the subject matter. The
> tail makes a claim about the document's own layout. Joining them with `and`
> presents a structural note as though it were a second finding.
>
> **The distributed property is a misplaced modifier.** `each is a step
> below` is a postmodifier on the noun phrase wearing a clause's clothes.
> Folding it back in is the repair.
>
> ## Why `no-cadence-device` does not reach it
>
> `no-cadence-device` (SPEC §8.1) is the nearest sibling. It requires the
> second part to restate a fact the first part already states, and it names
> two shapes: a verbless fragment set as its own sentence, and a matched pair
> of sentences in the same grammatical frame.
>
> This tail is neither. It adds information rather than restating it, and it
> is a coordinated clause inside one sentence rather than a separate one.
> Same family, a rhythm habit characteristic of generated text, different
> shape.
>
> ## Why it cannot be a regex on `, and each`
>
> The tail is legitimate when the distributed property is subject matter
> rather than layout:
>
> > Three consumers read the topic, and each commits its offset
> > independently.
>
> Nothing there is a claim about the document. The coordination has to be
> judged, not matched, so the rule is inference-based.
>
> ## Proposed direction
>
> A new inference-based rule, working name `no-distributive-tail`. Fire when
> a quantified noun phrase is followed by a coordinated distributive clause
> whose predicate is about the document's structure rather than its subject
> matter. Repair by folding the property into the noun phrase as a
> postmodifier.
>
> Reported as a recurring habit observed across a working session, not a
> single instance.

## Reading

A new §8.3, `no-distributive-tail`, alongside the two existing register
rules (§8.1 `no-cadence-device`, §8.2 `no-mechanical-repetition`): a rhythm
pattern of generated text, inside one sentence rather than across sentences,
that adds no fact about the subject matter. Inference-based, matching the
tier/check/severity of every rule in §7 and §8 (`inference-based`,
`model-judgement`, `warning`).

## Plan (from an Opus Plan subagent, which read SPEC §8 in full, §7.6, and
the matching `core-rules.toml` entries before proposing anything)

Two corrections the subagent made to the issue's own proposal, both forced
by text and conventions already in the repo:

- **The fix sentence.** The issue's own repair, "There are four checks,
  described in the steps below.", drops the fact "run on upload" — which
  fails the issue's own "loses no fact" test — and turns into a §7.6 count
  signpost once the steps follow directly. The plan keeps the fact: "Four
  checks run on upload, described in the steps below."
- **The test.** "Loses a verb and a conjunction, and loses no fact" does not
  separate the fault from the issue's own correct counter-example (which
  also loses no fact if rewritten the same way). The real test is two-step:
  is the distributed property about the document's layout, not the subject
  matter; only then does losing no fact matter.

Also found: the real TOML id for §7.6 is `vacuous-classification-property`
(not `no-vacuous-classification-properties` as assumed going in) — used
correctly in the TOML block below. Cross-references in this spec are not
always bidirectional (checked three existing pairs); the new rule's own
"Distinct from" clause already resolves the only possible overlap (with
§7.6, on a sentence that states only a count), so §8.1 and §7.6 need no
added backreference.

### 1. SPEC.md — Contents entry

After line 64 (`- [8.2 No mechanical repetition](#82-no-mechanical-repetition-inference-based)`):

```
  - [8.3 No distributive tail](#83-no-distributive-tail-inference-based)
```

### 2. SPEC.md — new §8.3

Insert after line 1570 (end of §8.2, before `## Appendices`), with a blank
line each side:

```
### 8.3 No distributive tail (Inference-based)

A distributive tail is a clause joined with `and` to a sentence that
states a count or a set. It gives one property to every member, with
`each`, `both`, or `every one of them`. The tail is this fault where
that property is a fact about the document's own layout:

> Four checks run on upload, and each is a step below.

The main clause states a fact about the system. The tail states where
the document describes each check. `And` joins two clauses of the same
kind, and these two clauses differ in kind. The tail sets out a note
on the document's structure as a second finding. Its property is a
modifier of the noun phrase, written as a clause. Write the property
as a modifier of the noun phrase:

> Four checks run on upload, described in the steps below.

The same fault with `both`:

> The service exposes two endpoints, and both are listed in the table.

Fix:

> The service exposes two endpoints, listed in the table.

Test: first, check that the property is about the document's layout,
not the subject matter. Then write it as a modifier of the noun
phrase. If a reader loses no fact, the tail was this fault.

A tail whose property is a fact about the members is correct:

> Three consumers read the topic, and each commits its offset
> independently.

The tail states a fact about the consumers, not about the document.
Keep it.

These are not this fault:

- a tail whose property is a fact about the subject matter, as in the
  consumer example;
- a distributive word in the main clause, with no tail joined by
  `and` (`Each of the four checks is a step in §4.`);
- a separate sentence that states where the document describes the
  members (`§4 describes each check.`);
- quoted material (§6.3).

Distinct from §8.1's no-cadence-device: a cadence device restates a
fact the sentence before it already states. A distributive tail adds a
fact about the document, inside the same sentence. Distinct from §7.6:
a count signpost states only how many items come directly after it. A
distributive tail is a clause joined to a count whose main clause
states a fact. Where a sentence states only a count of the items after
it, report it under §7.6 only.

A parser can find `, and each` or `, and both` after a count. Telling
a property of the layout from a property of the subject matter needs
judgement, so this stays inference-based.
```

### 3. rules/core-rules.toml — new block

Insert after the `no-mechanical-repetition` block (line 263-264), before
`id = "no-withholding-heading"`:

```toml
[[rules]]
id = "no-distributive-tail"
tier = "inference-based"
check = "model-judgement"
severity = "warning"
description = "A distributive tail is a clause joined with 'and' to a sentence that states a count or a set, which gives one property to every member with 'each', 'both', or 'every one of them' (SPEC §8.3). The tail is this fault where that property is a fact about the document's own layout, not about the subject matter. It adds no fact about the subject matter, and a reader recognises it as a pattern of text generated by a language model; the rule judges the text, not its author. Two faults at once: the coordination is false, because 'and' joins two clauses of the same kind, and here the main clause states a fact about the system while the tail states a note on the document's structure as though it were a second finding; and the distributed property is a modifier of the noun phrase, written as a clause. Fault: 'Four checks run on upload, and each is a step below.' Fix: write the property as a modifier of the noun phrase, 'Four checks run on upload, described in the steps below.' Fault: 'The service exposes two endpoints, and both are listed in the table.' Fix: 'The service exposes two endpoints, listed in the table.' Correct, not this fault: 'Three consumers read the topic, and each commits its offset independently.' The tail states a fact about the consumers, not about the document; keep it. Judge in two steps: first find a sentence that states a count or a set and then a clause joined with 'and' that opens with 'each', 'both', 'every one of them', or a similar distributive word; then check whether that clause's property is about the document's layout (a step, a section, a table, a list, a position such as 'below') and whether writing it as a modifier of the noun phrase loses a fact. Report a finding only where the property is about the layout and the modifier form loses no fact, and give the modifier form as the fix. Not this fault: a tail whose property is a fact about the subject matter, as in the consumer example; a distributive word in the main clause, with no tail joined by 'and' ('Each of the four checks is a step in §4.'); a separate sentence that states where the document describes the members ('§4 describes each check.'); quoted material (SPEC §6.3). Distinct from no-cadence-device (SPEC §8.1): a cadence device restates a fact the sentence before it already states, as a verbless fragment or a matched pair of sentences; a distributive tail adds a fact about the document, inside the same sentence. Distinct from vacuous-classification-property (SPEC §7.6): a count signpost states only how many items come directly after it; a distributive tail is a clause joined to a count whose main clause states a fact. Where a sentence states only a count of the items after it, report it under vacuous-classification-property only. A parser can find ', and each' or ', and both' after a count, but telling a property of the layout from a property of the subject matter needs judgement, so this stays inference-based."
```

### 4. COLOPHON.md — fix the now-false count

Line 179, "## Register: a new section, inference-based only" section:
replace `Both rules are inference-based.` with `Every rule in §8 is
inference-based.`. After the paragraph ending `deterministic register
check.` (line 185), add:

```
§8.3, no-distributive-tail, is inference-based for the same reason. A
pattern finds `, and each` after a count. It cannot tell a property of
the document's layout from a property of the subject matter.
```

### Other files

Checked `README.md`, `docs/agent-guide.md`, `docs/claude-md-ruleset.md`,
`templates/`, `vocabulary/`: none lists the rules by name or count.
`vocabulary/banned.tsv` bans "described below", "see below", "as shown
below" — the fix wording above ("described in the steps below") avoids the
banned substrings.

### Commit convention

`Add no-distributive-tail (SPEC §8.3): a distributive tail joined to a
count`, body ending `Closes #19`. Files: `spec/SPEC.md`,
`rules/core-rules.toml`, `COLOPHON.md`.

### Release

No version file in `software-english` itself. Step 7 of
`MAINTAINER-RUN.md`: run `release.yml` with the next patch after the newest
`v*` tag. This change touches `rules/core-rules.toml`, one of the two files
the `swe` plugin fetches, so also: bump the tag in `swe/software-english.json`
to the new release, bump `swe`'s own `version` in `claude-plugins`, push
`claude-plugins` `main`, and run `release-plugin.yml` for `swe`.

## Outcome

Shipped, single pass, no escalation.

- `software-english@4beaf26`: new §8.3 `no-distributive-tail`, the matching
  `core-rules.toml` block, and the `COLOPHON.md` register-section fix.
  `closes #19`; GitHub auto-closed the issue on push.
- Checked before committing: `tomllib` parses the edited `core-rules.toml`
  with no duplicate ids (34 rules); the deterministic tier finds no new
  errors in the added SPEC.md/COLOPHON.md text (ran the real linter with
  the edited checkout copied into a local, gitignored `swe/data/` cache,
  not committed); the located-candidate detector finds no new
  `no-cadence-device` candidate in the new section; a manual inference-tier
  read of the new prose against the plausible siblings (anthropomorphism,
  metaphor, catch-all-verb, entailed-restatement, ownership, framing-device,
  withholding/question heading, and a self-check against its own new rule)
  found nothing; the `decides`/`cannot tell X from Y` phrasing in the
  `COLOPHON.md` addition matches already-shipped phrasing at `SPEC.md:306`
  and `COLOPHON.md:182`. All seven `claude-plugins/swe` test suites pass,
  twice: once with the edited checkout, once again after fetching the real
  released tag (176 assertions, unchanged).
- Released [`v0.0.25`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.25).
- Touches `rules/core-rules.toml`, so also pinned and released `swe`:
  `claude-plugins@fcee923` (tag bump + `swe` version 0.18.4 → 0.18.5),
  released as [`swe-v0.18.5`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.18.5).
  `check-unshipped.sh` clean on both repos afterwards.
- Commented on the issue with the commit and release tags; removed
  `agent:working`.
