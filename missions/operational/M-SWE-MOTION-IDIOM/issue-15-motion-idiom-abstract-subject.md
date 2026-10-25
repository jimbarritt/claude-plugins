# Issue #15: motion verbs with an abstract subject, sibling of the v0.0.9 transport fix

## The ask, verbatim

> ## Verdict
>
> `false-negative` on `no-metaphor-or-analogy`, after the v0.0.9 transport-metaphor fix.
>
> ## The shape that is missed
>
> An **abstract subject** given a **verb of physical motion or position**. The subject is not data in transit, so the new vehicle-verb group does not apply, but the fault is the same one: a mechanism explained through movement through space rather than stated directly.
>
> Seven instances went into a single document, all of them after a deterministic run reported clean.
>
> Neutral examples showing the same shapes, with the direct form beside each:
>
> | Written | Direct |
> |---|---|
> | the deprecation notice should not go past a reader unnoticed | a reader should not miss the deprecation notice |
> | the published schema does not move | the published schema does not change |
> | the field can be renamed behind the serialiser | the field can be renamed without changing the response |
> | where this leaves the retry policy | what this means for the retry policy |
> | reject the option rather than pass over it | reject the option rather than omit it |
> | add them as they come | add more here |
> | that design comes from the reference implementation | that design is specified in the reference implementation |
>
> ## Why v0.0.9 does not catch these
>
> The transport group added in v0.0.9 keys on the verb naming a vehicle or a mode of travel (`rides on`, `travels`, `piggyback`, `ferry`, `hitch a ride`), which fits the case of a payload moving between components. Here the subject is a decision, a contract, a reader's attention, an argument or a design, and the verbs are ordinary motion verbs, so nothing on the list fires.
>
> ## Proposed fix
>
> Widen the deterministic coverage from vehicle verbs to **motion verbs with an abstract subject**. Several members of that family are genuinely ambiguous and need judgement, but the fixed phrasal ones are formulaic and catchable without it:
>
> - `go past` / `goes past` / `went past`
> - `pass over` / `passes over` / `passed over` (in the sense of omitting)
> - `does not move` / `did not move`, where the subject is a specification, a contract or a decision
> - `where this leaves` + noun
> - `as they come` (in the sense of arriving over time)
> - `behind the` + component name, used for "without changing"
>
> ## Alternative placement, possibly better
>
> This may belong on `abstract-location` rather than `no-metaphor-or-analogy`.
>
> `abstract-location` already fires on `sits`, `stands` and `lands`, which makes it the static-position check for an abstract subject. The family above is its motion counterpart: same subject test, same tier, same class of fault. Adding these there would keep one rule covering "an abstract thing placed or moved in space", rather than splitting the static half and the moving half across two rules.
>
> Maintainer's call which home is right; the deterministic coverage is the substance of the request either way.

Opened by `jimbarritt-pleo` (trusted collaborator), no `agent:go` label needed.

## Reading

Two judgement calls the issue explicitly left open, made without stopping for a
supervisor (an unattended run; the issue's own text frames both as the
maintainer's call, not a blocking question):

1. **Which of the six proposed phrasal shapes are safe to catch
   deterministically**, given the linter's actual mechanism (a `word_list`
   phrase match gated by requiring a structure noun or `it`/`this`/`that`
   within `lookback_words` words *before* the match — no lookahead, so
   anything needing to check what follows a phrase is out of reach).
2. **Where the fix belongs**: `abstract-location` (the sibling static-position
   rule the issue itself points at) or `vocabulary/banned.tsv` (flat,
   ungated), or a mix.

## Plan (from an Opus Plan subagent's read of the real code, tested against
the real linter, not just read)

The subagent ran every candidate through `check_line()` directly, in memory,
against real Software English data, before proposing anything. Result:

- **Kept, in `banned.tsv`** (flat, no subject gate needed — the subject is
  inside the fixed phrase itself): `where this leaves`, `where that leaves`,
  `where does this leave`, `where does that leave`, `as they come`,
  `as it comes`.
- **Dropped, left to the inference tier**: `go past`/`goes past`/`went past`,
  `pass over`/`passes over`/`passed over`, `does not move`/`did not move`,
  `behind the` + component. Each also names a correct, literal operation on
  a structure noun in ordinary technical prose (a second pass over a table,
  a file that does not move to an archive directory, a service that runs
  behind a proxy, a read that goes past end-of-file), verified by testing
  those exact sentences against the real linter, not just asserted.
