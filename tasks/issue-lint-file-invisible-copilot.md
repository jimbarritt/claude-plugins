# Bug: /swe:lint-file invisible to GitHub Copilot CLI

No GitHub issue filed. Found by Jim directly, after installing the
plugin fresh on Copilot CLI and noticing `swe:lint-file` was absent
while `swe:feedback` was present.

## Symptom

On Copilot CLI: `swe:feedback` loads, `swe:lint-file` reports "Skill
not found". On Claude Code: every skill loads. Same plugin, same
install.

## Cause

`swe/skills/lint-file/SKILL.md` line 3:

```
description: Run a full swe check on a named file, on demand: both tiers, regardless of hook gating
```

`on demand: ` puts a colon then a space inside an unquoted plain YAML
scalar. YAML reads that as a second mapping separator, so a strict
parser rejects the whole frontmatter document with "mapping values are
not allowed here". Claude Code's own parser accepts the form, so the
skill worked there and the fault stayed invisible. Copilot CLI parses
strictly and drops the skill, with no error surfaced to the user.

Present from [`bd9edac`](https://github.com/jimbarritt/claude-plugins/commit/bd9edac)
(v0.7.0, the inference-tier rework) through v0.10.0. Unrelated to the
commit-check work released as v0.10.0, which is what prompted the
fresh install that exposed it.

A scan of all five frontmatter blocks in the repository found this as
the only invalid one.

## Diagnosis note, for a future session

Two wrong theories came first, both discarded on evidence:

1. That Copilot CLI has no equivalent of Claude Code's slash commands.
   GitHub's own docs show it does support plugin-packaged skills.
2. That this was [github/copilot-cli#2753](https://github.com/github/copilot-cli/issues/2753),
   an open upstream bug where *no* plugin skill reaches the agent.
   Jim's own observation killed it: some `swe` skills did load.

The thing that settled it was parsing the actual files rather than
reading more documentation. "Works on one harness, missing on another"
points at the artefact, not the harness.

## Fix

Shipped on `main` at
[`9479980`](https://github.com/jimbarritt/claude-plugins/commit/9479980),
released as `swe-v0.10.1`.

- Colon replaced with a comma. Deliberately not quoted: quoting parses
  under a strict parser, but a harness that splits on the first colon
  would then carry the quote marks into the description, so removing
  the colon is the form that holds under every parser.
- New suite, `swe/tests/skill_frontmatter_test.sh`: checks every
  `SKILL.md` and output-style frontmatter for an unquoted `": "` and an
  unquoted leading YAML indicator character, asserts the frontmatter
  `name` matches its own directory (Copilot CLI requires this), names
  this specific regression as its own assertion, and re-parses
  everything with a real strict parser wherever PyYAML is installed.
  Stdlib-only otherwise, since the plugin depends on nothing outside
  it. Verified by reintroducing the fault: three assertions fire.
- Constraint documented in `swe/docs/agent-guide.md`, under "Writing a
  skill's frontmatter".

Carried in the same commit, all found while fixing the above:

- `install-commit-hook`'s description shortened under the
  sentence-length limit.
- An "escape hatch" metaphor in that same skill, found by judging it
  against the inference tier rather than only running the
  deterministic one.
- `plugin.json`'s description still said "commit gate" after the
  v0.10.0 rename to "commit check". It is a JSON file, so the prose
  linter never reads it, which is exactly why the rename missed it.

## Status

Done — shipped and released as `swe-v0.10.1`. Jim to confirm
`/swe:lint-file` now appears after updating the plugin on Copilot CLI.
