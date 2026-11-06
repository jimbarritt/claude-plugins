# Plan: software-english#24, a rule for a sentence that predicts how a reader reacts

## The ask (verbatim)

> ## Verdict
>
> False negative, no current rule. Three sentences in one procedural guide were found by reading. Neither tier reported them, with current rule data.
>
> ## Shape
>
> A sentence that predicts how the reader will react, or advises the reader with no fact about the subject. Examples with neutral subjects:
>
> - "That may be exactly what you want."
> - "It helps to keep a terminal open as you go."
> - "Choose the region carefully now, before you find out after the first deploy."
>
> Each sentence either states nothing about the system, or puts the fact inside a prediction ("before you find out ..."). The SPEC's commentary guidance covers this class in general, but no rule in the catalogue names it, so the inference pass has no rule to judge it against.
>
> ## Proposed rule
>
> `no-reader-reaction-prediction` (name open), inference tier, warning:
>
> - **Fault:** a sentence whose main clause predicts the reader's reaction, preference or experience ("you may find", "that may be what you want", "it helps to", "you will be glad"), or advises with no stated consequence.
> - **Fix:** state the fact or the consequence directly, or delete the sentence. "Choose the region before the first deploy: a deploy cannot change it later."
> - **Not this fault:** a sentence that states a consequence of an action ("if you skip this step, the first deploy fails"); an instruction in a How-to guide ("open a terminal"); quoted material.
>
> A few fixed phrases ("you may find", "it helps to") could also go into `banned.tsv`, so the deterministic tier catches the common forms.

## Reading

SPEC §5.3 "No unstated commentary (Inference-based)" (`spec/SPEC.md` lines 356-360)
names three faults in one sentence: an editorial judgement, a guess at how
someone might react, and a remark about the writing. None of the three has a
`[[rules]]` entry in `rules/core-rules.toml`. The issue asks for a catalogue
entry for the second fault, widened to cover advice that states no
consequence.

An inference-tier rule is judged only by a model, from its catalogue
`description` string — `software_english_lint.py` selects every rule where
`check == "model-judgement"` and prints the description verbatim as
"inference pending"; there is no per-rule code. So the description string is
the whole specification of the rule.

`vocabulary/banned.tsv` already bans `the reader`, `you might`, `you will
notice`, `you may find` under "Addressing or predicting the reader" (already
catches the issue's own `you may find` example). The three sentences in the
issue match no current row. A corpus check of both repos found `it helps`,
`helps to`, `be glad`, `find out`, `you will find`, `you may want` occur 0
times — safe to add exact-match rows for wording with no correct use, but
`it helps to` and `you may want to` are not safe as flat bans: "it" can name
a component, and a consequence can follow in the same sentence, so they stay
inference-only.

The change touches both `rules/core-rules.toml` and `vocabulary/`, so it
needs a software-english release and a downstream `swe` plugin pin bump +
release, per the briefing and claude-plugins/CLAUDE.md.

## Plan

1. `rules/core-rules.toml`: add `[[rules]] id = "no-reader-reaction-prediction"`,
   tier `inference-based`, check `model-judgement`, severity `warning`, with
   a description covering: the three fault shapes (prediction with no fact,
   advice with no consequence, fact stated only inside a prediction), fixes,
   the two-step judging test, "not this fault" exclusions (consequence
   statements, instructions incl. conditional imperatives, Tutorial
   observable-result statements, quoted material), the split with
   `banned.tsv` (this rule covers wording not on the fixed list), and
   distinctions from the editorial-judgement fault, `no-framing-device`, and
   `no-entailed-restatement`. Add `trigger_phrases` for documentation parity
   with other rules (not read by the script).
2. `spec/SPEC.md`: expand §5.3 in place (keep its number, per precedent
   commit 54e1fda) — retitle to "(mixed)" since both tiers now apply, update
   the Contents anchor, add the fault/fix/examples/exceptions prose, name the
   fixed-list rows and the new inference rule.
3. `vocabulary/banned.tsv`: add five rows under the existing "Addressing or
   predicting the reader" block — `you will be glad`, `you'll be glad`,
   `before you find out`, `exactly what you want`, `may be what you want` —
   each occurring 0 times in either repo today, each with no correct literal
   use. Do NOT add `it helps to` / `you may want to` / `you will find`:
   each has a plausible correct use, so they stay inference-only.
4. `COLOPHON.md`: add a section recording the rule, its rationale, and which
   phrases were banned outright vs. left to inference, following the
   convention of prior rule-adding commits.
5. Intro deck rule counts (`docs/public/presentations/intro/...md`): bump
   "33 inference rules" → 34 and "39 rules" → 40; rebuild via `build.sh` if
   marp/Playwright tooling is available in this session, otherwise patch the
   built HTML's two numbers directly and note the PDF rebuild as a follow-up.
6. Commit steps 1-4(-5) on `software-english` `main` with `Closes #24`; run
   `/swe:lint-file` on `spec/SPEC.md` and `COLOPHON.md`.
7. Release `software-english` via `release.yml` with the next patch version
   after the latest `v*` tag (`v0.0.29` → `v0.0.30`).
8. `claude-plugins`: bump `swe/software-english.json` tag to the new release,
   bump `swe/.claude-plugin/plugin.json` patch version, add
   `swe/tests/reader_reaction_test.sh` (modelled on `motion_idiom_test.sh`)
   covering: each new banned row fires, the inference-only phrases do NOT
   fire banned-word, and `--force-inference` lists
   `[no-reader-reaction-prediction]`. Run every `swe/tests/*.sh` and
   `scripts/check-unshipped.sh`.
9. Commit `claude-plugins` `main`, run `release-plugin.yml -f plugin=swe`,
   confirm `check-unshipped.sh` is clean.
10. Manual check (not scriptable): run `/swe:lint-file` on a scratch doc with
    the issue's three sentences; expect findings on the terminal and region
    sentences (`no-reader-reaction-prediction`) and on "exactly what you
    want" (`banned-word`); expect no finding on a correct consequence
    statement.

### Follow-ups raised, not fixed here (out of scope for #24)
- `templates/tutorial.md` recommends "You will notice that…", which is
  itself a banned phrase — worth a separate issue.
- SPEC Appendix A says the catalogue holds every deterministic-tier rule,
  which is stale (it also holds many inference rules) — worth a separate
  issue.

### Exact edit text
See the full subagent report (plan-agent `aab885393c8674733`, 2026-10-28) for
the exact `core-rules.toml` TOML block, the exact `SPEC.md` replacement
prose, the exact `banned.tsv` rows, the `COLOPHON.md` section text, and the
test file contents. These are transcribed into the working commits in
step 5 ("Work") of the maintainer-run briefing, not repeated verbatim here.
