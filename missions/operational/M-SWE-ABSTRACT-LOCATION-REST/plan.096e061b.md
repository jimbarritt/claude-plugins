# Plan: abstract-location fires on the protocol name REST

Mission: M-SWE-ABSTRACT-LOCATION-REST
Issue: software-english#31 — https://github.com/jimbarritt/software-english/issues/31

## The ask (verbatim)

> The rule matches the bare token `rest`, so it fires on `REST` as the name of the protocol. There the word is the one correct name for the thing, not the abstract sense the rule targets.
>
> A neutral example that fails today:
>
> > The adapter exposes no REST endpoint, because that module runs inside the host process.
>
> Any document about an HTTP API trips this. The only way past is to avoid naming the protocol, which is worse prose than the fault the rule guards against.
>
> Fix direction: exempt the token when it is capitalised as `REST`, or when it is next to `API`, `endpoint`, `call`, `route`, or `Web Services`.

## Reading

`abstract-location` must not report the protocol name `REST`. This needs a code
change in `claude-plugins` as well as a data change in `software-english`: the
rule data alone cannot express the exemption, because the checker lowercases
the line before it matches, destroying the case distinction between the verb
`rest` and the acronym `REST`.

## Key findings

1. **The fix needs claude-plugins code.** In
   `/home/user/claude-plugins/swe/scripts/software_english_lint.py`,
   `check_line()` sets `lowered = line.lower()` (line ~1224), then matches
   every `word_list` phrase for `abstract-location` (and
   `anthropomorphism-fixed-list`) against `lowered`. `subject_gate_passes()`
   also reads only `lowered`. Neither the checker nor the rule schema can see
   original case today. A new rule field with no checker change would do
   nothing. The mission covers both repos, following the #27 precedent
   (software-english commit b43ce39 + claude-plugins commit d9af284).
2. **The issue's own example sentence does not actually fire today**, verified
   against the real `structure.tsv`/`core-rules.toml`: "adapter" is not a
   structure noun, so the lookback gate fails independently of the bug. The
   bug is still real — it fires on "The service exposes a REST API." and "The
   request is a REST call." — so regression tests use sentences like those,
   plus the issue's own sentence as a clean-stays-clean guard.
3. `rest` is in no other rule's `word_list` and not in `vocabulary/banned.tsv`.
   `abstract-location`'s `word_list` is the only place to fix.
4. `LITERAL_TOKEN`/`is_literal_token()` already detect acronyms but are used
   only for vocabulary-membership. A blanket "skip all-caps" rule would also
   exempt unrelated all-caps text (e.g. a capitalised heading). An explicit,
   self-documenting list of exact-case exemption tokens is narrower and is
   the chosen approach.
5. The acronym has no inflected forms ("RESTs"/"RESTed" are not real usage).
   The exemption applies to the exact token `REST` only; lowercase
   `rest`/`rests`/`rested` keep firing exactly as today.
6. `str.lower()` can change string length for some Unicode input, which would
   desync offsets between `lowered` and the original `line`. The checker
   change guards against this and falls back to no exemption rather than
   guessing.
7. Out of scope, follow-up candidate (not fixed under #31): `abstract-location`
   has no determiner/noun-use exemption (unlike `anthropomorphism-fixed-list`'s
   `NOUN_USE_DETERMINERS`), so "The file is the rest of it." still fires on the
   noun "rest" today. Leave for a separate issue.

## Scope decision

- Exempt only on exact capitalisation: the literal token `REST`.
- No adjacency check (API/endpoint/call/route/"Web Services"): capitals alone
  are enough to distinguish the acronym from the verb, since the verb "rest"
  is never written in all capitals in normal prose. Adjacency would need a
  look-ahead the gate does not have today, for no real gain.
- No change to `word_list`: removing `rest` would lose real findings.

## Plan

Order: software-english first (data + spec + release), then claude-plugins
(checker + tests + pin bump), because claude-plugins pins a released
software-english tag.

### software-english (closes #31)

1. `rules/core-rules.toml`, `[[rules]] id = "abstract-location"`: add
   `case_sensitive_exemptions = ["REST"]` after `word_list`, and extend
   `description` with a sentence documenting the exemption and a `"The
   service exposes a REST API."` example.
2. `spec/SPEC.md` §5.2 (abstract-location): add one short paragraph
   documenting that `REST` written in capitals is exempt, as the protocol
   name rather than the verb.
3. Lint both changed files with the project's own Software English rules
   (per the lint-file procedure), then commit with `closes #31`, noting in
   the body that the deterministic implementation lands in
   jimbarritt/claude-plugins. Push `main`. Release the next patch tag
   (expected v0.0.35) via `release.yml`.

### claude-plugins (checker, tests, pin)

4. `swe/scripts/software_english_lint.py`, `check_line()`: read
   `exempt = set(rule.get("case_sensitive_exemptions", []))` before the
   `word_list` match loop (default empty keeps older pinned tags and
   scratch test catalogues working); inside the match loop, before the
   subject gate, skip the match when the original (non-lowered) slice at
   that span equals an exempt entry, guarded by a length check between
   `line` and `lowered` so a Unicode lowering mismatch falls back to firing
   as today rather than guessing. Comment references software-english#31.
   Applies generically to any word_list rule that sets the field; the
   do-support loop (motion-verb negation) is untouched since base forms are
   never acronyms.
5. Extend `swe/tests/anthropomorphism_gate_test.sh` (abstract-location block,
   `location()` helper): add real-data cases (fires on "The config rests in
   the environment file." and "This rests on the cache."; stays clean on
   "The service exposes a REST API.", "The request is a REST call.", and the
   issue's own sentence) and a scratch-catalogue pair that proves the
   `case_sensitive_exemptions` field works and that its absence still fires
   on REST (proving the default).
6. Run the `claude-plugins` test suite (`swe/tests/*_test.sh`) against the
   new software-english checkout; all tests pass.
7. Bump the pinned tag in `swe/software-english.json` to the tag cut in step
   3. Commit checker + tests, then the pin bump (or together), referencing
   software-english#31. Bump `swe`'s own `plugin.json` version per the repo's
   release rule and run `release-plugin.yml`.
8. Optional follow-up: file a new software-english issue for finding 7 (noun
   use of "rest" after a determiner). Not fixed here.

## Escalation

Not needed — one-run fix. The only coordination point is doing the
software-english release before bumping the claude-plugins pin, which the
plan already orders correctly.
