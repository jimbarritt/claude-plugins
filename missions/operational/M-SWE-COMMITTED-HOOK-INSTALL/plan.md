# Plan: claude-plugins#31, a per-repo, committed way to install the swe commit hook

## The ask, verbatim

> **Verdict:** feature request (no rule)
>
> **Problem.** `install-commit-hook.sh` writes `.git/hooks/pre-commit`. `.git/` is never cloned, so each new clone starts without the check. A Claude Code cloud session is a fresh clone every time, so in cloud sessions the hook is never present unless someone installs it by hand in that session. Markdown changes then reach the default branch with no lint.
>
> **Ask.** An opt-in, per-repo install that is committed with the repository, so any clone or cloud session of that repo has the check from its first commit. Options:
>
> - `install-commit-hook` writes a repo-level `SessionStart` hook into `.claude/settings.json` that runs the installer at session start.
> - A committed hooks directory set with `core.hooksPath`, plus a session start step that sets that config in each clone.
>
> **Constraints.**
>
> - The repo owns and commits it. It is separate from any other plugin's session start hook.
> - It is opt-in for each repo.
> - It is idempotent when it runs at every session start.

URL: https://github.com/jimbarritt/claude-plugins/issues/31

## Reading

The fix is an artefact the *target* repository commits (not a change inside the
swe plugin's own hook set). Any clone or cloud session of that repository then
gets the git commit hook installed at session start, with no person running
`/swe:install-commit-hook` by hand. Four constraints bind the design: the repo
owns the artefact; the SessionStart entry is its own group, never merged into
another plugin's; it is opt-in per repo; it is a no-op on a repeat run.

A second reading — putting the logic in swe's own `hooks/hooks.json`, gated on
a committed flag in `.claude/swe-lint.json` — was considered and rejected: it
would be swe's own SessionStart hook, which the issue's constraint explicitly
rules out ("separate from any other plugin's session start hook"), and it
would add a SessionStart hook to every swe install rather than only the repos
that opt in. The issue's own wording resolves this in favour of the first
reading, so this is not escalated.

## Mechanism: Option A (a SessionStart entry in `.claude/settings.json`) plus a committed shim script

Option B (`core.hooksPath` pointing at a committed hooks directory) is
rejected: it disables every other hook in the clone's `.git/hooks/`
(including the chaining onto an existing `pre-commit.local` the installer
already supports), it commits a copy of `pre-commit.sh` that goes stale
across swe plugin updates, and `core.hooksPath` is git config, which is not
cloned either — so it still needs a session-start step, with none of the
version-tracking benefit.

Option A meets every constraint:

- **Repo-owned and committed:** two new files in the target repo —
  `.claude/settings.json` (one new SessionStart group) and
  `.claude/hooks/swe-commit-hook.sh` (a small shim).
- **Separate:** the installer always appends its own new group object to
  `hooks.SessionStart`. It never edits another group.
- **Opt-in:** a new `--session-start` installer flag, offered by the skill
  as an explicit question. Plain `/swe:install-commit-hook` does not write it.
- **Idempotent:** the settings writer identifies its entry by its exact
  command string and no-ops when present; the shim always exits 0 and relies
  on the installer's existing "already installed" no-op path.

## Implementation steps

1. **New file `swe/session-start/swe-commit-hook.sh`** — the shim, installed
   by the installer as `<repo>/.claude/hooks/swe-commit-hook.sh`. Marked with
   `# swe-session-start-version: 1`. `set -uo pipefail`, no `-e`, every path
   exits 0 (fail-open). Locates the installed swe plugin via
   `$SWE_PLUGIN_ROOT` override, then `installed_plugins.json`, then a cache
   glob fallback; runs `scripts/install-commit-hook.sh` against the repo
   toplevel; prints at most one short line on install/update, nothing on a
   no-op, one stderr line when swe isn't found or the installer refuses.

2. **Edit `swe/scripts/install-commit-hook.sh`**:
   - Add `--session-start` to argument parsing and usage.
   - Fix: write the `plugin-root` pointer on the "already current version"
     path too (only when its content differs), so a persistent clone that
     relies on the session-start entry keeps the pointer current across
     plugin updates that don't bump the hook version.
   - `--session-start` path (after a successful git-hook install): requires
     `jq`; copies the shim into `.claude/hooks/swe-commit-hook.sh` with the
     same install/update/refuse-on-foreign-file logic as the git hook; writes
     a fixed-literal command into `.claude/settings.json`'s
     `hooks.SessionStart` via `jq`, creating the file if absent, refusing on
     invalid JSON, no-op when the exact command is already present, otherwise
     appending a new group without disturbing existing ones; prints a
     reminder to commit both files.
   - `--uninstall --session-start` removes only the matching command entry
     and the shim (if marked), leaving other groups untouched.

3. **Edit `swe/skills/install-commit-hook/SKILL.md`**: accept a
   `session-start` argument; when not given and no entry exists yet, ask one
   yes/no question about also committing the session-start entry (one
   question per message); update the step that currently says the installer
   needs re-running in each clone.

4. **Docs**: `swe/README.md` ("Check commits against a clean lint") and
   `swe/docs/agent-guide.md` ("The commit check") get a short addition
   covering the shim's plugin lookup order, fail-open behaviour, idempotency,
   and why `core.hooksPath` was rejected. British English, STE.

## Tests

New `swe/tests/session_start_hook_test.sh`, following the pattern of
`commit_check_test.sh` / `docs_hook_test.sh` (throwaway `git init` repos, a
fake `HOME`/`CLAUDE_CONFIG_DIR` under a `mktemp -d`, no network, no touching
the real `$HOME`). Cases: fresh install creates settings.json with one group
and an executable marked shim; an existing settings.json with a foreign
SessionStart group and other keys is preserved and the new group appended;
a second run is byte-identical and prints "already present"; invalid JSON in
settings.json is refused untouched; a foreign unmarked shim file is refused;
`--uninstall --session-start` removes only our group and shim; the shim
itself installs the git hook via `SWE_PLUGIN_ROOT` override and is silent on
a second run; the shim's `installed_plugins.json` and cache-glob lookup
paths; the shim exits 0 and warns on stderr when no plugin is found or
outside a git repo; the pointer-refresh fix; the shim fails open when the
installer itself refuses. Add a regression assert to `commit_check_test.sh`
for the pointer-refresh fix. Run every `swe/tests/*_test.sh` locally before
committing (CI only runs the Python-syntax and unshipped checks).

## Release

Change is under `swe/`: bump `version` in `swe/.claude-plugin/plugin.json`
(minor bump — new feature) in the same commit that closes the issue. Commit
to `main` (pre-approved), run `scripts/check-unshipped.sh`, then trigger
`release-plugin.yml -f plugin=swe` and poll `actions_get` until it finishes.
Confirm the release workflow ships the whole plugin directory (including the
new `swe/session-start/`) rather than an allowlist that would need updating.

## Open items noted, not escalated

- Ordering risk in a fresh cloud container when swe itself is installed by a
  sibling SessionStart command: mitigated by the cache-glob fallback and the
  shim's fail-open behaviour; not fixed further without being asked.
- Whether `claude-plugins` itself should opt in (dogfooding) is optional and
  not required by the issue; left undone in this run since this is an
  unattended run that cannot ask and the issue does not require it.
