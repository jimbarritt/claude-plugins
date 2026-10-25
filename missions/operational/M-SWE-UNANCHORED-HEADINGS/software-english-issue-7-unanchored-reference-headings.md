# software-english#7: no-unanchored-reference and headings

[Issue #7](https://github.com/jimbarritt/software-english/issues/7)
("no-unanchored-reference: rule description gives only body-prose
examples, so headings escape the inference tier"), opened by
jimbarritt-pleo on 2026-09-29. Claimed by the self-maintaining-repo
Routine on 2026-10-20.

## The ask, verbatim

> SPEC 7.5 states that an unanchored reference can appear in a heading.
> The rule description sent in the inference block gives only
> body-prose examples (`the design`, `the decision`, `this change`),
> so the judging pass did not apply it above the body text.
>
> A design document passed both tiers carrying four question-shaped or
> unanchored headings, all of the form "What this <verb>" or "Which
> <noun> <verb>":
>
> - What this costs
> - What this removes
> - Which process owns the cache
> - What an entry contains
>
> Each names a referent the heading itself never establishes.
>
> Direction: name headings explicitly in the 7.5 rule text, and add a
> worked example of the "What this X" heading shape so the judging
> pass has a pattern to match against rather than body-prose examples
> alone.

## Reading

The inference tier has no code: `/swe:lint-file` passes the rule's
`description` field in `rules/core-rules.toml` to the judging model
word for word, as `inference pending: <description>`. For an
inference-tier rule, that field is the whole rule.

Confirmed the gap: `no-unanchored-reference`'s current `description`
(line 130) never mentions headings, only body phrases (`the design`,
`the decision`, `the plan`, `this change`). `spec/SPEC.md` §7.5 already
says the fault "can appear in a heading or in body prose" and gives one
heading example of the definite-noun kind (`Facts that shape the
design`), but neither file covers the issue's narrower "What this
<verb>" / "Which <noun> <verb>" question-shaped heading, where the
fault is a bare `this` with nothing after it, or a noun with no
antecedent.

No generated artefact mirrors `core-rules.toml` (the old YAML catalogue
was deleted in commit 8804a21/7ee28d6). No check script or Makefile
exists in `software-english`; the only CI is `.github/workflows/release.yml`,
run by hand. No version file exists to bump.

## Plan

1. `rules/core-rules.toml` line 130: rewrite the `no-unanchored-reference`
   `description` to put every heading in scope (not only body prose),
   keep the existing definite-noun heading example, and add the
   question-shaped heading pattern with the issue's four headings as
   worked examples, plus a policy line that a bare `this`/`that`/`it`
   in a heading is a fault even under a parent heading that names a
   subject (a heading is also read alone — in a contents list, a link,
   a search result). Switch the TOML string from single-quoted literal
   to a double-quoted basic string (matches lines 51/159) to drop the
   em dash the current text has (breaks this repo's own `no-em-dash`,
   §3.5) and to allow the apostrophe in "writer's".
2. `spec/SPEC.md` §7.5 (after the existing Fault/Fix block, around line
   607): add a matching second Fault/Fix block for the question shape,
   with the same four worked examples and the "read alone" policy
   line, wrapped at the file's usual ~72 columns.
3. Verify: TOML parses and the description contains no em dash; `git
   diff --stat` touches only the two files; run `/swe:lint-file` on
   `spec/SPEC.md` (not `core-rules.toml` — not Markdown, no headings,
   rule data not document prose); hand-check the new description text
   against a small sample with the issue's four headings under a named
   parent heading (expect 4 findings) and their fixed forms (expect 0).
4. Commit on `main`, message ending `closes #7`. No version bump (no
   version file in this repo).
5. Release: run `software-english`'s `release.yml` with the next patch
   version after the newest `v*` tag (pinned catalogue is v0.0.15, so
   likely v0.0.16 — confirm against the actual release list first).
   Because this change touches `rules/core-rules.toml`: also bump the
   tag in `claude-plugins`' `swe/software-english.json` to the new
   release, bump `swe`'s own `plugin.json` version, push
   `claude-plugins` `main`, and run `release-plugin.yml` for `swe`.
6. Close the loop: comment on #7 with the commit and release tags,
   close if the commit didn't already.

Full plan detail (verbatim TOML/SPEC.md text) came from an Opus Plan
subagent dispatched during this run; the text above is this session's
own summary of it, not a verbatim copy.

## Outcome

Applied the plan as drafted, no deviation. Edited `rules/core-rules.toml`
line 130 (description, widened as planned, em dash dropped) and
`spec/SPEC.md` §7.5 (second Fault/Fix block added after the existing
one). Verified: TOML parses; no em dash in the new description;
`git diff --stat` touched only the two intended files.

Ran `/swe:lint-file`'s underlying script (`--diff spec/SPEC.md
--force-inference --quiet-vocab`) directly, since the `swe` plugin
is not installed as a skill in this session. Deterministic tier: 19
pre-existing errors elsewhere in `SPEC.md` (banned words: "holds",
"the reader", "carry", "load-bearing", "live"; one `no-continuous-tense`
hit), none in the new lines — out of scope for this issue, not fixed.
Inference tier: judged the new text by hand against all 16
`inference pending` rules Step 3 printed; found no violation in the
new text (no banned-word hits, no pronoun-chained clipped-sentence
run, no catch-all-verb reuse, the heading-pattern `this` occurrences
are inside backtick code spans quoting the pattern itself, matching
the existing 7.5 passage's own style). Recorded the ledger row
honestly as `failed` with `--findings 19` (the deterministic tier's
real, pre-existing total for this file), not `clean` — no commit
hook is installed in this environment, so nothing was blocked by
that choice.

Committed on `main`: `f7890c2`, message ends `closes #7`. Pushed. No
version bump (no version file in this repo). Released:
`release.yml` run with `version: 0.0.16` (newest prior tag was
v0.0.15) — run
[39379460663](https://github.com/jimbarritt/software-english/actions/runs/39379460663),
success, tag
[v0.0.16](https://github.com/jimbarritt/software-english/releases/tag/v0.0.16).

Because the change touched `rules/core-rules.toml` (a file `swe`
fetches): bumped `swe/software-english.json`'s `tag` to `v0.0.16` and
`swe`'s own `plugin.json` version `0.17.6` → `0.17.7`, commit
`e9a73b3` on `claude-plugins` `main` ("swe: bump pinned
software-english tag to v0.0.16"), pushed, ran `release-plugin.yml`
with `plugin: swe` — run
[39379580040](https://github.com/jimbarritt/claude-plugins/actions/runs/39379580040),
success, tag
[swe-v0.17.7](https://github.com/jimbarritt/claude-plugins/releases/tag/swe-v0.17.7).
Confirmed with `scripts/check-unshipped.sh` before and after the bump
(after fetching tags, since local tags lagged the earlier release).

Commented on #7 with the commit and release links. Issue auto-closed
by the `closes #7` commit before the comment landed (`closed_by:
jimbarritt`, `state_reason: completed`). Removed the `agent:working`
label, kept `auto-fix-candidate`. No other open issue, on either
tracker, is resolved by this change.

Single pass, no escalation.
