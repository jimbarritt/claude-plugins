# software-english#20: anthropomorphism-fixed-list misses motion/communication verbs and proper-noun subjects

[Issue #20](https://github.com/jimbarritt/software-english/issues/20), opened by
`jimbarritt-pleo` (trusted collaborator), labelled `auto-fix-candidate`.

## The ask, verbatim

> Rule: anthropomorphism-fixed-list (SPEC §5.1)
> Verdict: false negative
>
> The deterministic tier passed several sentences in one document that give an
> inanimate subject a human or animate verb. Two gaps cause this.
>
> 1. The word list has no verbs of motion or communication. Examples of the shape:
>
>    - "The record arrives with a default status."
>    - "Both totals arrive as fields on the request."
>    - "The worker asks the database whether the feature is enabled."
>    - "The two parsers disagree on the field type."
>    - "The flag is what tells a generated row from a submitted one."
>
>    "agrees" is listed, "disagrees" is not.
>
> 2. The subject gate fires only when a structure.tsv noun or a pronoun is within
>    lookback_words. A proper-noun subject (a product, vendor or service name) is
>    never a match, so "the database knows about the row" fires and
>    "Postgres knows about the row" does not, although "knows" is listed.
>
> Proposed fix:
>
> - Add motion verbs (arrives, arrive, goes, comes, travels, lands, reaches,
>   enters, leaves) and communication verbs (asks, tells, answers, disagrees,
>   says, replies, complains) to word_list.
> - Invert the subject gate: fire unless the subject is a known human referent
>   (user, customer, person, a personal pronoun), so that a proper noun or any
>   other inanimate subject counts as a system.
> - Keep severity at error. The rule is absolute: no human or animate verb takes
>   an inanimate subject.

## Reading

The rule's deterministic-tier implementation lives in
`claude-plugins/swe/scripts/software_english_lint.py` (`check_line()`,
~lines 731-747), not purely in `software-english`'s data. `word_list` and
`lookback_words` are TOML fields (data, read at runtime from the pinned
`rules/core-rules.toml`), but the subject-gate matching logic —
`SYSTEM_PRONOUNS = {"it", "this", "that"}` and
`HUMAN_SUBJECT_NOUNS = {"user"}` — is hard-coded Python in `claude-plugins`.
So this issue, although filed on `software-english`, needs a coordinated
change across both repos: a data change there, and a logic change in
`claude-plugins`' linter.

An Opus Plan subagent (model `opus`) read both repos' code/data directly —
not just the issue text — and verified every claim against the real linter
run in-process against real TOML/TSV data and real prose in both repos.

### The communication-verb half and the inverted gate are sound, once guarded

The subagent's simulation found the plain fixes proposed in the issue
produce ~60 false positives against this project's own shipped prose if
applied literally (e.g. "the rest of" matching `rest`, "the answers are in
the log" matching a noun use of `answers`, imperatives like "Tell the
user…"). Four guards bring that down to zero against both repos' real
`.md`/`.py`/`.sh` files, while still firing on every one of the issue's own
worked examples:

- clause-scope lookback (stop at `. ! ? ; : , (`, not a flat 40-character
  window);
- no match when nothing precedes it in the clause (covers an imperative:
  "Tell the user…");
- a determiner directly before the match (other than `this`/`that`) means a
  noun use, not a verb with a subject ("the answers");
- a human-referent noun's plural counts, but only above three letters (a
  naive strip read "is" as "i"); a possessive ("the user's database") does
  not count as the subject.

Design: a new per-rule TOML field pair, `subject_gate` (absent = today's
behaviour; `"not-human-subject"` = the new inverted gate) plus
`human_referents` (a word list, following the existing `word_list` pattern
so the data stays in `software-english` and only the generic gate-inversion
*logic* is new Python). `abstract-location`, which shares the same gate code
path, is **not** inverted: the subagent measured 32 new false positives
there (`live`, `stand` in `stand-in`, and similar — each of those verbs
already has a literal/adjectival use, which is exactly why SPEC §5.2
excludes them from a flat list on purpose). The two rules diverge by design
from here on.

Word-list correction found along the way: three of the issue's proposed
words (`disagrees`, `complains`, plus `travels`/`lands`/`reaches`) are
already in `vocabulary/banned.tsv` and banned spans are skipped by this
rule, so adding them would do nothing; the issue's own example ("The two
parsers disagree") needs the plural `disagree`, which its own list omits.
`replies` was dropped: it is a noun in four shipped sites this project
already carries ("longer replies", "chat replies"), and the determiner
guard can't catch an adjective-before-noun use of it.

### The motion-verb half conflicts with text already shipped — verified directly, not just reasoned about

Checked by hand, not taken on the subagent's word alone:

- `vocabulary/banned.tsv` prescribes `arrives` as the correct replacement
  for words this same issue proposes adding to the fixed list:
  `reaches → … arrives at`, `lands → arrives, or is saved`,
  `landed → arrived, or was saved`, `as it comes → as it arrives`.
- `spec/SPEC.md` lines 305-306 state the exclusion directly: a motion verb
  "is not on this rule's list: the subject check cannot tell `the schema
  does not move` from `the file does not move`."
- `claude-plugins#15` added `swe/tests/motion_idiom_test.sh` specifically to
  lock in that these stay clean of `[anthropomorphism]`:
  `"This leaves the file unchanged."`, `"That leaves two options."`,
  `"A read that goes past the end of the file returns an error."` Adding
  `leaves`/`goes` to `word_list` as this issue proposes fires on all three,
  breaking tests written on purpose two issues ago.

The issue's text never mentions `software-english`#15's own exclusion
rationale or `banned.tsv`'s prescribed fixes, so the author may not have
seen the conflict when filing. Implementing the motion-verb half as written
means reversing a design decision taken deliberately in a prior issue, not
merely refining this one (unlike `software-english`#18/#19, where
departures from the issue's own text refined the ask without reversing
shipped decisions).

## What's blocked

Two readings of the issue lead to materially different work (Ground
rules: Escalate condition 1):

- **Reading 1**: the absolute rule as stated overrides `#15`. Add the
  motion verbs, then rewrite six `banned.tsv` fix strings, the SPEC §5.2
  exclusion paragraph and its SPEC §5.5 worked fix text, the
  `abstract-location` TOML description, three `motion_idiom_test.sh`
  guards, and ~15 real prose sites across both repos that the now-listed
  motion verbs would flag.
- **Reading 2**: motion verbs stay at the inference tier, as SPEC §5.2,
  §5.5 and `#15` already say on purpose. Ship only the communication-verb
  additions and the inverted subject gate (still closes the issue's
  stated false negatives: every one of the issue's own worked examples
  fires under this reading too, since none of them use a motion verb from
  the proposed list — the motion examples are "arrives"/"arrive", already
  excluded from this reading, but "asks"/"disagree"/"tells" all fire).

A full plan exists for both readings, detailed enough to implement
verbatim once the question below is answered — see the Plan subagent's
report, summarised in full above, for exact TOML/SPEC.md/Python diffs,
test additions, and the verification/release order. Not copied in full
here to avoid drift between two copies; ask for the plan transcript if
re-deriving it is wanted rather than reusing this summary.

## The one question

> SPEC §5.5 and `banned.tsv` give `arrives` as the fix for `reaches`,
> `lands` and `as it comes`, and `claude-plugins#15` kept `this leaves` and
> `goes past` clean on purpose. Should #20 add the motion verbs and reverse
> those fixes and tests, or keep motion verbs at the inference tier and
> ship only the communication verbs and the inverted gate?

## Jim's answer

Given directly in the escalating session, the same route as #2/#13, not
on the issue: Reading 1. The rule is absolute. No motion verb, and no
human verb or adjective, takes an inanimate subject; an object cannot
carry, hold, travel, or move. Implement it, whatever that takes. Jim
also noted that the `#15` exclusion was not a decision of his own.
Recorded on the issue in a comment before resuming.

## Outcome

Shipped, both halves, single session after the escalation.

**software-english** `0935b1a`, released as v0.0.26, closed the issue
automatically.

- `anthropomorphism-fixed-list`: new catalogue fields
  `subject_gate = "not-human-subject"` and `human_referents` (33 words).
  Fires unless a human referent precedes the match in the same clause;
  a proper noun or a pronoun counts as a system.
- Added `asks`, `tells`, `answers`, `says`, `disagree`, and the motion
  verbs `arrives`, `arrive`, `goes`, `comes`, `come`, `enters`, `enter`,
  `leaves`, `leave`, `moves`, `move`. Not added: `disagrees`,
  `complains`, `travels`, `lands`, `reaches` (already in `banned.tsv`,
  and this rule skips a banned span, so they would do nothing);
  `replies` (a noun in four shipped sentences). `travel` added to
  `banned.tsv` beside `travels`.
- `banned.tsv` no longer gives `arrives` as the fix for `reaches`,
  `land`, `lands`, `landed`, `as they come`, `as it comes`. SPEC §5.1
  rewritten; §5.2's motion-verb exclusion paragraph and §5.5's
  inference-tier motion paragraph restated: only a positional idiom with
  no verb of its own (`pass over`, `behind the serialiser`) stays at the
  inference tier. `abstract-location` keeps the structure-noun check
  (inverting it measured 32 false positives: `live` as an adjective,
  `stand` in `stand-in`, `the rest of`).
- Four guards beyond the issue's text, each measured against both repos'
  real prose (the plain inversion gave about 60 false positives):
  clause-scoped lookback; no finding when nothing precedes the match, or
  only an imperative/infinitive lead (`do not leave a heading empty`,
  `to enter the value`: the `IMPERATIVE_LEAD` set, added after
  `templates/technical-manual.md`'s "do not leave a heading empty"
  fired); a determiner directly before the match marks a noun; a
  possessive is not the subject.
- 42 shipped sentences across both repos reworded (SPEC.md 18 sites,
  COLOPHON.md 3, four templates, the ADR; `claude-plugins` CLAUDE.md,
  README, send-feedback SKILL, two hook comments). Three were my own new
  text, caught only by re-running the linter: a code span wrapped across
  lines in §5.1 and §5.5 (the inline-code mask is per line), and "no word
  comes before the match" in the new TOML description.

**claude-plugins** `3a86371`, released as swe-v0.19.0 (minor: the gate
behaviour changes, not only the pin).

- `subject_gate_passes()` and `is_human_referent()` in
  `software_english_lint.py`; the catalogue switch defaults to the old
  system-subject check, so `commit_check_test`'s scratch catalogue and an
  older pin behave as before. `HUMAN_SUBJECT_NOUNS` now applies to that
  default check only.
- `motion_idiom_test.sh`: the three `#15` guards reversed to `fires`
  (`this leaves the file unchanged`, `the file does not move`, `goes past
  the end of the file`); `where it left off`, `pass over`, `behind the
  proxy` stay clean. New `anthropomorphism_gate_test.sh`, 34 assertions,
  two fixtures (real data, scratch catalogue with and without
  `subject_gate`). One fixture catch: `load_tsv_words()` skips a header
  row, so a scratch TSV needs one.
- Eight suites, 210 assertions, pass twice: with `SWE_SRC` on the local
  checkout, and without it against the fetched v0.0.26. Before/after
  count of `[anthropomorphism]`/`[abstract-location]` findings on every
  tracked `.md`/`.py`/`.sh` in both repos: 1 before (a pre-existing
  `abstract-location` "live" on SPEC.md), 59 after the TOML change
  alone, 1 after the rewording. `--diff --added-only` clean in both
  repos. `check-unshipped` green on `main`.

Two process catches. The `software-english` clone was checked out on the
harness-assigned branch, so the first `git push origin main` was a no-op
("Everything up-to-date"); caught by reading the push output, fixed by a
fast-forward of `main`. The first `release.yml` run failed at "Compute
the tag": the input is plain semver (`0.0.26`), not `v0.0.26`; nothing
was tagged, re-run with the right input. The count script's first run
missed `claude-plugins/.swe-ignore` (it ran from the other repo's
directory), which showed as two phantom `abstract-location` hits in
exempt files; the script now runs each repo from its own root.
