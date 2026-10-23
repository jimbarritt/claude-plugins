# State

Last updated: 2026-10-23 (software-english#21 claimed, planned)

## In progress

- [software-english#21](https://github.com/jimbarritt/software-english/issues/21)
  ("define-before-use and related rules: three mechanical candidates missed
  in one opening sentence"), claimed by the self-maintaining-repo Routine.
  Plan from an Opus Plan subagent, corpus-tested against both repos' real
  `.md` files; see
  [tasks/software-english-issue-21-define-before-use-count-list.md](tasks/software-english-issue-21-define-before-use-count-list.md).
  Not yet implemented.

## Waiting on others

- The Claude plugin directory's review of `swe`, which Jim submitted on
  2026-10-01. Status: waiting for review. See
  [tasks/future-plugin-directory-listing.md](tasks/future-plugin-directory-listing.md).
  A requested change to `plugin.json` needs a version bump and a release.
- Jim's worked example for the API Design type, expected as a
  `claude-plugins` issue. Checked on 2026-10-01: the newest issue is
  #15, so it has not been filed. See
  [tasks/future-api-design-doc-template.md](tasks/future-api-design-doc-template.md).
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

- [tasks/issue-20-unit-worklist.md](tasks/issue-20-unit-worklist.md)
  ([#20](https://github.com/jimbarritt/claude-plugins/issues/20), opened by
  `jimbarritt-pleo`): eleventh real `claude-plugins` issue worked end to end
  by the self-maintaining-repo Routine, single pass, no escalation. The
  nonce proved a `clean` verdict was recorded against the file's exact
  current blob, but nothing proved the judging pass had covered the whole
  file rather than one edited section. Plan from an Opus Plan subagent,
  which read the real nonce/ledger code and the existing exit-4 convention
  before proposing anything; the plan flagged eight open questions with a
  recommendation for each, decided by this session (one coherent reading,
  not two materially different ones) rather than escalated, all documented
  in the task file. New `prose_units()` (one unit per heading, paragraph,
  top-level list item — a nested bullet or continuation line folds into its
  parent item, not a separate unit — or table; reuses `register_blocks()`'s
  own parse, so "outside a code fence" matches the existing candidate
  detectors exactly) and `format_unit_worklist()`, wired into
  `--force-inference`'s single-file case only (the only case that mints a
  nonce): the rule block gains a numbered `[inference-unit]` worklist after
  every rule's own lines, and a `swe-lint-units: M` total prints just before
  the nonce. The nonce entry itself now stores `units`. New required
  `--record-lint-result` flag `--units-judged`, `"N"` or `"N of M"` (quoted);
  a mismatch against the nonce's own stored total exits 4, the same
  convention a stale nonce already used, and — unlike the four pre-existing
  nonce checks — also consumes the nonce, since the mismatch itself proves
  the caller did not walk the real worklist for this blob. A `clean` verdict
  with a partial count records `partial` in the ledger, not `clean`; a
  `failed` verdict always records `failed` regardless of coverage. The
  pre-commit hook needed no change: it already blocks on anything but
  `clean`. New `swe/tests/unit_worklist_test.sh` (47 assertions);
  `swe/tests/commit_check_test.sh` updated throughout, since every
  in-repository `--record-lint-result` call now needs `--units-judged` —
  its `nonce_for()` helper changed to capture both the nonce and the units
  total from one `--force-inference` run, since a second run would
  supersede the first nonce. All ten suites pass, verified both locally and
  against the real fetched `swe-v0.21.0` tag. `swe/skills/lint-file/SKILL.md`,
  `swe/docs/agent-guide.md`, and `swe/README.md` updated; two self-check
  catches in `SKILL.md`, both found only by running the real linter
  ("actually" a banned word, "is missing" tripping `no-continuous-tense`
  despite being adjectival — the same recurring false-positive shape prior
  task files record for that rule). Version bumped `0.20.0` -> `0.21.0`.
  Shipped on `main` at
  [`719a8a9`](https://github.com/jimbarritt/claude-plugins/commit/719a8a9c29322156098e76c06a196704feb05e5d),
  which closed the issue automatically, released as
  [`swe-v0.21.0`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.21.0).
  `agent:working` label removed on close. `software-english`#21, filed a
  few minutes after this issue by the same author, left unclaimed — one
  issue per run.
- [tasks/issue-19-definite-phrase-candidates.md](tasks/issue-19-definite-phrase-candidates.md)
  ([#19](https://github.com/jimbarritt/claude-plugins/issues/19), opened by
  `jimbarritt-pleo`): tenth real `claude-plugins` issue worked end to end by
  the self-maintaining-repo Routine, single pass, no escalation. Neither
  `no-unanchored-reference` (SPEC §7.5) nor `no-unstated-presupposition`
  (SPEC §7.19) is model-judgement-only pointed at anything, so a document
  whose opening sentence was a verbless colon list of fresh definite noun
  phrases passed `/swe:lint-file` clean, with no candidate for the model
  pass to check on a long file. Plan from an Opus Plan subagent, which read
  the #18 located-candidate precedent and both rules' real catalogue text
  before proposing anything. New `find_definite_first_mentions()`: one
  forward pass tracking every token's lemma seen so far (title and headings
  included) over `definite_segments()` (phrase-bounded chunks of
  `prose_lines()`'s output); a `the`/`these`/`those`/`both the` phrase whose
  head noun hasn't occurred earlier is a candidate, routed to
  `no-unstated-presupposition` when it carries a cardinal, otherwise to
  `no-unanchored-reference`, matching the catalogue's own stated precedence
  between the two. Wired into #18's existing `find_register_candidates()`
  dispatcher and `===INFERENCE_ADVISED===` printer unchanged: same
  `candidate at line N` format, same 20-per-rule cap, same never-a-finding
  invariants. One deviation from the plan's own literal algorithm, forced by
  the real corpus: a bare `both` was excluded from starting a phrase unless
  immediately followed by `the`, since every bare-`both` hit in this repo's
  and `software-english`'s own real prose was a correlative/pronoun use
  ("both existed here", "both match"), not a determiner, and the detector
  has no verb lexicon to tell the two apart. Two minor residual noise cases
  accepted as inherent to a no-POS-tagger design rather than special-cased: a
  compound-noun head reads as its first word ("the retry queue" -> head
  "retry"), and one elliptical "the two" picked up a following adverb as its
  head. No `software-english` change: both rules' existing `check`,
  `severity`, and precedence text already covered this signal, as the plan
  anticipated. New `swe/tests/definite_phrase_candidates_test.sh` (35
  assertions); `register_candidates_test.sh` edited since both new rules now
  legitimately fire on real prose by design (unlike #18's narrow structural
  patterns) — its true-negative sweep narrowed to the #18 rule ids only, its
  exact "1 located candidate(s)" assertion relaxed to a pattern; all nine
  suites pass (re-verified independently by this session, not just the
  implementing subagent). Corpus sweep across both repos' real `.md` files
  found candidates on every file, several hitting the 20-cap
  (`agent-guide.md`, `SPEC.md`, `pull-request.md`), ~20 spot-checked by eye
  as genuinely plausible signals — expected and correct, unlike #18's
  narrower patterns, since these are general prose rules. The issue's own
  "optional high-precision" blocking check deliberately not built: it would
  break the located-candidate invariant and needs a `software-english`
  schema change out of scope. Version bumped `0.19.0` -> `0.20.0`. Shipped
  on `main` at
  [`cf3f6ca`](https://github.com/jimbarritt/claude-plugins/commit/cf3f6cad9fced264db2133db81f98c7b12784ddb),
  which closed the issue automatically, released as
  [`swe-v0.20.0`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.20.0).
  `agent:working` label removed on close. `claude-plugins`#20 and
  `software-english`#21, both filed the same day a few minutes after #19 by
  the same author, left unclaimed — one issue per run.
- [tasks/software-english-issue-20-anthropomorphism-gate.md](tasks/software-english-issue-20-anthropomorphism-gate.md)
  ([#20](https://github.com/jimbarritt/software-english/issues/20), opened
  by `jimbarritt-pleo`): `anthropomorphism-fixed-list` passed any
  proper-noun subject (`Postgres knows about the row`) and every verb of
  motion or communication, since the word list had neither and the subject
  check fired only on a structure noun or a pronoun. The first
  `software-english` issue whose fix spans both repos: `word_list` is
  catalogue data, but the subject check is Python in `claude-plugins`.
  Escalated first, the Routine's first real escalation since #16: the
  motion-verb half contradicted `banned.tsv`'s own `arrives` fixes, SPEC
  §5.2's deliberate exclusion, and `claude-plugins#15`'s test guards. Jim's
  answer, in the session: the rule is absolute, an object cannot move,
  implement it. Shipped both halves. New catalogue fields `subject_gate`
  and `human_referents`; the linter fires unless a human referent precedes
  the match in the same clause, with four measured guards (clause scope,
  imperative lead, determiner-before, possessive) that took the plain
  inversion from about 60 false positives on both repos' real prose to
  zero. `abstract-location` keeps the old check (32 false positives
  measured on inversion). `banned.tsv` no longer offers `arrives` as a
  fix; the `#15` guards reversed; 42 shipped sentences reworded. Released
  `software-english` [v0.0.26](https://github.com/jimbarritt/software-english/releases/tag/v0.0.26)
  ([`0935b1a`](https://github.com/jimbarritt/software-english/commit/0935b1a9f1814de9598230207d7377e7595ab94d))
  and `swe` 0.18.5 -> 0.19.0,
  [swe-v0.19.0](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.19.0)
  ([`3a86371`](https://github.com/jimbarritt/claude-plugins/commit/3a86371adef28d7440de52aab788d6f4f3bc1ff8)),
  minor since the gate behaviour changes. New
  `anthropomorphism_gate_test.sh` (34 assertions); eight suites, 210
  assertions, pass against the fetched tag. Two process catches recorded
  in the task file: the `software-english` clone sat on the harness
  branch, so the first push to `main` was a no-op; `release.yml` takes
  `0.0.26`, not `v0.0.26`. `claude-plugins`#19/#20 and
  `software-english`#21 left unclaimed, one issue per run.
- [tasks/software-english-issue-19-distributive-tail.md](tasks/software-english-issue-19-distributive-tail.md)
  ([#19](https://github.com/jimbarritt/software-english/issues/19), opened
  by `jimbarritt-pleo`): a sentence stating a count or a set, followed by a
  clause coordinated with `and` that distributes a property over the
  members (`and each is ...`, `and both do ...`), where that property is a
  fact about the document's own layout rather than the subject matter. Plan
  from an Opus Plan subagent, which read SPEC §8 in full and §7.6 before
  proposing anything. Two corrections to the issue's own proposed fix and
  test, both forced by the issue's own stated rule: the repair sentence
  keeps the fact "run on upload", which the issue's own repair dropped,
  breaking its own "loses no fact" test and turning the sentence into a
  §7.6 count signpost once a list follows directly; and the test needed a
  first step checking that the property is about layout, not subject
  matter, since "loses no fact" alone does not separate the fault from the
  issue's own correct counter-example. New standalone rule
  `no-distributive-tail` (SPEC §8.3), third in the §8 register-rules
  family alongside `no-cadence-device` (§8.1) and `no-mechanical-repetition`
  (§8.2), inference-based for the same reason as its siblings: a parser can
  find the `, and each`/`, and both` coordination, but not whether the
  distributed property is about the document or the subject matter. Fixed
  `COLOPHON.md`'s now-false "Both rules are inference-based" in the §8
  section. Released `software-english` `v0.0.25`; since the change touches
  `rules/core-rules.toml`, also pinned and released `swe` (`0.18.4` →
  `0.18.5`, `swe-v0.18.5`). Shipped, single pass, no escalation.
- [tasks/software-english-issue-18-ownership-entitlement.md](tasks/software-english-issue-18-ownership-entitlement.md)
  ([#18](https://github.com/jimbarritt/software-english/issues/18), opened
  by `jimbarritt-pleo`): a possession or entitlement construction (`own`,
  `its own`, `belongs to`, `is entitled to`, `deserves`, `earns`, `claims`,
  `is owed`, and similar) given a possessor that cannot own or claim
  desert — a system, a service, a component, a process, a document, or a
  record. Plan from an Opus Plan subagent, which read SPEC §5 in full and
  the no-unstated-presupposition (§7.19) precedent before proposing
  anything. Two departures from the issue's own proposed direction, both
  forced by text already shipped in this spec, not left to the model to
  discover at judgement time: possessor animacy alone is not sufficient,
  since `own` already appears correctly with an inanimate possessor
  meaning one each and not shared ("each event on its own topic", the
  §3.6/§5.9 fix text; "its own sentence", §8.1) — the issue's own cut test
  ("cutting `own` changes nothing the sentence states") made a second,
  independent condition rather than restated motivation, so the new rule
  does not fire on the project's own correct fix text; and `belongs to`
  needed a sense split against §5.2, which already names it as the
  correct plain classification verb for an abstract subject (`a rule
  belongs to one tier`) — the new rule fires on `belongs to` only where
  its object is a possessor, never where the object is a set or whole the
  subject is a member or part of. New standalone rule
  `no-ownership-or-entitlement-for-a-system` (SPEC §5.11), end of §5,
  inference-based: a fixed-phrase, subject-gated design (the mixed tier
  §5.1/§5.2 use) was rejected, since every family member has at least one
  correct use with a system possessor (`belongs to` as classification,
  distributive `own`, a term of art such as a worker `claims` a job), so a
  subject check alone would misfire on the project's own shipped prose.
  Reciprocal "Distinct from" cross-references added to §5.1 and §5.2, in
  both SPEC.md prose and the TOML descriptions, so neither rule claims a
  phrase this one covers. Two pre-existing uses of "of its own"/"its own"
  reworded where they were purely vacuous emphasis the new rule's own test
  would itself flag (SPEC.md:188 and the matching
  no-clipped-sentence-run TOML description; no-unanchored-reference's TOML
  description). Verified against the real linter (`claude-plugins/swe`,
  data populated locally for this check only, emptied again before
  shipping, since `swe` is not installed as a skill in this session):
  `tomllib` confirms 33 unique rule ids (32 before); `--diff --added-only`
  reports 0 error-severity findings on every added line across both
  files; the three error-severity findings the new TOML description's own
  text produces when linted standalone (`carry`, `hold`, `knows`, all
  inside "Distinct from" sentences citing another rule's own banned
  words) match the same pattern already present, unmodified, in
  `no-metaphor-or-analogy`'s own shipped description (12 such findings
  there), confirmed by linting that rule's unmodified text the same way —
  not a new defect, the established and unavoidable cost of a catalogue
  that must name the very words a neighbouring rule bans. Full-file
  comment-only lint of `rules/core-rules.toml` as a code file: 53 errors
  before, 56 after, the delta exactly the three self-citation findings
  above. All seven `claude-plugins/swe` test suites pass (176 assertions,
  unchanged), run twice: once with locally-populated verification data,
  once against the real fetched `v0.0.24` tag after release. Shipped on
  `software-english`'s `main` at
  [`48b9084`](https://github.com/jimbarritt/software-english/commit/48b908440d91742bf42ca240cb39ee46db3241b2),
  released as
  [v0.0.24](https://github.com/jimbarritt/software-english/releases/tag/v0.0.24),
  closing the issue automatically. `claude-plugins` pin bumped and `swe`
  version bumped (`0.18.3` -> `0.18.4`) on `main` at
  [`cb48544`](https://github.com/jimbarritt/claude-plugins/commit/cb4854429656275f2b413c394d5dae496dd63092),
  released as
  [swe-v0.18.4](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.18.4).
  Single pass, no escalation. Sibling issue #19 ("a distributive tail
  coordinated onto a count"), filed three minutes after this one by the
  same author, left unclaimed for a future run — one issue per run.
  `claude-plugins`#16 stays `agent:hold`, excluded from the pool as
  before.
- [tasks/software-english-issue-17-unstated-presupposition.md](tasks/software-english-issue-17-unstated-presupposition.md)
  ([#17](https://github.com/jimbarritt/software-english/issues/17), opened
  by `jimbarritt-pleo`): a definite noun phrase with a cardinal or a
  completed-act participle ("the four surveyed carriers") can presuppose a
  count or an act the document never states — a shape
  `no-unanchored-reference` (SPEC §7.5) doesn't reach, since that rule needs
  an abstract singular with no antecedent noun, not a concrete plural
  missing a prior assertion. Plan from an Opus Plan subagent, which read
  `COLOPHON.md`, `SPEC.md`, and `rules/core-rules.toml` in full before
  proposing anything. New standalone rule `no-unstated-presupposition`
  (SPEC §7.19), inference-based, unscoped like its sibling §7.5; appended
  after §7.18 (not beside §7.5) for the §7.14 renumbering reason. Reciprocal
  "Distinct from" clauses added to both rules — the plan's one judgement
  call taken rather than left one-sided, since §7.5's own "and similar"
  wording could otherwise let the judging model claim a phrase like "the
  agreed plan" under §7.5 too. Kept the issue's own Fault sentence verbatim;
  changed its Fix from passive to active voice with a named actor and a
  date, to state the "who"/"when" the fault withholds and to avoid the
  §7.6 count-signpost shape. Two self-check catches, both found only by
  running the real linter: two uses of "is missing" (adjectival, not a
  verb) tripped the deterministic `no-continuous-tense` rule, reworded to
  "the document never states the fact ...". Verified directly against the
  real linter throughout: `tomllib` confirms 32 unique rule ids (31 before);
  `--diff --added-only` reports 0 errors on every added SPEC.md line, both
  before and after the `no-continuous-tense` fix; both changed TOML
  descriptions piped through `--text` report 0 errors (only the
  sentence-length warnings every dense TOML description in this catalogue
  already carries); `--force-inference` shows the new rule in the pending
  block (24, up from 23) with the deterministic tier unchanged at 20
  pre-existing errors; a manual judgement pass confirms the issue's own
  Fault sentence fires under §7.19 and not §7.5, the Fix fires under
  neither, and every stated non-trigger example doesn't fire. All seven
  `claude-plugins/swe` test suites pass (176 assertions, unchanged), run
  with `SWE_SRC` against the local checkout. No `claude-plugins` code
  change — `swe/data/` was populated locally only to run the linter for
  verification, then emptied again before shipping. Shipped on
  `software-english`'s `main` at
  [`3b4bb30`](https://github.com/jimbarritt/software-english/commit/3b4bb30db69301dbc2b9dbc15d46e5516b619320),
  released as
  [v0.0.23](https://github.com/jimbarritt/software-english/releases/tag/v0.0.23),
  closing the issue automatically. `claude-plugins` pin bumped and `swe`
  version bumped (`0.18.2` -> `0.18.3`) on `main` at
  [`f4d8268`](https://github.com/jimbarritt/claude-plugins/commit/f4d8268ef4ff3165718a92a5cefa617b562d7cdd),
  released as
  [swe-v0.18.3](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.18.3).
  Single pass, no escalation. Sibling issue #18 ("possession and
  entitlement require an animate possessor"), filed six minutes after this
  one by the same author, left unclaimed for a future run — one issue per
  run.
- [tasks/software-english-issue-15-framing-devices.md](tasks/software-english-issue-15-framing-devices.md)
  ([#15](https://github.com/jimbarritt/software-english/issues/15), opened
  by `jimbarritt-pleo`): no rule caught three co-occurring framing shapes
  in a declarative sentence: cleft padding (`the import is what
  reconciles` for `the import reconciles`), rhetorical-question framing
  (`asks one question`, `answers two questions`), and naming-as-justification
  (`is named for that question rather than for the structure`). The issue
  offered a deterministic cleft check plus an inference rule for the
  other two as one option; rejected after reading
  `claude-plugins/swe/scripts/software_english_lint.py` directly: its
  deterministic tier is hardcoded per rule id with no generic
  pattern-based dispatcher, so a new deterministic check would need new
  Python in a different repository, out of scope for a
  `software-english`-only issue. Shipped as one new rule,
  `no-framing-device` (SPEC §5.10), entirely inference-based
  (`check = "model-judgement"`), which needs no `claude-plugins` code
  change at all: that tier already collects every such rule's
  description generically. One correction to the Opus plan's first
  reading: the issue states plainly that an identity reading (`the
  primary key is what the index is built on`) does **not** exempt the
  cleft shape — kept as a fault with a fix, not listed as an exception.
  "Distinct from" cross-references added against seven neighbouring
  rules that could otherwise double-fire on the same sentence
  (`no-question-or-argument-heading`, `no-contrastive-framing`,
  `no-catch-all-verb`, `anthropomorphism-paraphrase`,
  `no-metaphor-or-analogy`, `no-abstract-stand-in-for-artefact`,
  `no-entailed-restatement`). Verified against the real linter: zero
  `[error]`-severity findings on the added lines in both files; a
  manual judgement pass against every rule the printed
  `INFERENCE_ADVISED` block listed found no plausible finding in the new
  prose. All seven `claude-plugins` test suites pass, unchanged.
  Shipped on `software-english`'s `main` at
  [`1de92e5`](https://github.com/jimbarritt/software-english/commit/1de92e5),
  released as
  [v0.0.22](https://github.com/jimbarritt/software-english/releases/tag/v0.0.22),
  closing the issue automatically. `claude-plugins` pin bumped and `swe`
  version bumped (`0.18.1` -> `0.18.2`) on `main` at
  [`53ea98b`](https://github.com/jimbarritt/claude-plugins/commit/53ea98b),
  released as
  [swe-v0.18.2](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.18.2).
  Single pass, no escalation. The issue's own closing remark, that
  `no-contrastive-framing` may separately miss the general `X rather
  than Y` contrast, is left unfixed: flagged there as a possible
  separate gap, not this issue's ask.
- [tasks/software-english-issue-14-abstract-stand-in-every-type.md](tasks/software-english-issue-14-abstract-stand-in-every-type.md)
  ([#14](https://github.com/jimbarritt/software-english/issues/14), opened
  by `jimbarritt-pleo`, a trusted collaborator — the first issue claimed from
  that account): `no-abstract-stand-in-for-artefact` (SPEC §7.15) carried
  `applies_to_document_type = "pr-description"`, so the same fault (an
  abstract or structural noun standing in for a named artefact — the issue's
  own example, "shapes" and "this record" for unnamed vendor payload
  structures and a schema) passed both tiers clean on a Reference or a
  Design document. Plan from an Opus Plan subagent, which read the sibling
  `no-check-without-result` entry, SPEC §7.15/§7.16/Appendix F, all four
  document-type templates, and `COLOPHON.md` before proposing anything.
  Dropped the scope condition so the rule fires on every type; only its
  *scope* stays conditional (problem/change statement on a PR Description,
  whole document elsewhere — the issue's own literal proposal). Widened the
  artefact list (added `type`, `schema`, `table`, `endpoint`, `topic`) and
  split the stand-in noun list by type (PR Description keeps
  `evidence`/`context`/`visibility`/`coverage`/`insight`; Reference/Design
  gets `shape`/`form`/`flavour`); deliberately did not add `surface` from
  the issue's own list, since it is already on `vocabulary/banned.tsv` and
  adding it here would double-report. New precedence clause against
  `no-metaphor-or-analogy` (§5.5), which already covers a form noun standing
  in for a *named* schema's fields: if the sentence names the artefact,
  §5.5 only; if it names no artefact at all, §7.15 only — needed so the
  issue's own fault sentence and §5.5's own worked example don't collide.
  New literal-sense exception for `form` (`an HTML form`). Confirmed
  `no-check-without-result` needs no change: it is the "essential" case in
  sibling issue #16's own essential/incidental terms, since its fault needs
  a Verification/Not-verified section pair only a PR Description has. One
  correction to the issue's own framing, given in the closing comment: its
  claim that every scoped rule names `pr-description` was already false in
  v0.0.20 (`no-planning-content-in-reference` is scoped to `reference`).
  Two self-check catches, both found only by running the real linter, not
  anticipated in the plan: "the sentence decides which rule reports it"
  genuinely tripped `anthropomorphism-fixed-list` (correctly, not a false
  positive — reworded to state the two cases with no verb of deciding), and
  "document, the common stand-ins are structural nouns" tripped
  `abstract-location`, a real false positive from hyphen tokenisation
  (`stand-ins` splits to the bare word `stand`, a listed location verb)
  landing within 4 words of `document`, a structure noun, after the
  paragraph was rewrapped onto a new line (reworded the second "stand-ins"
  to "substitutes"). Verified directly against the real linter throughout:
  `--diff --added-only` reports 0 errors on every changed line across all
  four files after both fixes; `--force-inference` against a scratch
  Design-typed source confirms the rule now reaches the judging model there
  (it always did, regardless of document type — `applies_to_document_type`
  is never read programmatically by `software_english_lint.py`, only by the
  judging model via the rule's own prose, which is what this fix actually
  changes); a manual judgement pass confirms the issue's fault sentence
  fires under §7.15, its fix sentence does not, §5.5's own worked example
  fires under §5.5 only, and the stated exceptions (a measured quantity, an
  HTML form) do not fire. All six `claude-plugins/swe` test suites pass (176
  assertions, unchanged), run against the fix both as a local checkout and
  against the real fetched `v0.0.21` tag post-release.
  `scripts/check-unshipped.sh` clean before and after the `swe` pin bump.
  Shipped on `software-english`'s `main` at
  [`86fa220`](https://github.com/jimbarritt/software-english/commit/86fa220),
  released as
  [`v0.0.21`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.21),
  which closed #14 automatically. `claude-plugins` pin bumped and `swe`
  version bumped (`0.18.0` -> `0.18.1`) on `main` at
  [`c5204ae`](https://github.com/jimbarritt/claude-plugins/commit/c5204ae),
  released as
  [`swe-v0.18.1`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.18.1).
  Single pass, no escalation. Also closed
  [#16](https://github.com/jimbarritt/software-english/issues/16) as a side
  effect: it asked for exactly the essential/incidental audit this fix
  performed on the only two `pr-description`-scoped rules that existed,
  with nothing left to audit once both were decided; closed with a comment
  pointing back to this commit, its own "add a new `reference` document
  type instead" alternative not pursued, rather than treated as a second
  piece of work this run.
- [tasks/issue-18-register-rule-candidate-detectors.md](tasks/issue-18-register-rule-candidate-detectors.md)
  ([#18](https://github.com/jimbarritt/claude-plugins/issues/18)): ninth
  real `claude-plugins` issue worked end to end by the self-maintaining-repo
  Routine, single pass, no escalation. Software English's `no-cadence-device`
  and `no-mechanical-repetition` (SPEC §8.1, §8.2, shipped #8/v0.0.17) are
  both `model-judgement`, so the deterministic tier never pointed at
  anything for them; two of their patterns have a cheap structural signal a
  stdlib-only linter can locate without deciding the fault itself. New
  `register_blocks()`/`split_sentences()` (multi-line structure the existing
  per-line `check_line()` cannot see) feed three detectors:
  `find_cadence_fragments()` (a verbless sentence right after a 15+-word
  sentence, against a closed verb/auxiliary lexicon —
  `vocabulary/operations.tsv` plus auxiliaries plus a further hardcoded
  common-verb set, added only after real prose false-positived without it,
  with a determiner-before exception so "No retries." reads as a noun),
  `find_matched_pairs()` (two adjacent sentences with an identical
  word-class sequence — the issue's own "matched-pair half" ask, kept in
  scope rather than deferred), and `find_bold_list_runs()` (a run of 3+
  bold-lead-in bullet lists; a single such list does not fire, since this
  repo's own templates and `CLAUDE.md` use one deliberately, exactly the
  catalogue rule's own exclusion). Plan from an Opus Plan subagent, which
  read the real linter, the real pinned `v0.0.20` catalogue/TSVs, and
  prototyped all three detectors against all 33 real `.md` files in both
  repos before proposing thresholds, flagging that the thresholds were
  tuned on that same corpus (no held-out set) as a point to recheck later.
  All candidates print as `candidate at line N: ...` lines directly after
  their rule's own `inference pending` line, inside the existing
  `===INFERENCE_ADVISED===` block, always at line 0, never entered into a
  findings list, so `error_total`, `--count`, and the exit code are
  unaffected; capped at 20 per rule per source. Verified directly against
  the real linter and the real pinned data throughout: the catalogue's own
  worked examples fire (including wrapped across lines), the determiner
  exception fires, the list-run detector fires on a real 3-list run and
  stays silent on 2 lists, a broken run, a single 5-bullet list, wholly-bold
  bullets, and the same content fenced; a true-negative sweep of this
  repo's own real prose (`README.md`, `agent-guide.md`,
  `lint-file/SKILL.md`, the output style, root `CLAUDE.md`) reports zero
  candidates. New `swe/tests/register_candidates_test.sh`, 34 assertions,
  all pass; all six existing suites pass unchanged (142 assertions, 176
  total). `--diff --added-only` on the two edited docs
  (`agent-guide.md`, `lint-file/SKILL.md`) reports zero errors/warnings.
  The three hooks' advisory text also updated. Version bumped `0.17.12` ->
  `0.18.0`. Shipped on `main` at
  [`a48875a`](https://github.com/jimbarritt/claude-plugins/commit/a48875a377a2adab6168f5a414bcce2da045d6de),
  which closed the issue automatically, released as
  [`swe-v0.18.0`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.18.0).
  No `software-english` change: the located-candidate approach needed no
  new catalogue `check` value, as the issue itself anticipated.
- [tasks/software-english-issue-12-heading-rules.md](tasks/software-english-issue-12-heading-rules.md)
  ([#12](https://github.com/jimbarritt/software-english/issues/12)):
  two faults visible only in a heading, named in the issue but not in
  the catalogue — a heading that withholds its content, and a heading
  phrased as a question or an argument instead of a claim. New
  `no-withholding-heading` (SPEC §7.17) and
  `no-question-or-argument-heading` (SPEC §7.18), both inference-based,
  unconditional on document type, scoped to headings only at every
  level. Plan from an Opus Plan subagent. Scoped deliberately narrower
  than the issue's literal wording to avoid flagging the repo's own
  heavily-used topic-label and indirect-question heading styles (`What
  a tutorial is`, `How this differs from …`, `Verdict`): a heading that
  names a subject, or a subject and a property, passes both rules, and
  a conventional section name is exempt from the withholding rule.
  Checked by hand against all 176 existing headings in `spec/`,
  `docs/`, `templates/`, `README.md`, and `COLOPHON.md`: zero false
  positives. One correction made during verification, found only by
  running the real linter, not anticipated going in: the drafted
  `COLOPHON.md` prose ("these rules sit... for the reason §7.14 sits
  there") tripped the deterministic `abstract-location` rule it sits
  beside — an abstract subject given a verb of physical position —
  reworded to "are new entries ... is there". Verified directly against
  the real linter throughout: `tomllib` confirms the catalogue parses
  and all 30 rule ids stay unique; `--added-only` (not `--diff` alone,
  which lints the whole file, confirmed by a first run surfacing 20+
  unrelated pre-existing findings) reports 0 errors on every added
  line; `--force-inference` confirms both new rule ids and full
  descriptions reach the judging-model block, count 20 -> 22; a manual
  model-judgement pass against all 176 real headings plus the issue's
  own fault/fix examples found zero false positives and each fault
  firing once under the intended rule. All six `claude-plugins` test
  suites pass (142 assertions, unchanged). Shipped on
  `software-english`'s `main` at
  [`f15724f`](https://github.com/jimbarritt/software-english/commit/f15724f294523c12ba023fa06d05f52ccac78dad),
  released as
  [v0.0.20](https://github.com/jimbarritt/software-english/releases/tag/v0.0.20).
  Because the change touches `rules/core-rules.toml`: bumped
  `claude-plugins/swe/software-english.json`'s pin to `v0.0.20` and
  `swe`'s own version `0.17.10` -> `0.17.11`, commit
  [`eef52ba`](https://github.com/jimbarritt/claude-plugins/commit/eef52bac81156e052ae62b6111b0c662a4f73a0e),
  released as
  [swe-v0.17.11](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.11).
  Issue auto-closed by the `closes #12` commit. Single pass, no
  escalation.
- [tasks/software-english-issue-10-11-pr-description-document-type.md](tasks/software-english-issue-10-11-pr-description-document-type.md)
  ([#10](https://github.com/jimbarritt/software-english/issues/10),
  [#11](https://github.com/jimbarritt/software-english/issues/11)):
  two issues asking for the same feature, oldest-first claimed #10,
  #11's concrete design actually implemented. A PR description could
  pass the deterministic tier clean while a sentence named no
  artefact (an abstract stand-in: "evidence", "visibility", and
  similar) or listed a check with no result, since no document type
  recognised a pull request description and nothing raised the bar
  for its two load-bearing sections. New `PR Description` type in
  Appendix F (`templates/pull-request.md`, a convergent convention
  like Lab Notebook, since no standards body defines one, citing
  Google's CL-description guide and the Linux kernel's "Submitting
  patches"), and two new inference-tier rules conditioned on it only:
  `no-abstract-stand-in-for-artefact` (SPEC §7.15, widened beyond
  #11's ask to also cover #10's own "It reports four counts" unnamed-
  count example) and `no-check-without-result` (SPEC §7.16, widened
  to a manual-step check and a ticked checkbox, not only a command).
  `document-type-template` and `no-work-breakdown-or-tracker-pointer`
  updated to name the type, the latter gaining a third exception for
  a `Closes #N` closing-keyword line. Plan from an Opus Plan subagent,
  which flagged the sourcing gap (the three cited guides' hosts
  blocked by the network proxy, so not fetched and checked against
  the drafted paraphrase) and eleven judgement calls rather than
  deciding them silently; two taken without asking (the two widenings
  above). Two self-check catches during drafting, both found only by
  running the real linter: the banned word "really" used three times
  across the new prose, and "stands in for"/"standing in for" in the
  new rule's own prose genuinely tripped the deterministic
  `abstract-location` rule it is adjacent to (an abstract subject
  followed by a location verb), not a false positive, reworded to
  "used in place of"/"substitute". Verified directly against the real
  linter throughout, not just reasoned about: `--diff --added-only`
  reports 0 errors on every newly added line across the four touched
  files; per-file before/after error counts unchanged on every
  pre-existing file (`SPEC.md` 19→19, `COLOPHON.md` 1→1, `README.md`
  2→2); the new `templates/pull-request.md` lints clean. All six
  `claude-plugins` test suites pass (142 assertions, unchanged), run
  twice: once against a local-fixture copy of the edited files, and
  again against the real fetched `v0.0.19` tag after release. Shipped
  on `software-english`'s `main` at
  [`76d9954`](https://github.com/jimbarritt/software-english/commit/76d9954),
  released as
  [`v0.0.19`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.19),
  which closed both issues automatically. `claude-plugins` pin bumped
  and `swe` version bumped (`0.17.9` -> `0.17.10`) on `main` at
  [`3ed3ab4`](https://github.com/jimbarritt/claude-plugins/commit/3ed3ab4),
  released as
  [`swe-v0.17.10`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.10).
  Single pass, no escalation. #10's own "where" standing in for a
  conditional is a sentence-level fault neither issue asked to fix;
  shown as a worked example in the new template, not filed as a
  further issue (one-issue-per-run).
- [tasks/software-english-issue-9-count-signpost.md](tasks/software-english-issue-9-count-signpost.md)
  ([#9](https://github.com/jimbarritt/software-english/issues/9)):
  `vacuous-classification-property`'s trigger set named only a
  taxonomy-definition case, so a bare count signposting the list
  below it ("Three costs follow from that:", "Three routes drop an
  entry:") went uncaught. The issue's own third example, "Two things
  changed.", already fired via `vocabulary/banned.tsv`'s "Announcing
  the shape of the text" group — only the first two were genuinely
  uncaught, corrected in the closing comment rather than absorbed
  silently. Rewrote the rule's `description` (TOML and SPEC.md §7.6
  both) to name two faults, taxonomy property and count signpost,
  each with a Fault/Fix pair and stated exceptions (a partial-set
  count, a summary count, a quantity). Rule id, tier, `check`, and
  `trigger_phrases` unchanged: nothing in `claude-plugins` ever reads
  `trigger_phrases` (only `description` reaches the judging model,
  confirmed by reading `--advise-inference`'s block-building code
  directly), and the new trigger is positional, not a literal
  substring, so it belongs in prose. No `claude-plugins` code change:
  "findable deterministically in markdown" describes the trigger's
  shape, not a Python detector requirement, and the trigger spans a
  sentence head plus the following list, which the linter's
  line-at-a-time `check_line` can't express without new
  paragraph-aware code anyway — left as a pointer to `claude-plugins`#18
  rather than a third issue. Verified against the real linter: 19
  deterministic-tier errors on `spec/SPEC.md` both before and after,
  identical set, line-shifted only; manually judged the issue's own
  examples and the three new exceptions against the rewritten
  description, each landing correctly. All six `claude-plugins` test
  suites pass (142 assertions, unchanged). Shipped on
  `software-english`'s `main` at
  [`03b3f31`](https://github.com/jimbarritt/software-english/commit/03b3f31),
  released as
  [v0.0.18](https://github.com/jimbarritt/software-english/releases/tag/v0.0.18),
  closing the issue automatically. `claude-plugins` pin bumped and
  `swe` version bumped (`0.17.8` -> `0.17.9`) on `main` at
  [`59c831f`](https://github.com/jimbarritt/claude-plugins/commit/59c831f),
  released as
  [`swe-v0.17.9`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.9).
  Single pass, no escalation. One process catch, before pushing: the
  first commit was missing the required attribution footer, fixed
  with `git commit --amend` since it had not been pushed yet.
- [tasks/software-english-issue-8-register-rule.md](tasks/software-english-issue-8-register-rule.md)
  ([#8](https://github.com/jimbarritt/software-english/issues/8)):
  prose can pass every existing rule clean and still read as
  machine-generated. New SPEC §8 "Register rules", two inference-tier
  catalogue entries: `no-cadence-device` (§8.1, a verbless fragment
  used as a rhythmic beat after a longer sentence, or a matched
  sentence pair that restates itself in parallel shape) and
  `no-mechanical-repetition` (§8.2, a bold lead-in repeated on every
  bullet across a run of lists, one measurement restated several times
  in different words, a contents list out of scale with its document).
  Plan from an Opus Plan subagent, applied with no deviation on scope
  or section placement. The issue's own two "deterministic-tier
  candidates" (a verbless-fragment check, a repeated-structure count)
  don't meet SPEC §2's deterministic-tier bar on their own (a
  stdlib-only linter has no part-of-speech tagger, and deciding whether
  flagged text adds a fact needs judgement either way), so both stayed
  inference-based/`model-judgement`, and the detector idea was split
  out as a `claude-plugins` follow-up,
  [#18](https://github.com/jimbarritt/claude-plugins/issues/18), for
  located-candidate signals to feed the existing model pass rather than
  a new blocking rule. One self-check catch: the drafted `COLOPHON.md`
  text used the banned word "holds", caught only by running the real
  linter (copying the edited `rules/core-rules.toml` into
  `claude-plugins/swe/data/`, since `swe` is not installed as a skill
  in this session), fixed to "contains". Deterministic-tier error count
  on the two edited files matched the pre-edit baseline exactly (20
  before and after), confirming zero new findings from the new text.
  All six `claude-plugins` test suites pass (142 assertions,
  unchanged); `scripts/check-unshipped.sh` clean before and after the
  `swe` pin bump. Shipped on `software-english`'s `main` at
  [`9df843b`](https://github.com/jimbarritt/software-english/commit/9df843b3cb8c31bd971294578f048eb715fa82fd),
  released as
  [v0.0.17](https://github.com/jimbarritt/software-english/releases/tag/v0.0.17),
  which closed the issue automatically. `claude-plugins` pin bumped and
  `swe` version bumped (`0.17.7` -> `0.17.8`) on `main` at
  [`7147c5a`](https://github.com/jimbarritt/claude-plugins/commit/7147c5a4648eb8d7962095d3813bffa2f6c3323a),
  released as
  [`swe-v0.17.8`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.8).
  Single pass, no escalation.
- [tasks/software-english-issue-7-unanchored-reference-headings.md](tasks/software-english-issue-7-unanchored-reference-headings.md)
  ([#7](https://github.com/jimbarritt/software-english/issues/7)):
  `no-unanchored-reference`'s rule description is the whole rule for
  the inference tier (`lint-file` passes it to the judging model
  verbatim), and it gave only body-prose examples, so a question-shaped
  heading ("What this costs", "Which process owns the cache") escaped
  it. Widened the description to put every heading in scope, kept the
  existing definite-noun heading example, and added the question shape
  ("What this `<verb>`", "Which `<noun>` `<verb>`") with the issue's
  four headings as worked examples, plus a policy that a bare
  `this`/`that`/`it` in a heading is a fault even under a parent
  heading that names a subject, since a heading is also read alone.
  Matching worked example added to `spec/SPEC.md` §7.5. Also dropped an
  em dash the old description had, which broke this repo's own
  `no-em-dash`. Plan drafted by an Opus Plan subagent, applied as
  planned with no deviation. `/swe:lint-file`'s deterministic tier on
  `spec/SPEC.md` found 19 pre-existing errors unrelated to the new
  lines (banned words like "holds", "the reader" scattered through the
  rest of the document); none in the new text, out of scope for this
  issue, recorded honestly in the lint ledger as `failed` rather than
  papered over as `clean`. Released as
  [v0.0.16](https://github.com/jimbarritt/software-english/releases/tag/v0.0.16)
  (commit f7890c2). Since the change touched `rules/core-rules.toml`,
  also bumped `claude-plugins`' `swe` plugin's pinned tag and released
  it as
  [swe-v0.17.7](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.7)
  (commit e9a73b3). Single pass, no escalation.
- [tasks/software-english-issue-6-work-breakdown-tracker-pointer.md](tasks/software-english-issue-6-work-breakdown-tracker-pointer.md)
  ([#6](https://github.com/jimbarritt/software-english/issues/6)):
  `no-planning-content-in-reference`'s Design exemption was too broad:
  a design document could carry a work-breakdown sentence (dividing the
  subject into "this piece of work" vs. "a later piece of work") and a
  bare issue-tracker id as the pointer to that later work, and neither
  fired, since the rule is conditional on document type Reference and
  fully exempts Design. New rule `no-work-breakdown-or-tracker-pointer`
  (SPEC §7.14), unconditional on document type, Design and API Design
  included; the open-questions and future-extension sections stay
  exempt as before, since neither names a unit of work or a tracker id.
  An entry in a section headed References/Bibliography may still cite
  an issue or PR by its id and title, as a source; a Lab Notebook entry
  naming its own task, or a Portfolio Journal entry recording work
  already done, is not this fault either. Took the issue's "every
  document type" literally, including RFC/ADR, a narrower reading than
  the existing rule's own rationale (planning content generally is
  correct there) but explicit in the issue's own direction. Three
  self-check catches during implementation, all found only by running
  the real linter against the drafted prose: "is scheduling" tripped
  `no-continuous-tense` in both `SPEC.md` and the TOML rule's own
  description (reworded to "a scheduling choice"); two em dashes and
  one banned word ("carries") in a new `COLOPHON.md` section; three
  sentences across `templates/design.md` and `templates/reference.md`
  exceeded the 20-word ceiling once old and new text combined onto one
  line. `--diff --added-only` reports zero errors/warnings on every
  changed line across all five Markdown files; `rules/core-rules.toml`
  needed a separate full-file check since `--diff` mode only tracks
  Markdown files. All six `claude-plugins` test suites pass (142
  assertions, unchanged). Shipped on `software-english`'s `main` at
  [`2556a26`](https://github.com/jimbarritt/software-english/commit/2556a26),
  released as
  [`v0.0.15`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.15),
  closing the issue automatically. `claude-plugins` pin bumped and
  `swe` version bumped (`0.17.5` -> `0.17.6`) on `main` at
  [`6859d31`](https://github.com/jimbarritt/claude-plugins/commit/6859d31),
  released as
  [`swe-v0.17.6`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.6).
  Single pass, no escalation. One process mistake caught before
  pushing, not after: the first `claude-plugins` pin-bump commit had a
  shell heredoc closed in the wrong place, folding a nonsensical
  `closes software-english#6` line into the subject and dropping the
  attribution footer from both commits on the first attempt; caught by
  reading each commit back with `git show` before `git push`, fixed
  with `git commit --amend` since neither had been pushed yet.
- [tasks/software-english-issue-4-catch-all-verb-clipped-sentences.md](tasks/software-english-issue-4-catch-all-verb-clipped-sentences.md)
  ([#4](https://github.com/jimbarritt/software-english/issues/4)): a
  repeated catch-all verb, an unvaried run of short sentences, and a
  shifting pronoun chain compounded into machine-written-sounding
  prose that no existing rule caught, since the fault is the paragraph
  as a whole. Two new inference-tier rules: `no-clipped-sentence-run`
  (SPEC §3.6, a run of three or more short sentences splitting one
  fact into clipped pieces joined by a shifting pronoun chain) and
  `no-catch-all-verb` (SPEC §5.9, one verb repeated in a paragraph to
  name different relations). The pronoun-chain fault is folded into
  the first rule as a required test, not given its own rule. Two
  factual corrections made to the issue's own example along the way,
  found only by actually counting: "states" occurs three times, not
  four, and the sentence lengths are 8/5/4/19/7, not uniform, so a
  length-only test would miss the example and fire on the reporter's
  own rewrite; the reporter's rewrite also drops facts §3.1 requires
  kept, so a fact-preserving rewrite was used as the worked fix
  instead. Verified directly against the real linter throughout, not
  just reasoned about: both rules load into the inference block, the
  deterministic tier is unchanged on the edited SPEC.md (diffed by
  content against the pre-edit file), and manually judging both the
  fault text and the fix text against each rule's printed description
  confirms each fires only on the fault. One self-check catch during
  implementation: a cross-reference sentence this fix added used
  "holds" as a truth-metaphor, caught only by re-running the real
  lint, not by reading the prose back, and reworded. All six
  `claude-plugins` test suites pass (142 assertions, unchanged).
  Shipped on `software-english`'s `main` at
  [`8aa442a`](https://github.com/jimbarritt/software-english/commit/8aa442a),
  released as
  [`v0.0.14`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.14),
  closing the issue automatically. `claude-plugins` pin bumped and
  `swe` version bumped (`0.17.4` -> `0.17.5`) on `main` at
  [`02dafb5`](https://github.com/jimbarritt/claude-plugins/commit/02dafb5),
  released as
  [`swe-v0.17.5`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.5).
  Along the way, found `claude-plugins` `main` one commit behind
  `origin/main`: a prior session had already shipped and released
  [`63ebe0c`](https://github.com/jimbarritt/claude-plugins/commit/63ebe0c)
  (`swe-v0.17.4`, rewording 19 uses of `hold`/`holds`/`holding` in the
  plugin's own docs that `software-english`#2/#13's ban made
  non-compliant); pulled in before bumping the pin again on top of it.
- [tasks/software-english-issue-3-undeclared-state-verb.md](tasks/software-english-issue-3-undeclared-state-verb.md)
  ([#3](https://github.com/jimbarritt/software-english/issues/3)): an
  invented state verb ("settles") passed every tier while the document
  declared an explicit status set that named no such value. Three
  candidate rules named in the issue each missed it for a distinct
  reason (not anthropomorphic, not a listed metaphor, not an undefined
  term — it substitutes for values the document already names). New
  §5.8 "No undeclared state verb" in `spec/SPEC.md` and a matching
  `no-undeclared-state-verb` entry in `rules/core-rules.toml`,
  `inference-based`/`model-judgement`/`warning`. Verified the new rule
  surfaces in the real linter's `--force-inference` block against the
  issue's own example; full lint of the edited SPEC.md found only
  pre-existing findings outside the new section. All six
  `claude-plugins` test suites pass. Shipped on `software-english`'s
  `main` at
  [`b21056b`](https://github.com/jimbarritt/software-english/commit/b21056b),
  released as
  [`v0.0.13`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.13),
  closing the issue automatically. `claude-plugins` pin bumped and
  `swe` version bumped (`0.17.2` -> `0.17.3`) on `main` at
  [`704f0a0`](https://github.com/jimbarritt/claude-plugins/commit/704f0a0),
  released as
  [`swe-v0.17.3`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.3).
  Single pass, no escalation. (This entry was missing from this list
  until the next run added it; the task file and the commits were
  already shipped.)
- [tasks/software-english-issue-2-13-holds-carries-metaphor.md](tasks/software-english-issue-2-13-holds-carries-metaphor.md)
  ([#2](https://github.com/jimbarritt/software-english/issues/2),
  [#13](https://github.com/jimbarritt/software-english/issues/13)):
  `carry`/`carries`' own suggested replacement recommended `hold`/
  `holds`, trading one possession metaphor for another that nothing
  then caught. Escalated first: implementing the ask as written meant
  rewriting `no-metaphor-or-analogy`'s own worked "correct" example
  (`"The retry queue holds a failed request"`, written by Jim himself
  in the spec's original design commit `d406426`) and reclassifying
  `hold` against `vocabulary/operations.tsv`'s existing treatment of it
  as a concrete domain operation. Jim's answer, given directly in the
  escalating session rather than via a GitHub comment: ban `hold`/
  `holds`/`holding`/`held` too, the same way `carry`/`carries` already
  is — a system, a structure, or an abstract concept has no hands.
  `vocabulary/banned.tsv` gained a new "Possession metaphor" group;
  `no-metaphor-or-analogy`'s description and `spec/SPEC.md` §5.5's
  worked examples rewritten to use `contain`/`have`/`save` instead of
  `hold`; seven vocabulary-file definitions that used `hold`/`holds`/
  `holding` to define another word rewritten (`qualities.tsv`
  `empty`/`full`/`stale`/`fresh`, `structure.tsv` `cache`,
  `operations.tsv` `contain`/`be`). Verified against the real linter
  throughout, not just reasoned about: the issue's own flagged sentence
  now fires, every new/rewritten line is itself clean, and SPEC.md's
  full finding count diffed before/after (14 -> 24, exactly the ten
  deliberately-left-alone `hold`/`holds` lines in SPEC's own general
  prose — out of scope for this fix, named as a follow-up candidate).
  Also flagged, not fixed: ~22 uses of `hold`/`holds`/`holding` in
  `claude-plugins/swe`'s own docs will now trip `banned-word` once
  linted, since that's a different repo's files this run didn't touch.
  All six `claude-plugins/swe` test suites pass (142 assertions,
  unchanged), confirmed against both a local-checkout fixture and a
  real fetch of the released tag. Shipped on `software-english`'s
  `main` at
  [`321718e`](https://github.com/jimbarritt/software-english/commit/321718e),
  released as
  [`v0.0.12`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.12),
  closing both issues. `claude-plugins` pin bumped and `swe` version
  bumped (`0.17.1` -> `0.17.2`) on `main` at
  [`b4af78a`](https://github.com/jimbarritt/claude-plugins/commit/b4af78a),
  released as
  [`swe-v0.17.2`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.2).
- `software-english` #1, `no-metaphor-or-analogy` missed the
  container-and-form family (`shape`, `layer`, `space` applied to a
  schema/type/API) — the first `software-english` issue the Routine has
  claimed since the pool-of-two-trackers fix below. Wording-only fix:
  worked examples added to the rule's description in
  `rules/core-rules.toml` and to `spec/SPEC.md` §5.5; no `banned.tsv`
  change, since those nouns have legitimate literal uses in the repo's
  own templates. Shipped on `software-english` `main` at `866bf42`,
  released as `v0.0.11`, issue closed. Because the change touched
  `rules/core-rules.toml`, also bumped and released `swe`'s pin:
  `claude-plugins` `main` at `b15a955`, released as `swe-v0.17.1`. See
  [tasks/software-english-issue-1-container-and-form-metaphor.md](tasks/software-english-issue-1-container-and-form-metaphor.md).
- `claude-plugins` #16, a model-backed check before an outbound
  action: Jim's answer is no. A `swe` hook never starts a model
  process, so the documented rule stays. The wider topic is parked in
  [tasks/future-model-backed-pre-action-check.md](tasks/future-model-backed-pre-action-check.md).
  The issue now has `agent:hold` in place of `supervisor`, with the
  answer in a comment.
- `MAINTAINER-RUN.md`, issue routing. Twelve `software-english` issues
  (#1 to #4, #6 to #13) sat unclaimed from 2026-09-20 to 2026-10-19.
  `/swe:send-feedback` files a finding on a core rule on
  `software-english`, and the Routine claimed only from
  `claude-plugins`. A run on 2026-10-08 found the gap and recorded it
  only in the design file, so nothing told Jim. Jim chose to keep the
  issues where they are: the claim step now reads both trackers as one
  pool, oldest first, with the release steps for a `software-english`
  issue (its own `release.yml`, then a `swe` pin bump and release only
  when `rules/core-rules.toml` or `vocabulary/` changed). A fix that
  also resolves another open issue closes that one too
  (`software-english` #2 and #13 ask the same thing, as do #10 and
  #11). Two process fixes in the same edit: a run that claims nothing
  writes nothing to `planning`, since empty runs had added 169 commits
  of timestamps to this file since 2026-10-08; and the report line
  names skipped issues and any blocking scope question, so it arrives
  as a push notification. No release: `planning` only. No task file;
  the decision is in
  [tasks/future-self-maintaining-repo.md](tasks/future-self-maintaining-repo.md).
- [tasks/issue-17-headings-as-prose.md](tasks/issue-17-headings-as-prose.md)
  ([#17](https://github.com/jimbarritt/claude-plugins/issues/17)): eighth
  real issue worked end to end by the self-maintaining-repo Routine,
  single pass, no escalation. The inference tier judged body prose only,
  so a metaphor or contrastive frame used as a heading went unchecked
  even once the body reached a clean state. `lint-file`'s Step 4 now has
  two passes (body, then every heading as its own contiguous list,
  against the same rules); the output style gets a matching "Headings"
  section. No code change: the deterministic tier already lints heading
  lines via `prose_lines()`, and the heading list is built from the same
  `Read` output the body pass already uses. Two of the four faults named
  already have a catalogue rule (`no-metaphor-or-analogy`,
  `no-contrastive-framing`); the other two (a rhetorical heading, a
  heading that withholds its content) have none, proposed separately
  against `software-english` per the issue itself, so the new text does
  not name them as faults to report. `agent-guide.md` updated to match,
  including a "Known limits" bullet naming that gap. One
  implementation-time correction: a sentence in the `agent-guide.md`
  addition read as a mild negative/contrastive statement, reworded
  positively before committing, this repo's own prose rules applied to
  itself. All six test suites pass (142 assertions, unchanged — prose
  only, no test needed); the deterministic tier reports zero findings
  against the edited `SKILL.md`. Version bumped `0.16.4` -> `0.17.0`.
  Shipped on `main` at
  [`79ad2a8`](https://github.com/jimbarritt/claude-plugins/commit/79ad2a8),
  which closed the issue automatically, released as
  [`swe-v0.17.0`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.0).
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
