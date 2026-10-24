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

## Follow-up: a guard for unreleased work

Raised by Jim while checking whether the marketplace carried the
version bump, after Copilot installed an old copy.

Findings on the manifest itself, all correct already: the marketplace
entry carries no `version`, which is right, because Claude Code takes
`plugin.json`'s value when both exist and does not warn; the default
branch is `main` and current; and `plugin.json` has been bumped at
every release.

The real hazard sat elsewhere. A declared version pins the plugin, so
a push to `main` delivers nothing on its own. Six commits had changed
`swe/` with no bump:

```
751f616  output-style: ban "load bearing" / "load-bearing"
7e7abdd  send-feedback: note the add_repo fix
b3b1732  Fix four em dashes in the README
bed5dec  Bring swe's README up to date
a53b53d  Use a full URL in the output style's picker description
4a75dfe  Add the spec link to the picker description
```

Each was carried to users by the next commit that did bump, so nothing
was lost; each was uninstallable until then, and nothing said so.

Shipped on `main` at
[`7f00234`](https://github.com/jimbarritt/claude-plugins/commit/7f00234):
`scripts/check-unshipped.sh` compares every plugin in
`marketplace.json` against its own newest release tag, and
`.github/workflows/check-unshipped.yml` runs it on each push to `main`
and on a pull request. Green on its first CI run. A version ahead of
the newest tag reads as a release in progress, not a fault, so an
intermediate commit that bumps early does not turn CI red. Repo
tooling alone needs no bump, and the check does not require one. The
rule is in `CLAUDE.md` under "Releasing a change", where a later
session reads it.

Still open: which version Copilot actually installed. Copilot CLI's
own resolution rules could not be checked from the session, since
`docs.github.com` is blocked by the environment's egress proxy.
