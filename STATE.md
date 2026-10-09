# State

Last updated: 2026-10-09 21:01 UTC (self-maintaining-repo Routine run:
nothing eligible to claim on `claude-plugins`; only open issue is #16,
still `supervisor`-labelled, no comment newer than the session's own
last comment)

## In progress

None.

## Waiting on others

- The Claude plugin directory's review of `swe`, which Jim submitted on
  2026-10-01. Status: waiting for review. See
  [tasks/future-plugin-directory-listing.md](tasks/future-plugin-directory-listing.md).
  A requested change to `plugin.json` needs a version bump and a release.
- Jim's worked example for the API Design type, expected as a
  `claude-plugins` issue. Checked on 2026-10-01: the newest issue is
  #15, so it has not been filed. See
  [tasks/future-api-design-doc-template.md](tasks/future-api-design-doc-template.md).
- `claude-plugins` issue #16 stays `supervisor`-labelled: checked on
  2026-10-08 and fourteen times on 2026-10-09 (06:02 UTC, 09:02 UTC,
  10:02 UTC, 11:01 UTC, 12:02 UTC, 13:02 UTC, 14:02 UTC, 15:02 UTC,
  16:02 UTC, 17:02 UTC, 18:01 UTC, 19:01 UTC, 20:02 UTC, and again at
  21:01 UTC), no comment newer than the session's own last comment, so
  the self-maintaining-repo Routine left it untouched again.
