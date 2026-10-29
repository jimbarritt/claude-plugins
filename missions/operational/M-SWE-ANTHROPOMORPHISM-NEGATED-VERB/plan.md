# Plan: software-english#26, anthropomorphism misses a fixed-list verb after "does not" / "doesn't"

## The ask (verbatim issue text)

Title: anthropomorphism: fixed-list verb not matched in a negated construction

### Verdict

False negative, `anthropomorphism` (deterministic tier).

### Shape

A fixed-list human-act verb after a negation, with a system as the
subject, gets no finding:

- "A missing scope usually does not say so."
- "The parser never tells you which line failed."

The same verbs are reported in the affirmative ("the parser tells you
which line failed").

### Expected

A finding on "say" and "tells", the same as in the affirmative.

### Proposed fix (issue author's own)

In the `anthropomorphism` matcher, allow an optional negation and an
optional adverb between the subject and the verb: `not`, `does not`,
`do not`, `doesn't`, `never`, `no longer`, plus an adverb such as
`usually` or `always`. Add fixtures for each negated form, and one that
confirms a person as the subject still gets no finding ("the operator
does not say so").

## Reading: what the issue actually needs

The issue's own diagnosis is wrong, so its proposed fix targets the
wrong mechanism. Confirmed by running the linter directly against both
example sentences (after populating `swe/data/` from a local
`software-english` checkout):

- The matcher already tolerates any words between the subject and the
  verb: `subject_gate_passes()` looks back up to `lookback_words` (4)
  words in the current clause, and the literal match is `\bphrase\b`
  wherever it falls. So "The parser never tells you which line failed."
  is **already flagged correctly today** — it is not a live false
  negative. "no longer arrives" is likewise already flagged.
- The real fault is English do-support: after "do not" / "does not" /
  "don't" / "doesn't", the verb takes its **base form** ("say", not
  "says"). `word_list` in `rules/core-rules.toml` holds only inflected
  forms (3rd-person singular, or multi-word gerund-style phrases), never
  base forms, so nothing in the list can ever match "say" or "tell".
  Confirmed false negatives: "does not say", "doesn't tell", "does not
  tell". Confirmed non-bugs: "never tells", "no longer arrives" (no
  do-support triggered, inflected form survives unchanged).

So the fix only needs to handle do-support base forms. `never` and
`no longer` need no code change.

## Decision: option (a), a second targeted regex pass for do-support base forms

Rejected alternatives:

- **(b) add base forms as plain `word_list` entries.** Rejected: a bare
  base form is frequently a noun or an infinitive ("the agreed plan",
  "your own answer", "it is hard to tell", "needless to say"), and the
  existing determiner/gate logic cannot tell those apart from a true
  verb use. This was confirmed by grepping both repos' prose for exactly
  these collisions. It would also start flagging modal forms ("can
  tell"), beyond what the rule does today in the affirmative.
- **(c) lemmatisation.** Rejected: the matcher has no POS/lemma
  infrastructure; `lemma_candidates()` produces multiple guesses, not a
  single reliable base form, and is tuned for vocabulary lookup, not
  rule matching.

**Chosen: (a).** Match the base form only directly after a do-support
negator (`do not` / `does not` / `don't` / `doesn't`), with at most one
optional word in between (covers "does not always say"). The gate check
runs at the negator's position, not the verb's, so the existing 4-word
lookback still sees the real subject.

Scope limits (deliberate, to keep the false-positive surface unchanged):

- **"did not" is out.** `word_list` has no past forms ("said", "told"),
  so flagging "did not say" while "said" itself stays clean would be
  inconsistent.
- **Copula and modal forms are out** ("is not happy", "cannot tell").
  Separate gaps; not raised by this issue.

## File changes

### Repo `jimbarritt/claude-plugins` (all behavioural change lands here)

**1. `swe/scripts/software_english_lint.py`**

- Next to `IMPERATIVE_LEAD` (~line 727), add:
  - `DO_NEGATION` regex: `\b(?:do|does)(?:\s+not|n['’]t)\s+(?:[a-z]+\s+)?`
    (handles the curly apostrophe prose actually uses).
  - `BASE_FORM_IRREGULAR` map: `{"has": "have", "goes": "go", "does": "do"}`.
- Add `do_support_base_forms(word_list)` near `lemma_candidates()`
  (~line 960): for each `word_list` entry, split head word from the
  rest; skip `is` (copula takes no do-support); derive the base form via
  irregular map, then `-ies`→`-y`, then strip trailing `-s` (not `-ss`);
  reattach the rest ("gives up" → "give up"); drop results already
  present in `word_list` (so `arrive`, `come`, `enter`, `leave`, `move`,
  `disagree` are left to the existing literal pass, avoiding double
  reporting).
- In `check_line()` (~lines 1042-1051), add a second loop scoped to
  `anthropomorphism-fixed-list` only (not `abstract-location`): for each
  derived base form, search `DO_NEGATION + re.escape(base) + r"\b"`;
  run `subject_gate_passes()` at the negator's match start (not the
  verb's) so the lookback window isn't consumed by "usually does not
  always"; record the finding keyed to the verb's own span so it
  dedupes against the literal pass and banned-word spans.

**2. `swe/tests/anthropomorphism_gate_test.sh`** — extend with the
fixtures below; add "software-english#26" to the header comment.

**3. `swe/.claude-plugin/plugin.json`** — bump `version` patch
(0.24.8 → 0.24.9) in the same commit as the fix (release step runs
`release-plugin.yml -f plugin=swe` and `scripts/check-unshipped.sh`
afterwards).

### Repo `jimbarritt/software-english` (optional, wording only — no behaviour depends on it)

**4. `rules/core-rules.toml` line 101** (`anthropomorphism-fixed-list`
description): add one sentence documenting the do-support base-form
behaviour, so the catalogue text matches what the matcher actually
does. No change to `word_list`, no new TOML field.

The issue lives in `software-english`; close it by commenting with the
claude-plugins commit/tag, whether or not the optional doc edit lands.

## Fixtures to add (`swe/tests/anthropomorphism_gate_test.sh`)

**Part 1 (real catalogue), new findings (the fix):**
- `fires 'A missing scope usually does not say so.' 'say'` (issue's own case)
- `fires 'The parser does not tell you which line failed.' 'tell'`
- `fires "The cache doesn't know the key." 'know'`
- `fires 'The client doesn’t want the full row.' 'want'` (curly apostrophe)
- `fires 'The workers do not ask the database.' 'ask'`
- `fires 'The retry does not always try again.' 'try'` (adverb-padded, `-ies`)
- `fires 'The parser does not worry about whitespace.' 'worry'`
- `fires 'The handler does not go to the cache.' 'go'` (irregular)
- `fires 'The job does not give up.' 'give up'` (multi-word)
- `fires 'It does not know the row.' 'know'` (pronoun subject)

**Regression fixtures (already pass; lock in "never"/"no longer" need no code):**
- `fires 'The parser never tells you which line failed.' 'tells'`
- `fires 'The record no longer arrives with a default status.' 'arrives'`
- Existing "The schema does not move" fixture (line ~93) still passes,
  with exactly one `[anthropomorphism]` line (no duplicate).

**Human subject stays clean:**
- `clean 'The operator does not say so.'` (required by the issue)
- `clean 'The operator usually does not always say so.'` (proves gate runs at negator)
- `clean 'Users do not know the password.'` (plural human referent)
- `clean "The reviewer doesn't agree."`

**Imperatives stay clean:**
- `clean 'Do not say so.'`
- `clean 'Then do not ask the user.'`

**No base-form false positives (guards against ever moving to option b):**
- `clean 'It is hard to tell which line failed.'`
- `clean 'The agreed plan has three steps.'`
- `clean 'Your own answer is in the log.'`

**Part 2 (scratch catalogue, `word_list = ["knows"]`):**
- `NEW`: `fires 'The database does not know the row.' 'know'`;
  `clean 'The user does not know the row.'`
- `OLD` (no `subject_gate`): `fires 'The database does not know the row.' 'know'`

## Release consequences

- The behavioural fix is entirely in `claude-plugins`; ships with the
  `swe` version bump and its release run. No `software-english` release
  needed for the fix itself.
- If the optional `core-rules.toml` description edit is made, it needs
  a `software-english` release (next patch after the newest `v*` tag),
  and because it touches `rules/core-rules.toml`, `swe/software-english.json`'s
  pinned tag must bump too, with another `swe` version bump and release
  — per the maintainer-run briefing's step 7, handled there.
