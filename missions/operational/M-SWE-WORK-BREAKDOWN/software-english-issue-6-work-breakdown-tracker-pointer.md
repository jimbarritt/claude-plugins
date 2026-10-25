# software-english#6: Design exemption too broad for work-breakdown narrative and issue-tracker ids

## The ask (verbatim)

> A design document passed both tiers with a sentence that stated which part of the work the current piece covers, which part a later piece covers, and cited an issue-tracker id as the pointer to that later work.
>
> `no-planning-content-in-reference` matches this shape but is conditional on document type Reference, and never fires on Design or API Design. That exemption is too broad. A design document legitimately carries open questions and future extensions, so the exemption cannot be removed wholesale. Two kinds of content within its scope should still fire on a design document:
>
> - Work-breakdown narrative: dividing the subject into "this piece of work" and "a later piece of work". That is scheduling, not design.
> - An issue-tracker id used as the pointer to that later work. It is not design content, it rots faster than a PR number, and a reader a year later cannot resolve it.
>
> Direction: split the rule's two concerns. Keep future-direction content allowed on Design, and make work-breakdown narrative and a bare issue-tracker reference fire on every document type outside a References section.

Opened by `jimbarritt-pleo` (trusted collaborator), 2026-09-29. Oldest
open issue across both trackers at claim time (`claude-plugins`#16,
the only other open issue, carries `agent:hold`).

## Reading

An Opus Plan subagent read `rules/core-rules.toml`, `spec/SPEC.md`
§7.8-§7.9, `templates/design.md`, `templates/reference.md`, and
`templates/api-design.md` in full, plus `COLOPHON.md`,
`templates/rfc.md`, `templates/lab-notebook.md`,
`templates/portfolio-journal.md`, and `vocabulary/banned.tsv`.

Three judgement calls made, none rising to the two-materially-different-
readings escalation bar:

1. **"Every document type" means every type, RFC and ADR included.**
   The existing rule's own rationale (`COLOPHON.md`) says planning
   content broadly is correct in a plan, an RFC, or an ADR — but the
   issue asks for these two specific sub-faults (not planning content
   generally) to fire everywhere outside a References section, with no
   carve-out named for RFC/ADR. Taken literally, since the issue's own
   text is explicit.
2. **A tracker id's fault is defined by role, not by issue vs. PR.**
   The issue's "rots faster than a PR number" reads as a severity
   comparison, not an exemption for PR numbers. The new rule's fault
   condition is "an id used as the pointer to work the document does
   not itself state", so a PR number used that way still fires; one
   cited as a past change (as this repo's own commits already do with
   `closes #N`) does not, because it states no future work.
3. **Lab Notebook and Portfolio Journal need a narrow exception.**
   Checked both templates directly: a Lab Notebook entry must name the
   task it belongs to, and a Portfolio Journal entry records work
   already done. Neither divides work into current/later pieces or
   points to later work, so the rule's own role-based fault definition
   already does not match them — the exception is stated explicitly
   anyway, to reduce false-positive risk in the model-judgement check.

## Plan (from an Opus Plan subagent, model opus)

One new inference-tier rule rather than a split into two, since the
tracker-id fault is scoped as part of the same work-breakdown concern:

