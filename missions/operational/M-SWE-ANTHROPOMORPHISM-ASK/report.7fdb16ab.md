# Report: software-english#29

## Outcome

Already fixed, no change. software-english#29 asked for the third-person
present form of *ask* (`asks`) to be added to `anthropomorphism-fixed-list`'s
`word_list`. It already is: commit `0935b1a9f1814de9598230207d7377e7595ab94d`
(2026-10-23, `closes #20`) added it, under the same `not-human-subject` check
`tells`, `says` and `answers` use.

No commit was made to either repository for this issue. No version was
bumped. No release was run.

## What was checked

- `rules/core-rules.toml` on `main` (and on `origin/main`, HEAD `7429f08`):
  `word_list` includes `"asks", "tells", "answers", "says", "disagree",`.
- The claude-plugins `swe` plugin's pinned data (v0.0.33) carries the same
  line.
- Lint runs against the real pinned data:
  - `Every ingredient the recipe asks the cook about, in the order the
    recipe asks it.` → `[anthropomorphism] "asks"` ×2.
  - `The recipe does not ask the cook to preheat.` → `"ask"` (do-support
    base form, software-english#26).
  - `The user asks the recipe.` → no finding (human referent).
- `swe/tests/anthropomorphism_gate_test.sh` already asserts
  `fires: the worker asks the database`. Re-ran the full suite against the
  real `software-english` checkout: 59 passed, 0 failed.

## Observation, not acted on

A plural non-human subject with the bare verb (`The recipes ask the
cook…`) does not fire: `word_list` has no base form `ask`, `tell`, `answer`
or `say` (it does have base/plural forms for the motion verbs and for
`disagree`). The issue asked only for the third-person present form, which
already fires, so this run made no change for the plural case. Noted on the
issue as an observation for Jim, not filed as a new issue.

## Issue closed

jimbarritt/software-english#29, `state_reason: completed`, with a comment
naming the fixing commit (0935b1a9, closes #20) and the existing test
coverage. `agent:working` removed.

## Links

- Issue: https://github.com/jimbarritt/software-english/issues/29
- Comment: https://github.com/jimbarritt/software-english/issues/29#issuecomment-6690794922
- Fixing commit: 0935b1a9f1814de9598230207d7377e7595ab94d (closes #20)
- Test: swe/tests/anthropomorphism_gate_test.sh, line ~87