- **Home**: `banned-word`, not `abstract-location`. Every kept idiom carries
  its subject inside the phrase, so `abstract-location`'s subject-gate
  mechanism doesn't apply to it; every candidate that *would* need the gate
  failed the literal-operation test above. `abstract-location`'s
  `word_list` is unchanged, with one new sentence in its description
  recording why the motion verbs aren't on it, so a future pass doesn't
  re-add them.
- **Documentation**: `no-metaphor-or-analogy`'s description now names the
  new fixed-list idioms and gives the dropped shapes as explicit
  inference-tier examples. SPEC §5.2 gets a cross-reference to §5.5; SPEC
  §5.5 gets both the new fixed-list line and an expanded inference-tier
  paragraph.
- **Scope**: both repos, `software-english` first (the fixed list and its
  documentation live there) then `claude-plugins` (pin bump, plugin version
  bump, a new test proving both directions against real data).
- **Versions**: `software-english` v0.0.9 -> v0.0.10 (released); `swe`
  plugin.json 0.16.0 -> 0.16.1 (released as `swe-v0.16.1`).

Full plan text (exact diffs, file-by-file) is in the Plan subagent's report;
not reproduced here since the actual commits below are the record of what
shipped, and it matched the plan closely.

## What shipped

`software-english` ([`8078f05`](https://github.com/jimbarritt/software-english/commit/8078f05),
released as [`v0.0.10`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.10)):

- `vocabulary/banned.tsv`: new "Motion idiom" group, the six phrases above.
- `rules/core-rules.toml`: `no-metaphor-or-analogy`'s description extended
  with the new fixed-list examples and the four dropped shapes as
  inference-tier examples; `abstract-location`'s description gets one new
  sentence explaining why the dropped motion verbs aren't on its list.
- `spec/SPEC.md` §5.2: cross-reference to §5.5 for the dropped-verb
  reasoning. §5.5: new deterministic-tier paragraph for the fixed motion
  idioms, expanded inference-tier paragraph naming the dropped shapes.

`claude-plugins` ([`6190b17`](https://github.com/jimbarritt/claude-plugins/commit/6190b17),
released as [`swe-v0.16.1`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.16.1)):

- `swe/software-english.json` pin: `v0.0.9` -> `v0.0.10`.
- `swe/.claude-plugin/plugin.json` version: `0.16.0` -> `0.16.1`.
- New `swe/tests/motion_idiom_test.sh`: the first test in this plugin that
  runs the real linter against real Software English data (via
  `SWE_SRC=<checkout>`, or the pinned tag through the existing fetch
  script), rather than a synthetic fixture catalogue. 18 assertions: the
  seven true positives from the kept idioms, five guards proving the same
  words in a literal or non-idiomatic sense stay clean, four guards proving
  the four dropped shapes stay clean on realistic technical sentences, plus
  one precondition and one existing-entry regression check.

One implementation-time correction, not in the plan: the test's `fires()`
and `clean()` helpers originally piped the linter's own stdout straight
into `grep -q`. Under `set -o pipefail`, the linter's own non-zero "a
finding was reported" exit code outranked `grep`'s actual match/no-match
result in the nested pipeline's reported exit status, so every `fires`
assertion read as a failure regardless of whether `grep` matched (and every
`clean` assertion passed regardless, for the same reason in reverse: 10
passed, 8 failed on first run, all 8 the `fires` assertions.) Fixed by
capturing the linter's output to a local variable first, then feeding that
into `grep` via a here-string, so no pipeline segment can carry the
linter's own exit code past `grep`'s.

All six test suites pass (encompassing the existing five plus the new
one). `scripts/check-unshipped.sh` confirms `swe` is released and matches
its tag.

Also surfaced, not fixed here (put in the closing comment on the issue,
not filed separately, at the Ground rules' one-issue-per-run limit):
`abstract-location` itself already false-positives on some real sentences
("Check that the rest of the file is clean." on `rest`; "the process hangs
when the queue is full" on `hangs`; "the service goes live on Monday" on
`live`), and its subject gate has no plural handling (`fields` doesn't
gate). Worth a future issue if it's worth chasing; not raised as a task
file here since it wasn't scoped or investigated further, only noticed
during the probe.

Issue closed automatically by the `software-english` commit's cross-repo
`closes jimbarritt/claude-plugins#15` trailer. Closing comment posted with
the kept/dropped table and reasoning; `agent:working` label removed.
