# Issues #7 and #8: the style's token cost, and a Design document type

Both filed by Jim, both shipped together in `swe` v0.11.0.

## Issue #7: document the output style's token cost

[claude-plugins#7](https://github.com/jimbarritt/claude-plugins/issues/7).
A 45-run headless measurement (5 repeats, 3 prompt lengths, `swe`
0.9.1, `sonnet`, 0 errors, harness in `jimbarritt/tsk`) established
three things, now stated in `swe/README.md` under "What the output
style costs":

- Selecting the style costs 6% to 11% more input tokens per turn
  (10.8% short, 9.5% medium, 6.0% long).
- The share shrinks as the prompt grows, because the style's text is a
  fixed size, and the styled condition writes fewer output tokens, so
  the cost is input-side rather than longer replies.
- No latency cost is established. A one-repeat pilot suggested about a
  second of extra time to first token; the 45-run design did not
  reproduce it. The README states this too, so the pilot figure does
  not get repeated later as fact.

Also confirmed by that measurement: the old Stop hook's per-turn cost
(#6) reads zero at 0.9.1.

## Issue #8: a Design document type

[claude-plugins#8](https://github.com/jimbarritt/claude-plugins/issues/8),
raised through `/swe:feedback` as a feature request. A design document
for an internal HTTP API was typed Reference, and
`no-planning-content-in-reference` then fired on every entry of its
open-questions section and on its future-extension section. Both
survived only because the owner granted the same two exceptions by
hand, once per section, and a second agent needed them restated.

Shipped in `software-english` v0.0.4
([`7cbfbb7`](https://github.com/jimbarritt/software-english/commit/7cbfbb7)):

- `templates/design.md`, a new cached reference citing IEEE Std
  1016-2009 for the formal standard and Ubl's "Design Docs at Google"
  (2020) for the industry convention. The two describe one type at two
  levels of formality, so the cache holds both organisations: IEEE
  1016's stakeholder, concern, view and viewpoint, and the Google
  convention's five sections.
- SPEC §7.9 and Appendix F tell Design and Reference apart.
- An open-questions section and a future-extension section are both
  permitted, marked as Software English's own addition, since neither
  source names either one. Every other rule applies unchanged, §7.7
  included.

### The part that actually changes behaviour

The plugin fetches `rules/core-rules.toml` and `vocabulary/*.tsv` and
nothing else. It never reads `templates/` or `SPEC.md`. The judging
agent sees the rule descriptions alone, so the distinction had to go
into those two descriptions, or the spec change would have altered
nothing a user sees. Both now carry it:
`document-type-template` names Design and gives the decision-state
test against ADR, RFC and Reference; `no-planning-content-in-reference`
states that it never fires on a Design document, and that a mistyped
one reports a finding against every entry in both sections.

Verified against a design-document fixture holding both offending
sections: the rules block now names Design, the document types as
Design, and the planning rule does not fire. An inference-tier rule
can be verified only at that level, which is that the judging agent
now holds the information it previously lacked.

## Carried in the same pass

- `swe/README.md`'s "Slack/Gmail/Drive" row marked with the per-line
  exemption `<!-- swe: ignore -->`. "Drive" there is the product name
  and `banned.tsv`'s entry means the verb; the false positive was
  logged through `/swe:feedback` earlier and left as it was. It had to
  be handled now, because committing the file needs a clean lint
  record for its exact staged content, and recording one over a known
  finding would have put a false row in the ledger. The first record
  written in this pass was exactly that false row, caught and
  corrected before the commit.
- `scripts/check-unshipped.sh` now notes that local tags can lag a
  release run. Hit directly: the 0.11.0 tag existed on the remote, the
  local clone had not fetched it, and the check reported a pending
  release that had already happened.
  [`e90bd3c`](https://github.com/jimbarritt/claude-plugins/commit/e90bd3c)
  carries the release; the note followed.

## Open, not addressed

`software-english`'s `rules/core-rules.yaml` is stale and misleading:
it holds 10 of the catalogue's 20 rules, still cites "SPEC §7.6" where
the TOML says §7.8, and carries a header note claiming the reference
implementation hardcodes the rules in Python, which stopped being true
once the plugin began parsing the TOML. `rules/core-rules.toml` is
canonical (SPEC Appendix A names it, and the plugin parses it). The
YAML was left untouched rather than half-corrected. Deleting it, or
generating it from the TOML, is Jim's call.

## Status

Done. `software-english` v0.0.4 released; `swe` v0.11.0 released with
the pin bumped to it. Both issues closed with a comment recording what
shipped. All five test suites pass against the new rule data.

## Follow-up: the stale YAML catalogue, now generated

Jim asked what "stale" meant, then asked for the file to be brought
current. `software-english` v0.0.5.

What it meant, measured:

- `rules/core-rules.yaml` held 10 of the catalogue's 20 rules.
  `no-em-dash` was among the missing ten.
- It cited SPEC §7.6 for `document-type-template`. The TOML and SPEC
  both place that rule at §7.8, so the section had been renumbered
  without the YAML following.
- Its header claimed the reference implementation hardcoded the rules
  in Python "rather than parsing this file directly", which stopped
  being true once the plugin began parsing the TOML, and named
  `claude-plugins/software-english-lint/`, a path that stopped
  existing at the v0.5.0 rename.
- Both files declared version `"0.1"`, so nothing signalled the
  disagreement.
- Nothing in either repository reads the YAML. The TOML is read by
  eight files.

Brought current by generating it rather than by hand:
`scripts/generate-rules-yaml.py` writes the YAML from the TOML, and
`.github/workflows/check-rules-yaml.yml` runs its `--check` mode on
every push and pull request, so a TOML edit committed without
regenerating fails there. Green on its first run. Standard library
only, matching the repository's lack of dependencies. SPEC Appendix A
now states which file is the catalogue and which is generated.

The round-trip check caught a real fault straight away.
`textwrap.wrap` breaks on hyphens by default, so the first generated
file folded `learning-oriented` into `learning- oriented`, and
likewise `load-bearing` and `inference-based`. Three rule descriptions
were corrupted in a way that reads as ordinary prose, and only a
field-for-field comparison against the TOML showed it. The generator
now wraps with `break_on_hyphens` and `break_long_words` off, and the
two files parse to identical data, rule order and exemptions
included.

No `swe` release followed. The plugin fetches `rules/core-rules.toml`
and `vocabulary/*.tsv`, and `git diff v0.0.4 v0.0.5` over exactly
those paths is empty, so the pin stays at v0.0.4 and a bump would
carry no change. Deleting the YAML remains available: nothing reads
it, and generating it costs one script.
