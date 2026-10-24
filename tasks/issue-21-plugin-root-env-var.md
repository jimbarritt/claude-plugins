# claude-plugins#21: install-commit-hook skill's script path built from an empty `CLAUDE_PLUGIN_ROOT`

[Issue #21](https://github.com/jimbarritt/claude-plugins/issues/21), opened
by `jimbarritt` (trusted collaborator), claimed by the
self-maintaining-repo Routine on 2026-10-24.

## The ask, verbatim

> The install-commit-hook skill (swe plugin) tells the agent to run:
>
>     "$CLAUDE_PLUGIN_ROOT/scripts/install-commit-hook.sh" [--uninstall] [<repo-path>]
>
> In a Bash tool call, CLAUDE_PLUGIN_ROOT is empty. The command expands to
> /scripts/install-commit-hook.sh and fails with "no such file or directory".
> The agent has to list the plugin cache directory and run the script by
> absolute path, which then succeeds with exit 0.
>
> A second fault in the same skill: Step 1 renders the arguments placeholder
> as empty, so the sentence reads "`` is empty, a repository path, ...".
> Argument substitution does not appear to apply to that text.
>
> Expected: the skill gives a script path that resolves in the Bash tool, and
> the arguments placeholder renders.
>
> Proposed fix direction:
> - Build the script path from the skill base directory that the harness
>   prints at the top of the skill (the skill directory sits under the
>   plugin's scripts directory), instead of an environment variable.
> - Check the other swe skills for the same CLAUDE_PLUGIN_ROOT pattern.
> - Fix the arguments placeholder so Step 1 reads correctly after
>   substitution.

## Reading

Two independent text-substitution bugs in `SKILL.md` prose, not a script
behaviour fault, and not limited to the one skill the issue names.

## Plan (from an Opus Plan subagent, which read the official Claude Code docs first)

The subagent read the Claude Code docs directly
(`https://code.claude.com/docs/en/plugins-reference`,
`https://code.claude.com/docs/en/skills`) rather than the issue's own guess
at a mechanism, and found the root cause is narrower than the issue's
proposed fix direction:

- **`${CLAUDE_PLUGIN_ROOT}` (with braces) is substituted inline by the
  harness when it loads a skill's Markdown body**, before the agent ever
  reads the text — "the variables aren't present in the environment of
  commands Claude runs through the Bash tool"; the braced form in Markdown
  prose is the documented way to reference a bundled script. The three
  affected skills wrote the bare `$CLAUDE_PLUGIN_ROOT` (no braces), which
  the harness leaves untouched, so the agent passes the literal unset shell
  variable to Bash. The fix is adding the braces, not reading a
  harness-printed base-directory header (the issue's own proposed
  direction) — simpler, and the officially documented mechanism.
  `swe/hooks/hooks.json` already uses the braced form and is a harness
  subprocess invocation, not a Bash-tool call; out of scope, unchanged.
- **`$ARGUMENTS` is also substituted before the agent reads the skill.**
  With no argument given, it substitutes to the empty string, so
  `` `$ARGUMENTS` is empty, ...`` (using the token as a backticked sentence
  subject) renders as `` `` is empty, ...``. The fix rephrases each
  affected Step 1 as a label ("Arguments given: $ARGUMENTS") followed by
  prose describing the cases, never as the subject of a sentence inside
  backticks.
- `swe/scripts/install-commit-hook.sh` itself needs no change: its own
  `${CLAUDE_PLUGIN_ROOT:-$HERE}` fallback on line 109 is already correct
  for a Bash-tool invocation (the variable is unset there, so it falls back
  to `$HERE`, computed from `$0`).

**Every file needing a change** (full-repo grep for `CLAUDE_PLUGIN_ROOT`
and `ARGUMENTS`, not just the issue's one named file):

- `swe/skills/install-commit-hook/SKILL.md`: line 17 (`$ARGUMENTS` as
  sentence subject — the issue's own second fault) and line 24 (bare
  `$CLAUDE_PLUGIN_ROOT` in the Step 2 fence — the issue's own first fault).
- `swe/skills/lint-file/SKILL.md`: line 19 (same `$ARGUMENTS` pattern,
  not named in the issue) and lines 25, 34, 164, 172 (same bare
  `$CLAUDE_PLUGIN_ROOT` pattern, three call sites, not named in the issue).
- `swe/skills/feedback/SKILL.md`: line 17 (same `$ARGUMENTS` pattern, not
  named in the issue; this skill has no `$CLAUDE_PLUGIN_ROOT` use).
- `swe/skills/send-feedback/SKILL.md`: checked, has neither pattern, no
  change needed.
- `swe/hooks/hooks.json`: checked, already braced, correct, unchanged.
- `swe/.claude-plugin/plugin.json`: version bump required (this repo's
  `CLAUDE.md` release rule — any change under a plugin's own directory
  needs a bump before the release workflow runs).

No `swe/tests/` change needed: the existing suites exercise script and
hook behaviour (lint detectors, `commit_check`, `hooks_test`,
`lint_fail_open`), and `skill_frontmatter_test.sh` checks only YAML
frontmatter, which this fix does not touch. The subagent's plan offered an
optional regression guard (a frontmatter-test assertion that fails on a
future unbraced `$CLAUDE_PLUGIN_ROOT` or a backticked `` `$ARGUMENTS` ``)
as a nice-to-have, not required for a minimal fix.

## Decision taken on the plan's one open point

The plan flagged an optional regression-guard test as a "could add, not
required" item, not a genuine two-readings fork — this is a documentation
fix with a known, narrow failure shape, and this Routine does not design
new permanent test coverage speculatively beyond what an issue actually
asks for. Not added; noted here for a future issue if the same bug class
recurs.

## Status

(filled in at Record, step 9)
