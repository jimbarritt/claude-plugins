# Plan: claude-plugins#36 — a structural check that a review comment states the problem first

## The ask, verbatim (claude-plugins#36, opened by jimbarritt-pleo)

> A PR review comment took four rewrites before it was readable. The deterministic
> tier passed every version, including the first.
>
> The rules score single words and sentence length. Nothing scores whether the
> opening states the problem. A clean report read as a finished draft, so the text
> stayed dense and evidence-first through three versions. What was wanted was one
> plain claim up front: this change solves a local-development problem by editing
> production code behind a config flag. Then the alternative. Then the steps to
> build it.
>
> Ask: a structural check for a review comment or a PR body, in the inference
> tier. Does the first paragraph name the problem in one sentence. Is an
> alternative stated. Are the steps concrete enough to act on.

## Reading

The deterministic tier (word/vocabulary/sentence-length checks) cannot judge
whether a review comment opens with the problem, states an alternative, or
gives concrete steps — that needs judgement, so it belongs in the inference
tier. `rules/core-rules.toml` in `software-english` already stores
inference-tier rules as catalogue entries (`tier = "inference-based"`,
`check = "model-judgement"`) whose `description` text is what
`software_english_lint.py` prints into the `===INFERENCE_ADVISED===` block
that a lint-file pass judges the worklist against. A new catalogue entry
there reaches every inference pass with no `claude-plugins` code change.
`claude-plugins` needs only the routine pin-bump release that follows any
`core-rules.toml`/`vocabulary/` change.

"Review comment" is not an existing document type (no match in `spec/` or
`templates/`); the nearest type is PR Description, which states a change
already made — a review comment asks for a change not yet made, so the two
are distinct types. Only the problem-first check transfers to a PR
Description: "alternative" and "concrete steps" presuppose a change not yet
built, which does not fit a PR description of a change already shipped.

## The plan

### `software-english` (the content change)

1. Add `templates/review-comment.md`, mirroring `templates/pull-request.md`:
   canonical sources, what a review comment is, structural conventions
   (problem sentence, optional evidence, alternative, concrete steps, optional
   Conventional-Comments severity label), the one rule for this type (§7.24),
   other rules that apply (§7.1, §7.7, §7.14, §7.15), a neighbouring-types
   table, verify-against-source.
2. Add SPEC §7.24 "Problem, alternative, and steps in a review comment
   (Inference-based)", appended after §7.23 so no existing numbering shifts,
   with a Contents entry. Condition: Review Comment in full; PR Description
   for the problem-first opening only. Three checks (problem first, named
   alternative, concrete steps), each with a fault/fix pair taken from the
   issue's own example. Exemptions (approval, clarifying question, a nit with
   a suggestion block as the step, a reply whose thread already states the
   problem, a one-sentence problem+fix comment). Cross-references to keep
   §7.1/§7.15/§7.7/§7.14 from double-reporting the same fault.
3. Add Review Comment to the §7.8 type list and to Appendix F (source links,
   template link, one paragraph on scope).
4. Append one `[[rules]]` entry to `rules/core-rules.toml`: id
   `problem-alternative-steps`, `tier = "inference-based"`, `check =
   "model-judgement"`, `applies_to_document_type = "review-comment"`
   (informational only — the plugin does not read this field, so the
   condition is restated in full inside `description`, including the PR
   Description clause).
5. Update `templates/pull-request.md`: the Problem item gets "open with one
   sentence that states the problem, before any evidence (SPEC §7.24)"; the
   "two rules for this type" section names §7.24's opening check; add a
   Review Comment row to the neighbouring-types table.
6. Update `README.md` ("fifteen types" → "sixteen types"), `COLOPHON.md` (new
   section explaining why §7.1/§7.15/the template's own prose did not already
   cover this), and the intro deck's rule count (37 → 38; rebuild if marp/
   playwright are available, otherwise note in the commit that `build/` was
   not regenerated).
7. Lint every changed prose file with the `swe` lint-file procedure
   (fetch-software-english-data.sh, `software_english_lint.py
   --force-inference --quiet-vocab`, fix deterministic and inference
   findings, record the clean verdict).
8. Commit (`Refs jimbarritt/claude-plugins#36` — the issue lives in the
   other repo, so no closing keyword here), push `main`, run
   `release.yml -f version=0.0.37` (next patch after the current `v0.0.36`
   tag), confirm the `v0.0.37` tag exists.

### `claude-plugins` (the pin bump and release)

9. Set `swe/software-english.json`'s `tag` to `v0.0.37`; bump
   `swe/.claude-plugin/plugin.json` `version` 0.27.0 → 0.27.1.
10. Run `swe/tests/*.sh` and `scripts/check-unshipped.sh`.
11. Commit with `Closes #36`, push `main`, run
    `release-plugin.yml -f plugin=swe`.
12. Confirm the cached rule data picks up `v0.0.37` and a `--force-inference`
    run lists `[problem-alternative-steps]`.

## Design decision

Scoped the new rule to a new **Review Comment** document type (full rule) plus
a narrow clause on **PR Description** (problem-first opening only), rather than
(a) a type-agnostic rule — rejected, most document types have no alternative
or steps to state — or (b) folding review comments into the existing PR
Description type — rejected, a PR description states a change already made,
a review comment asks for one not yet made.

## Out of scope / follow-up notes (not blocking, to mention in the issue close-out)

- GitHub review comments posted through the GitHub MCP tools
  (`add_comment_to_pending_review`, `pull_request_review_write`,
  `add_issue_comment`) are not matched by any `swe` hook (`hooks.json` matches
  Bash/Artifact/Gmail/Drive/Slack, not MCP calls) — only `gh pr review`/`gh pr
  comment` go through `bash-check.sh`. Not part of this issue's ask; worth a
  separate issue if Jim wants hook coverage there too.
- The issue's complaint that "a clean deterministic report read as a finished
  draft" is a workflow point already covered by the existing "a clean
  deterministic result is necessary, and not sufficient" section in
  `templates/pull-request.md`; the new `review-comment.md` template repeats
  it, no plugin change needed.

## Ambiguity considered, not escalated

"A review comment or a PR body" could be read as asking for all three checks
on both. Rejected: on a PR body the change is already built, so "steps to
build it" has nothing to apply to, and the issue's own worked example is a
review comment, not a PR body. The narrow reading (problem-first only on PR
Description) is used. Extending PR Description to also require a stated
alternative would be a small follow-up to §7.24, not materially different
work, so this was not treated as a scope fork needing a supervisor decision.
