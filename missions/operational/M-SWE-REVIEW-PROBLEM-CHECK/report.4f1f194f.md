# Report: claude-plugins#36 — problem-alternative-steps (SPEC §7.24)

## What shipped

**`software-english`**

- New document type, Review Comment: `templates/review-comment.md`,
  an Appendix F row and paragraph, a §7.8 type-list mention, and a
  README.md type-count bump (fifteen → sixteen types).
- New SPEC section, §7.24 "Problem, alternative, and steps in a
  review comment (Inference-based)", appended at the end of §7 (no
  existing section renumbered). Three checks: the first paragraph
  states the problem before any evidence; the comment names an
  alternative; each step names an artefact and an action. Applies in
  full to a Review Comment, and narrowed to the opening-sentence
  check only on a PR Description (the other two presuppose a change
  not yet built).
- New catalogue entry in `rules/core-rules.toml`:
  `problem-alternative-steps`, inference-based, conditional on
  document type.
- `templates/pull-request.md` updated: the Problem item gets the
  §7.24 cross-reference, the "rules for this type" section grew from
  two to three, and a Review Comment row was added to the
  neighbouring-types table.
- `COLOPHON.md` and the intro deck
  (`docs/public/presentations/intro/`) updated with the new rule's
  rationale and the new rule/type counts; the deck was rebuilt
  (`build/intro-to-software-english.{html,pdf}`).
- Commits: [`4ae2350`](https://github.com/jimbarritt/software-english/commit/4ae2350)
  (the rule and type), [`2db8cc9`](https://github.com/jimbarritt/software-english/commit/2db8cc9)
  (follow-up: removed two anthropomorphic verbs — "asks", "comes" /
  "stand in for" — from the catalogue text, found by re-reading the
  shipped entry against the same rules it now enforces).
- Releases: [`v0.0.37`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.37),
  then [`v0.0.38`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.38).

**`claude-plugins`**

- `swe/software-english.json` pin moved to `v0.0.38`;
  `swe/.claude-plugin/plugin.json` version moved 0.27.0 → 0.27.2
  (one bump per pin move).
- Commits: [`4e1f005`](https://github.com/jimbarritt/claude-plugins/commit/4e1f005)
  (`Closes #36`), [`bfd83ec`](https://github.com/jimbarritt/claude-plugins/commit/bfd83ec)
  (follow-up pin bump).
- Release: plugin version `0.27.2`, tag `swe-v0.27.2`.
- No code change needed: the `lint-file` worklist already judges
  every paragraph of a file against each catalogued inference rule,
  so the new rule reaches a lint pass through the pin bump alone.
- All 21 `swe/tests/*.sh` suites pass; `scripts/check-unshipped.sh`
  reports both `swe` and the pin up to date.

## What was found along the way

- `spec/SPEC.md` already carries 23 pre-existing deterministic-tier
  findings (mostly `banned-word` on "the reader"/"holds"/"carries",
  used throughout the spec's own rule-description prose, which
  quotes the words it bans). These predate this change, are far from
  anything this issue touched, and were left alone: fixing them is a
  large, separate, unrelated cleanup. Verified by diffing the error
  count before/after this change (27 before my edit introduced 4 of
  its own → 23 left after I fixed those 4; all 23 remaining are
  outside the lines this change touched).
- The two canonical sources for Review Comment
  (`google.github.io/eng-practices/review/reviewer/comments.html`,
  `conventionalcomments.org`) could not be fetched for a live check:
  this session's network policy does not resolve either host. Both
  are well-known, correctly-spelled URLs, and the same
  `google.github.io/eng-practices/...` domain is already a canonical
  source for PR Description in the same table. Not verified live.
- Out of scope, worth a separate issue: the GitHub review-comment
  MCP tools (`add_comment_to_pending_review`,
  `pull_request_review_write`, `add_issue_comment`) are not matched
  by any `swe` hook (`hooks.json` matches Bash/Artifact/Gmail/Drive/
  Slack, not MCP calls) — only `gh pr review`/`gh pr comment` go
  through `bash-check.sh`. A review comment posted through those MCP
  tools is never checked by this plugin at all.
- The issue's "a review comment or a PR body" was read narrowly: on
  a PR description only the problem-first check applies (the change
  is already built, so "steps to build it" has nothing left to
  apply to, and the template already asks for rejected alternatives).
  Noted on the issue as something the supervisor can ask to widen.

## Scoping decision

A new Review Comment document type plus a rule scoped to it (full),
narrowed on PR Description (opening sentence only) — rather than a
type-agnostic rule (rejected: most types have no alternative or steps
to state) or folding review comments into PR Description (rejected:
a PR description states a change already made; a review comment asks
for one not yet made). Recorded as a mission decision.
