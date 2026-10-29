# Report: software-english#26, anthropomorphism base-form negation fix

## Issue

`jimbarritt/software-english#26`: "anthropomorphism: fixed-list verb not
matched in a negated construction". Opened by `jimbarritt-pleo`.

## What was found

The issue's own diagnosis was slightly off. The matcher
(`anthropomorphism-fixed-list`, `swe/scripts/software_english_lint.py`
in `claude-plugins`) already tolerated words between the subject and
the verb, so "The parser never tells you which line failed." was
already flagged correctly before this change — confirmed by running
the linter directly. The real, confirmed gap: English do-support. After
"do not" / "does not" / "don't" / "doesn't", the verb takes its base
form ("say", not "says"), and `word_list` in
`software-english`'s `rules/core-rules.toml` holds only inflected
forms, so nothing in the list could ever match the base form.

Considered and rejected:
- Adding base forms directly to `word_list` — rejected: a bare base
  form collides with ordinary noun/infinitive uses ("the agreed plan",
  "your own answer", "it is hard to tell"), confirmed by grepping real
  prose in both repos for exactly these collisions.
- Lemmatisation — rejected: the matcher has no POS/lemma
  infrastructure suited to picking one reliable base form.

## What changed

All in `jimbarritt/claude-plugins`, commit `2cb9c2b`:

- `swe/scripts/software_english_lint.py`: added `DO_NEGATION` regex,
  `BASE_FORM_IRREGULAR` map, `do_support_base_forms()`, and a second
  match pass in `check_line()` scoped to `anthropomorphism-fixed-list`
  only. The subject gate runs at the negator's own position (not the
  verb's), so the existing not-human-subject lookback still sees the
  real subject through an intervening adverb ("usually does not always
  say").
- `swe/tests/anthropomorphism_gate_test.sh`: extended from 34 to 59
  fixtures — new do-support positives (say, tell, know, want, ask, try,
  worry, go, give up, pronoun subject), regression fixtures for
  "never"/"no longer" (already correct, no code change needed for
  those), the human-subject exemption under negation, imperatives
  staying clean, and guards against ever adding bare base forms to
  `word_list` (would start matching "the agreed plan", "it is hard to
  tell", "your own answer").
- `swe/.claude-plugin/plugin.json`: version 0.24.8 → 0.24.9.

No change was needed in `software-english` itself: `word_list` and
`rules/core-rules.toml` stay as they are; the fix is entirely in the
matcher code. The optional catalogue-description wording update
mentioned in the plan was skipped as unnecessary — the issue's own
repo is closed directly from the `claude-plugins` commit instead.

## Verification

- `swe/tests/anthropomorphism_gate_test.sh`: 59 passed, 0 failed (run
  with `SWE_SRC=/home/user/software-english`).
- Every other `swe/tests/*.sh` suite: all green, no regressions.
- `scripts/check-unshipped.sh`: clean after release (0.24.9 matches tag
  `swe-v0.24.9`).

## Release

- Commit: `jimbarritt/claude-plugins@2cb9c2b`
  ("anthropomorphism: match a word_list verb's base form after
  do-support", `Closes jimbarritt/software-english#26`).
- Release workflow run: `release-plugin.yml` run #53, `conclusion:
  success`.
- Tag: `swe-v0.24.9`.
- Issue `software-english#26`: closed automatically by the cross-repo
  `Closes` keyword; commented with commit/tag details; `agent:working`
  label removed.

## Scope notes for any follow-up

- "did not say" (past tense) is deliberately out of scope: `word_list`
  has no past forms ("said", "told"), so flagging the past negated form
  while the past affirmative stays clean would be inconsistent.
- Copula and modal negation ("is not happy", "cannot tell") are
  deliberately out of scope — separate gaps, not raised by this issue.
