# Plan: software-english#32, `scope-escalation`

## The ask, verbatim

Title: "Rule: a sentence whose only content ranks the problem against a lesser case"

> A sentence in a PR description stated no fact. Its whole content compared the problem with a smaller one, and the substance was deferred to the next sentence. Both tiers passed it.
>
> A neutral example:
>
> > That breaks more than the nightly job.
>
> Such a sentence names what the problem exceeds, never what it is. Cutting it and stating the wider case directly costs nothing.
>
> Proposed id `scope-escalation`, fix `CUT`, state the wider case directly.
>
> Two tiers are needed. A deterministic tier for fixed openers that are escalation and nothing else: `Not just`, `More than just`, `This is not only`, `This is bigger than`, `It goes further than`. An inference tier for the general `<verb> more than <noun phrase>` shape, because a literal rule on `more than` fires on measurement, as in `takes more than 30 seconds`.
>
> This is a sibling of the ban on meta-remarks about the writing. It is aimed at the subject rather than at the prose.

## Reading

The issue asks for a new rule, `scope-escalation`, catalogued the same way every mixed (fixed-list plus general-shape) rule in this catalogue is: the fixed openers go into `vocabulary/banned.tsv`, caught by the existing deterministic `banned-word` rule; the general `<verb> more than <noun phrase>` shape becomes one new inference-based `[[rules]]` entry, distinguished explicitly from measurement uses of "more than" and from every sibling rule it could be confused with (`no-remark-about-the-writing`, `no-contrastive-framing`, `no-split-contrast-pair`). The new rule needs a SPEC.md section, a COLOPHON.md rationale note, and the intro deck's rule counts need incrementing and the deck rebuilt.

## The plan (from an Opus Plan subagent, verified against the repo's own conventions and git history)

### Section choice: SPEC §5.12, "No scope escalation (mixed)"

Appended at the end of §5 ("Semantic rules", where the existing mixed fixed-list/inference rules already live: §5.1, §5.3, §5.5, §5.6), so no existing § citation renumbers — the same reasoning the repo used when appending §7.23 and §8.4. §5.3 (closest sibling) was rejected because §5.3's faults are about the reader or the document, not the subject; §8.5 (Register) was rejected because every §8 rule is inference-only with no fixed list, while this rule is mixed.

### Facts found that refine the ask

1. **Banned-word matching is case-insensitive and word-boundary, not full-line.** (`software_english_lint.py` lines 997-1013, `\b<phrase>\b` with `re.IGNORECASE`.) Case variants of the five openers are therefore redundant — but a contracted form (`isn't just`) is a different string and needs its own row.
2. **The phrases already occur in prose**, unlike most past additions:
   - `software-english/docs/public/presentations/intro/samples/gmail-messages-before.md:17` has "isn't just" — harmless, the file is in `.swe-ignore`.
   - `claude-plugins` has five "not just" hits (`swe/skills/send-feedback/SKILL.md:76`; `swe/README.md:293`; `swe/docs/agent-guide.md:19,702,726,907`). Four are real escalations; `agent-guide.md:19` ("do not just work around") is a false positive where "just" means "only" — accepted, same precedent as `carry`/`hold` on the fixed list. This is a **follow-up in claude-plugins**, out of scope for this change (fixing it needs a release-pin bump first).
3. **No double-report risk**: "It goes further than" also contains "goes" (on `anthropomorphism-fixed-list`), but the linter already suppresses an anthropomorphism match inside a banned-word span, so only banned-word fires.
4. **The deck's SVG rule count is already stale** independent of this change: commit 44831c5 updated the body-text count (42→43) but missed the SVG box (still 36, one behind the body text's implied 37). This plan increments the SVG box by its own +1 (36→37) rather than jumping it to match the already-drifted body text, and does not open a new issue for the pre-existing drift — noted here only.
5. **No code change needed in claude-plugins.** `swe/software-english.json` pins `{"repo": "jimbarritt/software-english", "tag": "v0.0.35"}`; bumping it to the new release tag is a later pipeline step (release + pin bump + `release-plugin.yml`), not a file edit in software-english.
6. **No CI validates the TOML/TSV in software-english** — the parse and tier counts must be checked by hand (`python3 -c "import tomllib;tomllib.load(open('rules/core-rules.toml','rb'))"`, then the two tier-count greps, expecting 6 deterministic / 38 inference-based).

