# Issue #13: transport metaphors missed by no-metaphor-or-analogy

[Issue #13](https://github.com/jimbarritt/claude-plugins/issues/13), filed by
`jimbarritt-pleo`.

## The ask, verbatim

> ## Verdict
>
> `false-negative` on `no-metaphor-or-analogy` (`swe/data/core-rules.toml`,
> inference-based, `check = "model-judgement"`).
>
> ## What was missed
>
> A document was written, linted, reported clean, and shipped to the user
> with this sentence in it:
>
> > So the whole decision is: **does current state ride on the event, or on
> > a topic of its own?**
>
> The user caught it. Data described as "riding on" an event is a transport
> metaphor, exactly what SPEC §5.5 forbids.
>
> A manual sweep of the same document then found seven more the tool had
> passed: `blast radius`, `leans towards`, `size is a wash`, `wins that
> round`, `bite later`, `ships this shape`, `the seam`.
>
> ## Why the tool could not catch it
>
> `no-metaphor-or-analogy` is inference-based, so `software_english_lint.py`
> never evaluates it. Its own docstring is explicit: the script "never
> judges the prose itself". `--force-inference` prints the applicable rules
> and the model applies them.
>
> ## Proposed fix
>
> **Move the formulaic transport metaphors down to the deterministic
> tier**, in `swe/data/banned.tsv`.
>
> Recognising a novel metaphor needs judgement. Recognising "the message
> rides on the topic" does not. When the subject is data, a message, an
> event or a request, this is a closed and frequently used set:
>
> - `ride on`, `rides on`, `riding on`
> - `travel`, `travels`, `travelling`
> - `journey`
> - `land`, `lands`, `landing` (already partly covered)
> - `flow through`
> - `piggyback`
> - `hitch a ride`
> - `carried across` / `ferried`
>
> Each has a plain replacement: *the event includes it*, *the topic
> publishes it*, *the service sends it*, *the consumer receives it*.
>
> This catches the cheap cases at zero inference cost and leaves the
> genuinely novel metaphors to the inference tier, where judgement is
> actually needed.
>
> ## Suggested suffix for the entry
>
> Following the existing `banned.tsv` convention, the replacement hint
> should name the action rather than offer a synonym, since a transport
> metaphor usually has to be rewritten rather than word-swapped:
> `ride on` -> name the mechanism: the event includes it, the topic
> publishes it, the service sends it

## Reading

The issue's own file paths (`swe/data/core-rules.toml`, `swe/data/banned.tsv`)
are stale — that layout does not exist. The real files live in
`jimbarritt/software-english` (the upstream spec repo this repo's linter
fetches at a pinned tag), not in `claude-plugins`:

- `vocabulary/banned.tsv` — the deterministic banned-word list.
- `rules/core-rules.toml` — `no-metaphor-or-analogy` rule entry.
- `spec/SPEC.md` §5.5.

`claude-plugins/swe/scripts/software_english_lint.py`'s `load_banned` loads
every row generically (`\b<phrase>\b`, case-insensitive, no stemming), so no
`claude-plugins` code change is needed. Confirmed: none of the candidate
words already exist in the approved vocabulary files (`operations.tsv`,
`structure.tsv`, `qualities.tsv`, `connectives.tsv`), so there is no
approved-vocabulary conflict. `land`/`lands`, `carry`/`carries`, `flow` and
`journey` are already banned; the matching is whole-word with no stemming,
so `landed`, `carried`, `flows`/`flowed` are not currently caught.

`software-english` has no test harness; `claude-plugins/swe/tests` has no
per-entry banned-word assertions. No test file needs a new assertion.

## Plan (from an Opus Plan subagent's read of the real files)

**`vocabulary/banned.tsv`:**
- Complete existing families in place: add `landed` (after `lands`),
  `carried across` (after `carries`), `flows through` and `flowed through`
  (after `flow`). Not adding bare `flow through`/`travel` as separate
  entries where an existing entry or scope reason already covers/excludes
  them.
- New group at the end of the file (after `load-bearing`), header
  `# Transport metaphor: data, a message, or an event does not travel.
  Name the mechanism.`, with: `ride on`/`rides on`/`riding on`/`rode on`
  (issue's own hint), `travels`/`travelled`/`travelling` (bare `travel`
  dropped — real domain noun, e.g. "travel dates", a `/travel` API),
  `piggyback`/`piggybacks`/`piggybacked`/`piggybacking`, `hitch a
  ride`/`hitches a ride`/`hitching a ride`/`along for the ride`,
  `ferry`/`ferries`/`ferried`/`ferrying`.
- Dropped: `landing` (false-positive risk: "landing page", "landing zone"
  are real terms; `landed` covers the common metaphor). `flow through`
  (already caught by the existing bare `flow` entry). Bare `carried`
  (would fire on "carried out"; kept the phrase `carried across` only,
  same narrow-scope precedent as the existing bare `carry`/`carries`).
  `journey`'s existing `CUT` hint is unchanged — out of scope.
- The issue's non-transport sweep items (`blast radius`, `leans towards`,
  `size is a wash`, `wins that round`, `bite later`, `ships this shape`,
  `the seam`) are not transport metaphors and mostly not formulaic; left
  to the inference tier, not added here. Noted as a possible follow-up
  issue, not filed as part of this fix.

**`rules/core-rules.toml`:** update the `no-metaphor-or-analogy`
description to state that a formulaic transport metaphor is now caught by
`banned-word` via the fixed list, following the same cross-reference
wording pattern already used by `honest-self-qualifier-paraphrase`.

**`spec/SPEC.md`:** §5.5 heading changes from "(Inference-based)" to
"(mixed)", following the precedent already set by §5.6 ("No self-qualifying
'honest' (mixed)"), which has the same fixed-list-plus-paraphrase split.
Update the table of contents anchor to match. Replace the "no fixed word
list applies" sentence with two paragraphs: the deterministic fixed list
(naming the actual words, backticked so they don't self-trigger the lint)
and the remaining inference-based case.

**Decisions made without a supervisor to ask (unattended run, one issue
open per Ground rules, no other route to a decision):**
- Drop `landing` — the Plan subagent's false-positive case (landing
  page/zone) is concrete and the issue itself only listed it as
  "already partly covered", not as the headline case.
- Keep `piggybacking` despite the TCP-term-of-art risk — SPEC's own
  code-span/quote exemption (§6.2/§6.3) already covers the legitimate
  technical use, and the file already bans other words with legitimate
  domain meanings elsewhere (`gate`, `drive`, `hit`).
- Apply the "(mixed)" heading and anchor change — it is factually
  accurate once the fixed list exists, and mirrors an existing
  precedent (§5.6) rather than inventing new SPEC structure.
- Leave `journey`'s `CUT` hint unchanged — the issue did not ask to
  change it, only to leave it as "already partly covered".

**Follow-up (not part of this fix, flagged for the record only):** for
`swe` to pick this change up, someone still needs to tag a new
`software-english` release, then in `claude-plugins` bump the tag in
`swe/software-english.json`, bump `swe/.claude-plugin/plugin.json`
version, and run `release-plugin.yml`. `claude-plugins/CLAUDE.md`
already documents this as a separate release step, not part of fixing
the spec repo, so this issue's own Ship/Release steps apply to
`software-english` only.