- Nine open issues directly on `jimbarritt/software-english` (#1-4,
  #6-10), all filed by `jimbarritt-pleo` via `/swe:send-feedback`
  (which routes a rule-engine bug straight there, not to
  `claude-plugins`). This contradicts the self-maintaining-repo
  Routine's own design decision that `claude-plugins` stays the single
  point of contact for filing, so the Routine's unattended claim step
  does not currently reach them, and they are unprocessed. Needs Jim's
  call: see the new "Open questions" entry in
  [tasks/future-self-maintaining-repo.md](tasks/future-self-maintaining-repo.md).

## Next

[tasks/future-model-backed-pre-action-check.md](tasks/future-model-backed-pre-action-check.md)
(a model-backed check before the action, within fixed limits, raised as
[issue #16](https://github.com/jimbarritt/claude-plugins/issues/16) and
escalated by the self-maintaining-repo Routine on 2026-10-02; Jim's call on
2026-10-02 was to defer discussion rather than answer now — the issue
stays `supervisor`-labelled on GitHub, but the topic also lives here so it
surfaces as a planning item; carries the research links the issue cited,
on OpenAPPA and the Jev classifier, not yet read since `jimbarritt/tsk` is
outside this session's repo scope), then
[tasks/future-self-maintaining-repo.md](tasks/future-self-maintaining-repo.md)
(live: the hourly Routine, the four labels, `MAINTAINER-RUN.md`, and
the empty `ALLOWLIST.md` overlay all exist on `claude-plugins` and
`planning`; the first real issue, #9, went through the full loop end
to end on 2026-09-21, single pass, no escalation, released as
`swe-v0.11.1`; the push notification reached Jim's phone and opened
straight to the session, confirmed; two gaps found and fixed along
the way, a fresh Routine session needing `add_repo` for both
repositories before anything else, and the `agent:working` label not
being cleared on close; the two remaining dry runs, a non-collaborator
author and a deliberate escalation, are deferred at Jim's direction,
not run; researched whether comments/commits could show as a
separate bot instead of Jim, per Anthropic's docs the Claude GitHub
App backs a different product, `claude-code-action`, than the cloud
sessions this loop runs on, and the only route found is the GitHub
Actions trigger this plan already passed over, not built; Jim has a
new mission before returning to this), then
[tasks/future-lint-document-profiles.md](tasks/future-lint-document-profiles.md)
(idea only, not scoped — needs a follow-up conversation on the doc-type
list and what "layered"/"filtered" rules means; now has one concrete
case, the API Design type's fenced HTTP/TypeScript content, which the
linter skips entirely today), then
[tasks/future-stop-reply-check.md](tasks/future-stop-reply-check.md)
(resolved for Claude Code already; still open for Copilot CLI — though
worth re-reading with fresh eyes given how much changed in the pass
below; may already be moot or need restating).

## Recently done

- [tasks/future-plugin-directory-listing.md](tasks/future-plugin-directory-listing.md):
  `swe` is submitted to the Claude plugin directory. The blocking
  requirement was an open source license, which the policy article does
  not state; it comes from the directory's submission process. Jim chose
  Apache-2.0, matching `software-english`. Shipped on `claude-plugins`
  `main`: `LICENSE`, then `license` and `author` fields in `swe`'s
  `plugin.json`, then `icon.png` beside it, released as `swe-v0.16.2`,
  `swe-v0.16.3`, and `swe-v0.16.4`. The icon ("swe" in white on black,
  reviewed by Jim) is fixed from the first portal submission, so it does
  not change later. A push collided with the Routine's commits (swe
  0.12.1 to 0.16.1) and merged with one conflict, on the version line.
  Outcome of the review is open.
- `software-english` README, Document types section
  ([`0abecc7`](https://github.com/jimbarritt/software-english/commit/0abecc7)):
  the intro described only the sentence-level rules, and the
  document-type catalogue appeared only as one row of the Structure
  table. A new section before Structure now lists the fourteen types and
  says Software English draws on and references canonical examples of
  them. Jim softened an earlier draft's "does not redefine any of these
  structures", since the Design and API Design types add content of their
  own. README only, no release. No task file.
- [tasks/issue-15-motion-idiom-abstract-subject.md](tasks/issue-15-motion-idiom-abstract-subject.md)
  ([#15](https://github.com/jimbarritt/claude-plugins/issues/15)): seventh
  real issue worked end to end by the self-maintaining-repo Routine, single
  pass, no escalation. `no-metaphor-or-analogy`'s v0.0.9 transport fix
  missed a sibling shape: an abstract subject (a decision, a contract, a
  reader's attention) given an ordinary verb of physical motion or
  position, not a vehicle verb. The issue proposed six phrasal shapes and
  left two judgement calls open to the maintainer (which shapes are safe
  to catch deterministically, and whether the fix belongs on
  `abstract-location` or `banned.tsv`); an Opus Plan subagent tested every
  candidate against the real linter before proposing anything, rather than
  reasoning from the issue's text alone. Kept two, both idioms that carry
  their own subject inside the fixed phrase so no gate is needed ("where
  this/that leaves", "as they/it come(s)"), added to
  `vocabulary/banned.tsv`. Dropped four ("go past", "pass over", "does not
  move", "behind the" + component): each also names a correct, literal
  operation on a structure noun in ordinary technical prose (a second pass
  over a table, a file that does not move to an archive directory, a
  service behind a proxy), confirmed by running those exact sentences
  through the real linter, not just asserted; left to the inference tier,
  named as explicit examples in `no-metaphor-or-analogy`'s description.
  `abstract-location`'s own `word_list` unchanged, since every dropped verb
  fails its literal-operation test too; one new sentence added to its
  description recording why, so a future pass doesn't re-add them. SPEC
  §5.2 and §5.5 updated to match. One implementation-time correction found
  only by actually running the new test, not anticipated in the plan: its
  `fires()`/`clean()` helpers piped the linter's own stdout straight into
  `grep -q`, and under `set -o pipefail` the linter's own non-zero
  "finding reported" exit code outranked `grep`'s real match result in the
  nested pipeline's exit status, so every true-positive assertion read as
  a failure and every guard read as a pass regardless of what `grep` found
  (8 of 18 failed on the first run, all 8 the true-positive assertions).
  Fixed by capturing the linter's output to a variable before grepping it.
  New `swe/tests/motion_idiom_test.sh` is the first test in this plugin to
  run the real linter against real Software English data (via `SWE_SRC` or
  the pinned tag) rather than a synthetic fixture catalogue; 18 assertions,
  all pass, both against a local checkout and against the released tag.
  All six suites pass. Also surfaced, not fixed (put in the issue's
  closing comment, not filed separately, at the one-issue-per-run limit):
  `abstract-location` already false-positives on a few real sentences
  ("the rest of the file", "the process hangs", "goes live on Monday") and
  has no plural handling on its subject gate. Entirely cross-repo, same
  shape as issue #13: shipped on `software-english`'s `main` at
  [`8078f05`](https://github.com/jimbarritt/software-english/commit/8078f05),
  released as
  [`v0.0.10`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.10),
  which closed the issue automatically via a cross-repo `closes` trailer.
  `claude-plugins` pin bumped to that tag and `swe` version `0.16.0` ->
  `0.16.1` on `main` at
  [`6190b17`](https://github.com/jimbarritt/claude-plugins/commit/6190b17),
  released as
  [`swe-v0.16.1`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.16.1).
- [tasks/issue-14-inference-block-findings-shape.md](tasks/issue-14-inference-block-findings-shape.md)
  ([#14](https://github.com/jimbarritt/claude-plugins/issues/14)): sixth
  real issue worked end to end by the self-maintaining-repo Routine, single
  pass, no escalation. `--force-inference`'s inference-rule block printed
  free-text `- rule-id: description` lines, a different shape from a
  deterministic finding, so a findings-shaped grep (the natural thing to
  do on a long file) silently dropped the whole block; this is how a
  metaphor shipped undetected under #13, and the two issues were filed
  minutes apart by the same reporter. Plan from an Opus Plan subagent's
  read of the real code, tests, and docs. Fixed: each applicable rule now
  prints as `label:0: [warning] [rule-id] inference pending: description`
  (line 0 and severity "warning" always, since a pending rule is not
  itself a violation; a rule whose own catalogue severity differs gets
  `(severity on violation: X)` appended), followed by one
  `[inference-pending]` summary line naming the pending count and the
  source's real deterministic counts, all inside the existing
  `===INFERENCE_ADVISED===` fences so the three hooks' strip/extract
  helpers and blocking decisions are unaffected. Also rejected `--count`
  combined with either inference flag (exit 2): that combination returned
  before the block printed and before a nonce minted, so it always
  reported a clean two-tier pass regardless of content, the same failure
  reached a different way, a hole the plan found unprompted while reading
  the code rather than one the issue named. `swe/scripts/software_english_lint.py`,
  `swe/hooks/_lib.sh` and its three callers (message wording only),
  `swe/skills/lint-file/SKILL.md`, `swe/docs/agent-guide.md`, and both
  `swe/tests/commit_check_test.sh` (16 new assertions, including a
  `fixture-multiline` catalogue rule proving a multi-line TOML description
  still prints as one grep-able line) and `swe/tests/hooks_test.sh`
  (fixture updated to the new grammar) all updated; all five suites pass
  (124 assertions, up from 108). Two implementation-time corrections not
  in the plan: the plan's worked example assumed a zero-warning summary
  line, but real prose with no seeded vocabulary trips
  `vocabulary-membership` even on ordinary words, so test expectations
  were written against the linter's actual output; three em dashes
  introduced while writing this fix's own prose (one in `SKILL.md`, caught
  by running `--force-inference` on the file itself; two in the linter's
  own docstring and the `.swe-ignore`'d `agent-guide.md`, caught only by
  grepping the diff directly, since neither is machine-checked) were fixed
  before committing. Entirely within `claude-plugins`; no
  `software-english` change. Version bumped `0.15.1` -> `0.16.0`. Shipped
  on `main` at
  [`337de79`](https://github.com/jimbarritt/claude-plugins/commit/337de79),
  which closed the issue automatically, released as
  [`swe-v0.16.0`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.16.0).
- [tasks/issue-13-transport-metaphor-banned-words.md](tasks/issue-13-transport-metaphor-banned-words.md)
  ([#13](https://github.com/jimbarritt/claude-plugins/issues/13)): fifth
  real issue worked end to end by the self-maintaining-repo Routine, single
  pass, no escalation. `no-metaphor-or-analogy` is inference-based, so
  `software_english_lint.py` never caught formulaic transport metaphors
  ("the event rides on the topic") reported after one shipped undetected.
  The issue's own file paths (`swe/data/...`) were stale; the fix lives
  entirely in `jimbarritt/software-english` (`vocabulary/banned.tsv`,
  `rules/core-rules.toml`, `spec/SPEC.md`), no `claude-plugins` code
  change, since the plugin fetches those files directly. Plan from an
  Opus Plan subagent's read of the real files (confirmed no approved
  vocabulary conflict, confirmed the linter's whole-word/no-stemming
  matching, confirmed no test harness exists in `software-english`). A
  new `# Transport metaphor` group added to `banned.tsv` (`ride on`,
  `travels`/`travelled`/`travelling`, `piggyback` family, `hitch a
  ride`/`along for the ride`, `ferry` family), plus missed inflections on
  the existing `land`/`carry`/`flow` families (`landed`, `carried
  across`, `flows through`/`flowed through`). `no-metaphor-or-analogy`'s
  description and SPEC §5.5 updated to name the fixed list, following the
  mixed-tier pattern §5.6 already uses. Four judgement calls made without
  a supervisor, since this is an unattended run: dropped bare
  `travel`/`landing` (real domain nouns/terms, "travel dates", "landing
  page"), kept `piggybacking` despite being a real TCP term of art
  (SPEC's code-span/quote exemption already covers that use, same
  precedent as `gate`/`drive`/`hit`), applied the "(mixed)" heading
  change (factually accurate once the fixed list exists, mirrors an
  existing precedent rather than inventing new SPEC structure), left
  `journey`'s existing `CUT` hint unchanged (out of scope). The issue's
  own non-transport sweep items (`blast radius`, `the seam`, and so on)
  are not formulaic transport metaphors, left to the inference tier,
  noted as a possible follow-up issue rather than added here. Verified
  directly against the real linter, not just read: the reported sentence
  now fires `banned-word`; `landing page`/`travel service` do not; the
  new SPEC prose introduces zero new lint findings elsewhere in the
  document (diffed error output before/after, identical 12 pre-existing
  findings). All five `claude-plugins` test suites pass (108 assertions,
  unchanged) against the newly fetched pinned data. Shipped on
  `software-english`'s `main` at
  [`7b18340`](https://github.com/jimbarritt/software-english/commit/7b18340),
  released as
  [`v0.0.9`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.9),
  which closed the issue automatically via a cross-repo `closes`
  trailer. `claude-plugins` pin bumped to that tag and `swe` version
  `0.15.0` -> `0.15.1` on `main` at
  [`221e451`](https://github.com/jimbarritt/claude-plugins/commit/221e451),
  released as
  [`swe-v0.15.1`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.15.1).
- [tasks/issue-12-send-feedback-redaction.md](tasks/issue-12-send-feedback-redaction.md)
  ([#12](https://github.com/jimbarritt/claude-plugins/issues/12)):
  fourth real issue worked end to end by the self-maintaining-repo
  Routine, single pass, no escalation. `send-feedback` drafted a
  public GitHub issue straight from a feedback log entry's
  `quote`/`note` fields, which routinely hold private detail
  (employer/project names, ticket ids, verbatim excerpts from internal
  documents) — the log is local, the tracker is not. Shipped the
  issue's items 1-3 in `swe/skills/send-feedback/SKILL.md`: a new
  section stating the redaction rule and its reason, Step 3 reworded
  so a yes only takes an item to a draft (not to publishing it), and
  Step 4 rewritten to show the exact redacted title, body and target
  repository and wait for approval before `gh issue create` runs.
  `swe/README.md` updated to match. Deliberately did not implement
  item 4 (an open question on whether `/swe:feedback`'s log itself
  should also be redacted at capture time, or the archive expired)
  even though the issue asked to decide it first: an Opus Plan
  subagent's read of the real skill files found every answer to item 4
  still needs send-time redaction (existing logs and archives are
  already verbatim; the session drafting an issue can hold private
  context that never passed through the log at all), so this was not
  the "two readings lead to materially different work" escalation
  case. Item 4 split out to
  [tasks/future-feedback-log-confidentiality.md](tasks/future-feedback-log-confidentiality.md),
  and the closing comment on the issue states the reasoning plainly so
  Jim can reopen if he disagrees. One real lint finding (`banned-word`
  on "(see below)") caught by actually running the lint on the edited
  skill file, fixed. All five test suites pass (108 assertions,
  unchanged). Version bumped `0.14.0` -> `0.15.0`. Shipped on `main` at
  [`bc5bb5c`](https://github.com/jimbarritt/claude-plugins/commit/bc5bb5c62d499647e61da0d522865428ece82ddf),
  which closed the issue automatically, released as
  [`swe-v0.15.0`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.15.0).
- [tasks/issue-11-commit-hook-success-line.md](tasks/issue-11-commit-hook-success-line.md)
  ([#11](https://github.com/jimbarritt/claude-plugins/issues/11)):
  third real issue worked end to end by the self-maintaining-repo
  Routine, single pass, no escalation. The pre-commit hook printed on
  failure only; a passing commit now prints one line, naming the
  count of staged markdown files verified and the clean verdict,
  right before the hook's own final `exit 0` so it only shows once
  the commit actually proceeds (after the ledger check and
  `block_on_deterministic`, not before). Every path where nothing was
  checked, or the ledger could not be evaluated (fail-open), stays
  silent as before. Plan came from an Opus Plan subagent read against
  the real hook script; implementation matched it, including bumping
  the hook's own version marker (`swe-commit-check-version: 1` -> `2`)
  so `/swe:install-commit-hook` re-copies it into repositories that
  already have the hook installed. 9 new/updated assertions in
  `swe/tests/commit_check_test.sh`; two em-dashes and two `actually`
  banned-word findings caught by actually running the lint on the
  docs edit, fixed before committing. All five test suites pass (108
  assertions). Version bumped `0.13.0` -> `0.14.0`. Shipped on `main`
  at
  [`c6a68ef`](https://github.com/jimbarritt/claude-plugins/commit/c6a68ef732930e1978fe8ce26281ddfe8dcc102e),
  which closed the issue automatically, released as `swe-v0.14.0`.
- [tasks/issue-10-lint-ledger-nonce.md](tasks/issue-10-lint-ledger-nonce.md)
  ([#10](https://github.com/jimbarritt/claude-plugins/issues/10)):
  second real issue worked end to end by the self-maintaining-repo
  Routine, single pass (aside from two wording-fix rounds caught by
  actually running the checks, not anticipated in the Opus plan). Also
  the first run where an issue's author was a second collaborator, not
  Jim: `list_repository_collaborators` returned only `jimbarritt` at
  first, because `jimbarritt-pleo`'s invite (added the day before) was
  still pending acceptance, and GitHub's collaborators API omits a
  pending invite. Paused and asked Jim directly rather than guessing or
  treating the account as untrusted; he confirmed the invite, a
  re-check then showed it as a collaborator, and the run proceeded.
  `--force-inference` now mints a single-use nonce bound to a file's
  exact git blob id, and `--record-lint-result` requires that nonce
  back (for `clean` and `failed` alike) before writing a ledger row,
  closing the shortcut the issue reported: recording a verdict on an
  earlier, or stale, judgement without re-running Step 4.
  `swe/scripts/software_english_lint.py`, `swe/skills/lint-file/SKILL.md`,
  `swe/docs/agent-guide.md`, and `swe/tests/commit_check_test.sh` (34
  new assertions, a fixture rule catalogue added since
  `--force-inference` needs one to reach the sources loop) all updated;
  all five suites pass (97 assertions). Version bumped `0.12.1` ->
  `0.13.0`. Shipped on `main` at
  [`fd9d3c8`](https://github.com/jimbarritt/claude-plugins/commit/fd9d3c8),
  which closed the issue automatically, released as `swe-v0.13.0`.
- `claude-plugins/CLAUDE.md`
  ([`cb10626`](https://github.com/jimbarritt/claude-plugins/commit/cb10626)):
  a session on this repo sometimes holds a harness-generated "Git
  Development Branch Requirements" block naming an auto-assigned,
  session-specific branch (e.g. `claude/add-repo-xxxxxx`), set at
  session creation and unrelated to this file. It conflicts with this
  file's own "push straight to `main`" convention, and it causes real
  confusion across a few sessions. `CLAUDE.md` now states
  explicitly that its own instruction wins, so a future session does
  not have to resolve the conflict by inference each time. No task
  file: raised and fixed directly in conversation. The root cause (the
  harness auto-assigning a branch at session creation) is outside this
  repo's control; only the in-repo ambiguity is fixed.
- `software-english` "cache" -> "local reference" rename, three rounds
  in one conversation, all at Jim's direction (his rule: a file is a
  "cache" only if it is a byte-for-byte copy of a fetched file; none
  of these are). Round 1
  ([`81c06cb`](https://github.com/jimbarritt/software-english/commit/81c06cb)):
  cut "This file is a cache. It does not replace the canonical
  sources." from the 9 templates that opened with it. Round 2
  ([`8213fec`](https://github.com/jimbarritt/software-english/commit/8213fec)):
  the same cut from all 14 templates' "Verify against the source"
  sections and one stray instance in `research-note.md`'s body;
  `SPEC.md`'s "each cached file states its own last-verified date"
  claim removed since it was no longer true. Round 3
  ([`384aa21`](https://github.com/jimbarritt/software-english/commit/384aa21)):
  "cache"/"cached" renamed to "local reference" everywhere it
  described these written summaries (all 14 template titles, `SPEC.md`
  Appendix F including its table header, `README.md`,
  `docs/agent-guide.md`, `COLOPHON.md`, ADR 1, and
  `core-rules.toml`'s `document-type-template` description). Left
  alone throughout: `vocabulary/structure.tsv` and `operations.tsv`'s
  real dictionary entries for "cache"/"evict", and `SPEC.md`'s own
  example sentences illustrating anthropomorphism and metaphor with a
  generic software cache as the subject (§5.1, §5.5): those describe
  the actual software concept, not this repo's own files. Released as
  `software-english` v0.0.8; `swe` v0.12.1
  ([`45d726c`](https://github.com/jimbarritt/claude-plugins/commit/45d726c))
  picked up the pin bump, since `core-rules.toml` changed. All five
  test suites pass; `scripts/check-unshipped.sh` confirms `swe` is
  released. No task file: prose cleanup raised and done directly in
  conversation, across three follow-up messages after the API Design
  task below shipped.
- [tasks/future-api-design-doc-template.md](tasks/future-api-design-doc-template.md):
  an API Design document type for `software-english`, a
  specialisation of Design, shipped without Jim's worked example
  (his direction: proceed, use the example as a later test case).
  `software-english` v0.0.7
  ([`87062d5`](https://github.com/jimbarritt/software-english/commit/87062d5)):
  `templates/api-design.md` (a cached reference following
  `templates/design.md`'s own pattern), a new "API Design" row in
  `spec/SPEC.md` Appendix F, and both `document-type-template` and
  `no-planning-content-in-reference` in `rules/core-rules.toml`
  updated to name API Design, the part that actually changes the
  judging agent's behaviour (same finding as the Design type's own
  rollout). `swe` v0.12.0
  ([`b98bc62`](https://github.com/jimbarritt/claude-plugins/commit/b98bc62)):
  pin bumped to v0.0.7. All five test suites pass;
  `scripts/check-unshipped.sh` confirms `swe` is released. `v0.0.6`
  on `software-english` was already taken by an earlier, untagged
  commit, so this shipped as `v0.0.7`. The request/response
  fenced-content checks stay deferred to
  [future-lint-document-profiles.md](tasks/future-lint-document-profiles.md),
  unchanged. Jim's worked example is still expected as a
  `claude-plugins` issue; full record in the task file.
- [tasks/issue-9-document-routine-in-readme.md](tasks/issue-9-document-routine-in-readme.md)
  ([#9](https://github.com/jimbarritt/claude-plugins/issues/9)): the
  first real issue worked end to end by the self-maintaining-repo
  Routine itself, single pass, no escalation. Added a "What happens to
  an issue filed here" section to `swe/README.md`, describing the
  Routine's mechanism and pointing to
  `tasks/future-self-maintaining-repo.md` on `planning` for the full
  design. Documentation only; `swe` version bumped `0.11.0` ->
  `0.11.1` and released as `swe-v0.11.1`. Shipped on `main` at
  [`dbf434d`](https://github.com/jimbarritt/claude-plugins/commit/dbf434d25400f24a9b791693c276073b63a3f8e),
  which closed the issue automatically.
- `software-english` v0.0.5: `rules/core-rules.yaml` is now generated
  from `core-rules.toml` by `scripts/generate-rules-yaml.py`, with CI
  checking it stays generated. It had drifted to 10 of 20 rules, a
  section reference the TOML had moved, and a header describing an
  implementation that changed at v0.5.0. The round-trip check caught
  the generator folding `learning-oriented` into `learning- oriented`
  on its first run, which would have corrupted three rule descriptions
  invisibly. No `swe` release: nothing the plugin fetches differs
  between v0.0.4 and v0.0.5, so the pin stays put. Full record in
  [tasks/issue-7-8-design-type-and-style-cost.md](tasks/issue-7-8-design-type-and-style-cost.md).
- [tasks/issue-7-8-design-type-and-style-cost.md](tasks/issue-7-8-design-type-and-style-cost.md)
  ([#7](https://github.com/jimbarritt/claude-plugins/issues/7),
  [#8](https://github.com/jimbarritt/claude-plugins/issues/8)): two
  issues shipped together as `swe` v0.11.0. #7 put the output style's
  measured cost in the README (6% to 11% more input tokens per turn,
  no latency cost established). #8 added a Design document type to
  `software-english` (v0.0.4), by reference to IEEE Std 1016-2009 and
  Ubl's "Design Docs at Google", so a design document's open-questions
  and future-extension sections stop drawing a
  `no-planning-content-in-reference` finding on every entry. The part
  that changes behaviour is in the two rule descriptions, since
  `rules/core-rules.toml` and the vocabulary are the only files the
  plugin fetches: the judging agent never reads `templates/` or
  `SPEC.md`. Left open deliberately: `core-rules.yaml` is stale, at 10
  of 20 rules with a wrong section reference, and whether to delete or
  generate it is Jim's call.

- [tasks/issue-lint-file-invisible-copilot.md](tasks/issue-lint-file-invisible-copilot.md):
  `/swe:lint-file` was invisible to GitHub Copilot CLI from v0.7.0 to
  v0.10.0, while every other skill in the same plugin loaded. Its
  frontmatter description held `on demand: `, a colon then a space
  inside an unquoted plain YAML scalar, which a strict parser rejects
  outright. Claude Code's parser accepts it, so the fault never showed
  locally. Fixed with a comma (not quotes, which a split-on-first-colon
  harness would carry into the description), guarded by a new
  `tests/skill_frontmatter_test.sh` covering every frontmatter block in
  the plugin, and documented in `docs/agent-guide.md`. Two wrong
  theories preceded it, both about Copilot CLI's own behaviour; parsing
  the files settled it. Released as `swe-v0.10.1`, on `main` at
  [`9479980`](https://github.com/jimbarritt/claude-plugins/commit/9479980).
- [tasks/future-precommit-lint-gate.md](tasks/future-precommit-lint-gate.md):
  a git pre-commit check (`/swe:install-commit-hook`) that blocks a
  commit staging a markdown file unless `/swe:lint-file` already
  recorded a `clean` verdict for that file's exact staged content (git
  blob id, not a path or mtime), via a new repository-local NDJSON
  ledger under `.git/` and a new `--record-lint-result` flag on the
  linter. Deliberately not merged into the existing, global
  `~/.claude/swe/inference-state.json` throttle: different scope,
  different question answered. Designed by an opus-model agent against
  the real code, then implemented with two corrections found only
  during implementation: the design's own "commit gate" terminology
  violated Software English's own banned-word list (renamed to "commit
  check" throughout), and the installed hook's extensionless filename
  (`git` requires the literal name `pre-commit`) meant the linter's own
  extension-based dispatch was linting the whole script as prose, not
  bash comments, fixed by naming the plugin's own source copy
  `pre-commit.sh`. New 34-assertion test suite; all three prior suites
  still pass. Version bumped to 0.10.0, released as `swe-v0.10.0`.
  Shipped on `main` at
  [`af7dfdc`](https://github.com/jimbarritt/claude-plugins/commit/af7dfdc).
- Release tooling, plus a first real release of each repo. Added
  `workflow_dispatch`-only GitHub Actions workflows (triggered from
  here, on demand, never on push) that tag and release:
  - `claude-plugins/.github/workflows/release-plugin.yml`: takes a
    `plugin` input (default `swe`), reads that plugin's version
    straight out of its own `.claude-plugin/plugin.json`, tags
    `<plugin>-v<version>`, refuses to re-tag an existing version,
    creates a GitHub Release with notes scoped to that plugin's own
    previous tag (not the repo's last tag generally, so a second
    plugin's tags don't pollute each other's changelogs later).
  - `software-english/.github/workflows/release.yml`: that repo has
    no version-bearing manifest, so version is a typed input instead;
    same tag/refuse/scoped-notes shape otherwise, plain `v<version>`
    (single-product repo, no plugin prefix needed).
  Used them for real: `swe-v0.9.0` (first-ever release, plugin
  already at that version, never previously tagged), then
  `software-english`'s `v0.0.3` (the load-bearing ban commit that
  was sitting on `main` unreleased, plus an already-existing but
  never-pushed local `v0.0.3` tag from an earlier session, discarded
  in favour of letting the new workflow create the authoritative one).
  `swe/software-english.json`'s pin bumped to that tag, fetched and
  verified locally (the deterministic tier now catches "load-bearing"
  directly), then `swe-v0.9.1` released to carry the update. All on
  `main` at
  [`4b8cd38`](https://github.com/jimbarritt/claude-plugins/commit/4b8cd38)
  (workflow),
  [`1e0acf6`](https://github.com/jimbarritt/claude-plugins/commit/1e0acf6)
  (pin bump + version), and `software-english`'s
  [`20ec1e3`](https://github.com/jimbarritt/software-english/commit/20ec1e3)
  (workflow). No task file: infrastructure work raised and done
  directly in conversation, not from an issue.
- [tasks/issue-5-gh-session-scope-friction.md](tasks/issue-5-gh-session-scope-friction.md)
  ([issue #5](https://github.com/jimbarritt/claude-plugins/issues/5)):
  `gh issue create` is refused until the target repo is attached to
  the session's GitHub scope. Not a claude-plugins code fix (harness
  behaviour, flagged for escalation elsewhere per the issue itself);
  the actionable scope was a one-line note in
  `send-feedback/SKILL.md` Step 4, near the `gh issue create` call,
  so a future run recognises the denial and knows the fix
  (`add_repo`, then retry). Lint run on the edited file caught one
  real finding (`banned-word` on "refuses"), fixed; the file's
  pre-existing `vocabulary-membership` warnings (~344, spread
  through the whole document) are unrelated to this change,
  confirmed by linting the pre-edit version separately. All three
  test suites pass. Shipped on `main` at
  [`7e7abdd`](https://github.com/jimbarritt/claude-plugins/commit/7e7abdd),
  which closed the issue automatically.
- [tasks/issue-4-feedback-tooling-gaps.md](tasks/issue-4-feedback-tooling-gaps.md):
  `/swe:feedback` gained a fourth verdict, `feature-request`, for
  feedback about the tooling itself, logged with `rule_id: null` (not
  the string `"unknown"`, which already means something else).
  `/swe:send-feedback`'s Step 2 now only clusters by a real `rule_id`;
  a placeholder (`null` or `"unknown"`) always surfaces its entries
  individually, closing the false-clustering bug the issue reported
  directly, and a singleton with a real `rule_id` is raised too,
  instead of waiting for a sibling. Took the task file's own "always
  individually" default for the one open question left in it, rather
  than stopping to ask again, since Jim's instruction ("do the
  feedback gaps, this is important") read as wanting execution.
  Verified against a scratch fixture, dry-run through the skill's own
  Steps 1-3 with no real GitHub calls: four distinct items came out,
  not the false-cluster bug. Full lint run over both edited skill
  files and the two docs referencing the verdict list; fixed what it
  found. All three test suites pass. Version bumped to 0.9.0. Shipped
  on `main` at
  [`233ee3d`](https://github.com/jimbarritt/claude-plugins/commit/233ee3d),
  which closed the issue automatically.

- Three-part removal, decided in one conversation and shipped in one
  commit: the `Stop` hook, the `PostToolUse` (`file-check.sh`) hook,
  and `force-for-plugin` on the output style. Jim asked to review the
  Stop hook's actual purpose before fixing issue #6's ~2s delay;
  found its reply check was already unconditionally dead under Claude
  Code (the output style was assumed to cover it), leaving only a
  once-per-turn markdown diff for that cost. Verdict: overbuilt from
  before the output style existed, remove rather than fix. Once that
  landed, `file-check.sh` (which deferred to the Stop hook for tracked
  markdown) went the same way — "output style is already doing
  something like this," `/swe:lint-file` covers on-demand checking —
  and `force-for-plugin` came off in the same pass, since its own
  justification (the Stop hook's reactive fallback) no longer existed.
  This also resolved `future-remove-force-for-plugin.md`'s open
  question, which depended on that same fallback.
  Net effect: no automatic checking of a file edit or a chat reply
  anymore, on either harness. `bash-check.sh`, `artifact-check.sh`,
  `mcp-send-check.sh` unaffected. Every doc/test reference to the
  removed hooks and flag updated in the same commit; full lint run
  over every touched file with real prose (README.md, the feedback
  skill), two findings fixed (a contrastive-framing warning, an
  overlong frontmatter description). All three test suites pass.
  Version bumped to 0.8.0. Shipped on `main` at
  [`cec8f1a`](https://github.com/jimbarritt/claude-plugins/commit/cec8f1a).
  Issue #6 closed with a comment explaining the actual resolution
  (the commit itself carried no `closes #6` trailer, since the fix
  ended up different from what was planned when the message was
  written). Full record split across
  [`issue-6-stop-hook-delay.md`](tasks/issue-6-stop-hook-delay.md),
  [`future-remove-force-for-plugin.md`](tasks/future-remove-force-for-plugin.md),
  and the new
  [`future-remove-file-check-hook.md`](tasks/future-remove-file-check-hook.md).
- The inference-tier mechanics discussion resolved by removing the
  subprocess entirely, at Jim's direction, once he pointed out
  `software_english_lint.py` should never spawn a process at all
  (everything here already runs inside a skill or a hook-dispatched
  subagent, which already has a model attached). `run_inference()`,
  `build_inference_prompt()`, and the `claude -p --safe-mode` call are
  gone; `--advise-inference`/`--force-inference` now both print a
  fenced `===INFERENCE_ADVISED===` rules block instead of running
  anything, gated for the former, unconditional for the latter. Every
  caller (the four hooks' dispatched subagent, `/swe:lint-file`'s own
  session) judges the prose against those rules directly, in its own
  context, deliberately not isolated from it the way `--safe-mode` used
  to be. `bash-check.sh`/`mcp-send-check.sh` no longer need a scratch
  file, since the checked text goes straight into the advisory message.
  `config.json`'s `fast_model`/`model_call_timeout_seconds` are gone
  too, dead once there was no subprocess to configure.
  `send-feedback/SKILL.md`'s stalled-call pattern detection is gone,
  since there is no longer a call to stall. Caught and fixed several
  deterministic-tier findings (em dashes, a banned word, two overlong
  frontmatter descriptions) in files this touched, by actually running
  the full lint over them rather than assuming they were clean. Version
  bumped to 0.7.0. Shipped on `main` at
  [`bd9edac`](https://github.com/jimbarritt/claude-plugins/commit/bd9edac).
- Small follow-ups after the inference-tier rework shipped: the output
  style's picker description revised twice more at Jim's direction
  (added the spec URL, then made it a real clickable `https://` link);
  `swe/README.md` brought current with the rework (subagent-dispatch
  mechanism named explicitly, a stale duplicate closing line cut) and
  then actually run through the plugin's own full lint as asked — caught
  four em dashes that edit itself introduced (fixed) and one
  `banned-word` false positive on "Drive" in "Slack/Gmail/Drive" (the
  product name, not the verb; logged via `/swe:feedback`, text left as
  is). Shipped on `main` at
  [`4a75dfe`](https://github.com/jimbarritt/claude-plugins/commit/4a75dfe),
  [`a53b53d`](https://github.com/jimbarritt/claude-plugins/commit/a53b53d),
  [`bed5dec`](https://github.com/jimbarritt/claude-plugins/commit/bed5dec),
  [`b3b1732`](https://github.com/jimbarritt/claude-plugins/commit/b3b1732).
- [tasks/future-inference-tier-rework.md](tasks/future-inference-tier-rework.md):
  both ideas shipped together. Idea 1: the four non-`Stop` hooks no
  longer call `claude -p --safe-mode` themselves; each calls the
  linter with a new `--advise-inference` flag, which only decides
  whether a fresh pass is worth dispatching, and the hook turns that
  into a non-blocking advisory hook response telling Claude to
  dispatch a subagent to run the real check and report back. Idea 2:
  a single named file is throttled by growth since its last recorded
  `--force-inference` pass (`~/.claude/swe/inference-state.json`), not
  a flat per-edit threshold, so a file with known outstanding findings
  is not re-advised on every follow-up fix. Also fixed the output
  style's picker description (Jim's second ask this session). Both
  existing test suites pass; a new
  `tests/inference_eligible_test.sh` covers the throttle directly.
  Shipped on `main` at
  [`3108620`](https://github.com/jimbarritt/claude-plugins/commit/3108620).
- [tasks/future-plugin-rename.md](tasks/future-plugin-rename.md): renamed
  the plugin `software-english-lint` -> `swe` and dropped the `swe-`
  prefix from each command, so the picker shows `swe:feedback` instead
  of `software-english-lint:swe-feedback`. Full scope from the task
  file applied, including the directory rename, the three skill
  directory renames, the local state paths under `~/.claude/`, and
  every cross-reference in the docs. Both test suites pass. Shipped on
  `main` at
  [`b27f7e5`](https://github.com/jimbarritt/claude-plugins/commit/b27f7e5).
- [tasks/future-lint-command.md](tasks/future-lint-command.md): a new
  `/swe-lint-file` command runs a full lint (deterministic tier plus a
  forced, ungated inference tier) on a named file, on demand. Added
  `--force-inference` to the linter for it; `--run-inference`'s gate,
  used by the four hooks, is unchanged. Shipped on `main` at
  [`b06d0fc`](https://github.com/jimbarritt/claude-plugins/commit/b06d0fc).
- [tasks/issue-3-data-fetch-crash.md](tasks/issue-3-data-fetch-crash.md)
  ([issue #3](https://github.com/jimbarritt/claude-plugins/issues/3)):
  a cloud session's egress policy blocked the plugin's raw-HTTPS data
  fetch, and the linter crashed instead of failing open, which blocked
  every turn. Fixed (git-clone-based fetch, plus a real fail-open path
  in the linter) and shipped on `main` at
  [`6f08705`](https://github.com/jimbarritt/claude-plugins/commit/6f08705),
  closing the issue automatically. Diagnosed and fixed in one pass, no
  design discussion needed.
- [tasks/future-swe-output-style.md](tasks/future-swe-output-style.md):
  a plugin output style, forced on with `force-for-plugin: true`, puts
  Software English's rules directly in the system prompt. Claude
  Code's `stop-check.sh` reply/transcript check now skips outright;
  Copilot CLI, which has no output-style mechanism, keeps it unchanged.
  Shipped on `main`, pushed.
- [Issue #2](https://github.com/jimbarritt/claude-plugins/issues/2):
  `software-english-lint` per-hook enable/disable. Shipped on `main` at
  [`36391c4`](https://github.com/jimbarritt/claude-plugins/commit/36391c4),
  which closed the issue automatically. See
  [tasks/issue-2-per-hook-toggle.md](tasks/issue-2-per-hook-toggle.md)
  for the full record, including a jq gotcha the new unit test caught.

See [tasks/index.md](tasks/index.md) for the full task list.

## Repos in scope

- `jimbarritt/claude-plugins` - primary repo for this work.
- `jimbarritt/software-english` - upstream spec repo, changed when a
  plugins-repo task needs a spec change.
