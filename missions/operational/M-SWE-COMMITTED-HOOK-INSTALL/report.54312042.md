# Report: claude-plugins#31, a per-repo, committed way to install the swe commit hook

## Outcome

Shipped. Commit `d3f09be` on `jimbarritt/claude-plugins` `main` (`closes #31`),
released as `swe-v0.25.0`. Issue closed, with a comment naming the commit,
the release tag, and what changed.

## What changed

- `swe/session-start/swe-commit-hook.sh` (new): a fail-open SessionStart
  shim, installed into a target repository as
  `.claude/hooks/swe-commit-hook.sh`. Locates the installed swe plugin via
  `$SWE_PLUGIN_ROOT`, then `~/.claude/plugins/installed_plugins.json`, then
  a plugin-cache directory glob fallback (verified against this session's
  own environment, where the swe plugin cache holds `0.23.1` but
  `installed_plugins.json` has no swe entry at all — not a hypothetical
  case), and re-runs `install-commit-hook.sh` against the repository.
  Every path exits 0.
- `swe/scripts/install-commit-hook.sh`: added `--session-start`, which
  installs/uninstalls the shim and a `SessionStart` group in
  `.claude/settings.json` (identified by its exact command string, so a
  repeat run is a no-op; never merges into another plugin's own group).
  Also fixed the "already current version" no-op path, which used to
  return before refreshing `<git-common-dir>/swe/plugin-root` — needed so
  the session-start shim's repeated runs keep that pointer current across
  a plugin update that doesn't bump the git hook's own version.
- `swe/skills/install-commit-hook/SKILL.md`: a `session-start` argument,
  and a one-question opt-in (Step 2a) offering to commit the entry when
  not already given.
- `swe/README.md`, `swe/docs/agent-guide.md`: documented the mechanism,
  including why `core.hooksPath` (the issue's other option) was rejected.
- `swe/tests/session_start_hook_test.sh` (new, 42 assertions): fresh
  install, idempotency, a foreign `SessionStart` group preserved, invalid
  JSON refused untouched, a foreign shim file refused, `--uninstall
  --session-start` scoped to only its own group and shim, and the shim's
  own plugin-lookup order, fail-open paths, and installer-refusal
  propagation.
- `swe/tests/commit_check_test.sh`: one regression assert for the
  plugin-root pointer refresh fix.
- `swe/.claude-plugin/plugin.json`: `0.24.13` -> `0.25.0` (minor: new
  feature).

All 21 `swe/tests/*_test.sh` suites pass, 597 assertions total.
`scripts/check-unshipped.sh` confirms `swe` matches its released tag.

## Design decision

Option A (a committed `.claude/settings.json` SessionStart entry plus a
shim) over Option B (`core.hooksPath`) and over a third option considered
during planning — a SessionStart hook owned by the swe plugin itself,
gated on a committed per-repo flag. Recorded as a mission decision. The
issue's own constraints resolved this without escalation: "the repo owns
and commits it... separate from any other plugin's session start hook"
rules out a plugin-owned hook, and `core.hooksPath` disables every other
hook in the clone and would commit a copy of the git hook that goes stale
across plugin updates.

## What was found along the way, not fixed

- `swe/docs/agent-guide.md` is listed in `.swe-ignore`, so it is exempt
  from `/swe:lint-file` entirely (confirmed: the linter reports "No
  sources to check" for it, even directly). No lint record exists or is
  possible for it; left as is.
- `swe/README.md`'s "What happens to an issue filed here" section still
  describes the pre-ledger Routine design (reading `MAINTAINER-RUN.md`
  from the deprecated `planning` branch, writing a task file there). This
  is stale against the ledger-based Routine this run executed under, but
  it is unrelated to #31's scope; not changed here.
- Whether `claude-plugins` itself should opt into the new session-start
  entry (dogfooding) was not done: optional, not required by the issue,
  and this is an unattended run that cannot ask.

## Verification performed

- Manual smoke tests of every installer path (fresh install, idempotent
  re-run, foreign `SessionStart` group preserved, invalid JSON refused,
  foreign shim file refused, pointer refresh, `--uninstall
  --session-start`), each exercised directly before being captured as an
  automated test.
- Shim tested against all three plugin-lookup paths (override,
  `installed_plugins.json` by project and by user scope, and the
  cache-glob fallback), plus outside-a-git-repo and no-plugin-found
  fail-open cases.
- `/swe:lint-file`'s full process (deterministic + inference tiers, both
  passes) run by hand on `swe/skills/install-commit-hook/SKILL.md` and
  `swe/README.md`: two deterministic errors found and fixed
  (anthropomorphism on "asks", banned word "holds") before a clean
  inference-tier judgement and ledger recording of both files.
