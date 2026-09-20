# Issue #4: swe:feedback / swe:send-feedback tooling gaps

Issue: https://github.com/jimbarritt/claude-plugins/issues/4

## Summary

Filed after a session where reporting one piece of meta-feedback about
the feedback tooling itself took five round trips. Two concrete gaps:

1. **`/swe:send-feedback`'s clustering threshold is too strict.**
   Step 2 only raises a candidate pattern for two or more entries
   sharing `rule_id` and `verdict`. A single, clear, well-formed entry
   should be enough to raise for discussion; waiting for an accidental
   second match delays real feedback for no benefit.
2. **No verdict for feedback about the tooling itself.**
   `/swe:feedback` only recognises `false-positive`, `false-negative`,
   `wrong-fix`, all of which assume a specific lint finding exists to
   react to. Feedback like "this skill's own logic is wrong" gets
   forced into `wrong-fix` against a placeholder `rule_id: unknown`,
   which then risks **false clustering**: two unrelated `unknown`
   entries share `rule_id`/`verdict` by accident and look like a
   pattern to Step 2's mechanical grouping, even though they are not.

## Ask (from the issue)

- Change `/swe:send-feedback` Step 2 so any single entry can be raised
  as a candidate pattern, not just entries with a sibling. The user
  still confirms or declines before anything is filed, so this does not
  risk noisy auto-filing.
- Add a fourth verdict to `/swe:feedback`, e.g. `feature-request`, for
  feedback not tied to a specific finding.
- For `rule_id: unknown` entries, stop treating a shared `rule_id`/
  `verdict` alone as clustering evidence: either give each topic a
  distinct placeholder, or always surface a single `unknown` entry
  individually rather than attempting to group it.

## Findings from reading the code

- `skills/feedback/SKILL.md` Step 1 hardcodes the three verdicts and
  rejects anything else. Step 2 branches only on
  `false-positive`/`wrong-fix` (look back for a prior finding) vs.
  `false-negative` (no prior finding, `rule_id: "unknown"`, `source:
  "user-reported"`). A `feature-request` verdict does not fit either
  branch: it has no finding to look back for, and forcing `rule_id:
  "unknown"` on it is exactly the collision the issue reports.
- `skills/send-feedback/SKILL.md` Step 2 clusters purely by
  `(rule_id, verdict)` pairs, with no distinction between a real rule ID
  and the `"unknown"` placeholder. Nothing currently stops two
  unrelated `unknown`/`wrong-fix` entries from clustering.

## Proposed fix direction

1. **`skills/feedback/SKILL.md`**: add `feature-request` as a fourth
   recognised verdict in Step 1. Give it its own path in Step 2 (no
   finding to look back for): `rule_id: null` (not `"unknown"`, so it
   never collides with a real "no rule identified" case), `source:
   "user-reported"`, empty `location`/`quote`, just the note.
2. **`skills/send-feedback/SKILL.md`** Step 2: two changes together.
   - Still cluster entries that share a real `rule_id` (from the actual
     rule catalogues) and `verdict`, for genuine repeated patterns.
   - Any entry that does not land in such a cluster, including every
     `rule_id: null` entry and any singleton with a real `rule_id`, is
     also surfaced in Step 3, one at a time, instead of being silently
     left for a future run. This satisfies the issue's "any single
     entry can be raised" ask without giving up clustering's value for
     entries that do share a genuine rule.
3. Step 4 (filing) already asks the user which repository when
   `rule_id` is `unknown`/not found; extend that to `rule_id: null`
   too, and treat `feature-request` as, by default, not a candidate for
   the `auto-fix-candidate` label (Step 4.3 already asks before
   labelling anything that is not a concrete, scoped rule bug — a
   feature request plainly is not one).

## Open question before implementing

Should a `rule_id: null` clustering key still group multiple
`feature-request` entries that happen to be about the *same* underlying
ask (e.g. two people separately ask for the same new verdict), or
should every `feature-request` entry always surface individually, with
the person doing the judgement call about whether it's a duplicate of
one just discussed? Leaning toward: always individually, since
`feature-request` volume is expected to be low and judgement here is
cheap, but worth confirming before writing it into the skill.

## Status

Not started. Task file only; no code changed yet.

## Next step

Resolve the open question above (or take the "always individually"
default if none is given), then edit both SKILL.md files, then
exercise the flow by hand: log a `feature-request` entry, run
`/swe:send-feedback`, confirm it surfaces on its own.