- `no-work-breakdown-or-tracker-pointer`, new SPEC §7.14 (appended
  after §7.13, not inserted as "§7.9a" — renumbering would break every
  existing cross-reference to §7.10-§7.13 in both the TOML and
  `SPEC.md`'s own Contents list). No `applies_to_document_type` key:
  unconditional, the only rule besides the existing conditional one to
  need this distinction stated explicitly.
- Two faults named in one rule: a work-breakdown sentence (dividing the
  subject into units of work) and an issue-tracker pointer (an id used
  in place of a stated fact about later work). Takes precedence over
  `no-planning-content-in-reference` where both would match the same
  sentence in a Reference document, to avoid double-reporting.
- `no-planning-content-in-reference`'s own description and SPEC §7.9
  amended: the Design exemption now explicitly covers the
  open-questions and future-extension sections only, with a
  cross-reference to §7.14 for the two narrower faults.
- `templates/design.md`, `templates/api-design.md`, and
  `templates/reference.md` updated to state the same narrowing.
- `COLOPHON.md` given a new section explaining why §7.14 is
  unconditional where §7.9 is conditional, and why it sits at the end
  of §7 rather than beside §7.9.

## Work

All five files edited as planned: `rules/core-rules.toml` (24 rules
total, TOML parses, ids unique), `spec/SPEC.md` (Contents entry, two
§7.9 paragraphs, new §7.14, two Appendix F paragraphs),
`templates/design.md`, `templates/api-design.md`,
`templates/reference.md`, `COLOPHON.md`.

Three self-checks caught during implementation, not anticipated in the
plan, all found only by actually running the real linter against the
drafted text, not by reading it back:

- "The division is scheduling." (both in `SPEC.md`'s new §7.14 and in
  the TOML rule's own description) matches `no-continuous-tense`'s
  `is|are|was|were` + `-ing` pattern even though "scheduling" is a
  gerund-as-noun, not a continuous verb. Reworded to "a scheduling
  choice" in both places.
- Two em dashes and one instance of the banned word "carries" in the
  new `COLOPHON.md` section.
- Two sentences in `templates/design.md` and one in
  `templates/reference.md` exceeded the 20-word sentence-length
  ceiling after the edit combined old and new text onto one line;
  split into shorter sentences, re-verified against the linter.

The TOML rule descriptions themselves carry pre-existing
`sentence-length` warnings throughout the file (every long rule
description does, including the ones this issue touches) — left alone,
consistent with the file's existing convention; this is a dense
machine-readable catalogue fed to a model-judgement check, not
reader-facing prose.

`swe/data` (gitignored, populated at release time from a pinned tag)
does not exist in a fresh `claude-plugins` checkout, so it was
populated locally with `swe/scripts/sync-from-software-english-repo.sh`
from this run's own local `software-english` checkout, to run the real
`software_english_lint.py` and the real test suites against the
pre-release content, then removed again before committing (the
checked-in `.gitignore` already excludes it).

Verified directly against the real linter:

- Both new/amended rules load into the `--force-inference` advisory
  block without error.
- `--diff --added-only` on the five touched Markdown files reports
  zero errors and zero warnings on every changed line, after the three
  fixes above (note: `--diff` mode replaces the file list with
  `git diff`-detected Markdown files, so `rules/core-rules.toml` needed
  a separate full-file check, cross-referenced against `git diff
  --unified=0` to isolate which findings were pre-existing versus
  introduced by this change).
- All six `claude-plugins` test suites pass (142 assertions, unchanged
  from the prior run — no code change, rules/prose only).
- `scripts/check-unshipped.sh` clean on `software-english` before
  release, and correctly reports `claude-plugins`' `swe` pending
  release after the pin bump, before that release ran.

## Shipped

`software-english` `main` at
[`2556a26`](https://github.com/jimbarritt/software-english/commit/2556a26),
released as
[`v0.0.15`](https://github.com/jimbarritt/software-english/releases/tag/v0.0.15),
closing the issue automatically (`closes #6`). Because the change
touched `rules/core-rules.toml`, `claude-plugins` pin bumped to that
tag and `swe` version `0.17.5` -> `0.17.6` on `main` at
[`6859d31`](https://github.com/jimbarritt/claude-plugins/commit/6859d31),
released as
[`swe-v0.17.6`](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.6).

Single pass, no escalation.

## Note: a commit-message mistake caught and fixed before push

The first `claude-plugins` pin-bump commit was malformed: a shell
heredoc was closed in the wrong place, folding a nonsensical
`closes software-english#6 (no change to this repo's own content)`
line into the subject, and the Co-Authored-By/Claude-Session
attribution footer was missing from both this commit and the
`software-english` commit on the first attempt. Both caught by reading
the commit back with `git show -s --format="%B"` before pushing, and
fixed with `git commit --amend` (neither commit had been pushed yet).