### Exact edits

1. **`vocabulary/banned.tsv`** — append a new heading block with 7 rows (5 from the issue + 2 contracted forms, `isn't just` / `this isn't only`), fix text `CUT, and state the wider case` (plain `CUT` would lose half the issue's intent).
2. **`rules/core-rules.toml`** — one new `[[rules]]` block, `id = "scope-escalation"`, `tier = "inference-based"`, `check = "model-judgement"`, `severity = "warning"`, full description text drafted by the subagent (states the fault, the fix, the test, what is excluded — measurement, quantity comparison, a sentence that already states the wider case, quoted material — and explicit "Distinct from" cross-references to `no-remark-about-the-writing`, `no-contrastive-framing`, `no-split-contrast-pair`, and a non-existent `no-out-of-scope-comparand` reference to verify/correct against the actual catalogue before committing). Add one "Distinct from scope-escalation" sentence each to `no-remark-about-the-writing` and `no-contrastive-framing`.
3. **`spec/SPEC.md`** — new `### 5.12 No scope escalation (mixed)` section after §5.11 and before `## 6. Vocabulary rules`, plus its Contents-list entry; cross-reference bullets added to §5.3 and §5.7.
4. **`COLOPHON.md`** — new section "Scope escalation: a mixed semantic rule at the end of §5" explaining the false negative, why §5.3/§5.7/§8.4 don't already cover it, the §5.12 placement rationale, and the tier split (including the pre-existing "not just" hits in claude-plugins prose and that the plugin itself needs only a release-pin bump).
5. **Intro deck** (`docs/public/presentations/intro/intro-to-software-english.md`) — body text 43→44 rules, "6 are deterministic" unchanged; SVG box inference count 36→37 (see point 4 above). Rebuild with `bash docs/public/presentations/intro/build.sh`; commit the regenerated HTML/PDF, never hand-edited.
6. **Lint** every touched prose file (SPEC.md, COLOPHON.md, commit message, this document) with the full two-tier lint-file procedure until clean, quoting the new fixed phrases only inside code spans/blockquotes so banned-word does not fire on the catalogue's own description of itself.
7. **Spot-check** the deterministic tier on three throwaway lines before committing: an escalation opener (expect banned-word), "It goes further than the import." (expect banned-word only, no anthropomorphism double-report), and "The import takes more than 30 seconds." (expect no finding).
8. **Commit** to `main`, subject in the house style ("Catalogue a scope escalation as scope-escalation (SPEC §5.12)"), body covering the false negative / why siblings don't match / the tier split, `closes #32`, with the required attribution lines.
9. **Release** (later pipeline step, not a file edit): run software-english's `release.yml` with the next patch after the newest `v*` tag; since this change touches `rules/core-rules.toml` and `vocabulary/`, also bump `swe/software-english.json`'s tag, bump `swe`'s own `plugin.json` version, push claude-plugins `main`, and run `release-plugin.yml` for `swe`.

### Decisions logged separately via `tsk decision add`

D1 rule split (fixed list → banned.tsv, one new inference rule for the shape); D2 SPEC placement (§5.12, appended, not §5.3/§8.5); D3 two contracted forms added beyond the issue's five; D4 accepted false positive on "do not just work around"; D5 fix text `CUT, and state the wider case` rather than plain `CUT`; D6 deck SVG box set to 37 (own prior value + 1), pre-existing drift from body text noted but not corrected as part of this issue.

### Follow-up noted, not actioned here

The five "not just" occurrences in `claude-plugins/swe` prose (four real escalations, one false positive at `agent-guide.md:19`) will surface as banned-word errors once the pin is bumped. Left for a separate pass; not created as a new issue per the one-issue-per-run rule.
