# claude-plugins#22: swe installs a tsk pre-docs-commit hook

Status: in progress (step 5, Work)
Session: https://claude.ai/code/session_01Kxgz5bvg4rAH2FMwoDqBYh

## The ask (verbatim)

> ## Context
>
> `/swe:install-commit-hook` writes `.git/hooks/pre-commit`. That hook applies to commits in the code repo. In a repo that uses [tsk](https://github.com/jimbarritt/tsk), it also applied to tsk's own commits of ledger documents, because tsk's documents worktree is a linked worktree of the code repo. On 2026-10-24 this blocked `tsk ledger push` in a field test: the hook found staged Markdown with no clean lint record, the push stopped, and the background publish failed with no visible reason.
>
> tsk 0.26.1 fixes the cause. tsk now runs its own git commands with git hooks disabled, so no code repo hook applies to the ledger. The ledger documents therefore stop being linted by the swe commit hook. Jim wants swe to lint the ledger documents, with no dependency of the tsk binary on swe.
>
> tsk 0.26.1 adds a generic hook point for this. The full interface is in [ADR 0025](https://github.com/jimbarritt/tsk/blob/main/docs/adr/0025-a-documents-hook-point-and-no-git-hooks-in-the-ledger-worktrees.md), and the user guide is `docs/user-guide/checking-ledger-documents.md` in the tsk repo.
>
> ## Request
>
> When the swe plugin installs its commit hook, it checks whether tsk is installed. If it is, it offers to install a `pre-docs-commit` script as well.
>
> 1. **Detect tsk.** `command -v tsk` finds the binary, and `tsk --version` prints 0.26.1 or later. If tsk is older than 0.26.1, say that the documents hook needs 0.26.1 and stop. If tsk is absent, do nothing.
> 2. **Install the script.** Write an executable `pre-docs-commit` that runs the swe check on the document paths it receives. Do not hard-code a path to a plugin cache directory that changes with each swe version: the script must keep working after swe updates, or `/swe:install-commit-hook` must be safe to run again to refresh it.
> 3. **Choose where.** Offer these places, and ask which one:
>    - **User:** `${XDG_CONFIG_HOME:-$HOME/.config}/tsk/hooks/pre-docs-commit`. It applies to every ledger of this user, including repos the user does not control. This is the right default for those repos.
>    - **Clone:** `<state>/repos/<clone-id>/hooks/pre-docs-commit`. `tsk ledger path` prints the ledger store path inside it. It applies to one clone.
>    - **Repo:** `.tsk/hooks/pre-docs-commit` at the root of the code repo. It is committed, so every contributor is checked. Use it only in a repo the user controls.
>    `tsk config docs-hook` prints which script applies and where it came from. Run it after installing, and show the result.
> 4. **Do not overwrite** an existing `pre-docs-commit` that swe did not write. Say where it is and stop.
>
> ## The interface the script must meet
>
> - Arguments: the changed document paths, relative to the documents worktree, one argument each. Deleted documents are not passed.
> - Current directory: the documents worktree. The environment variable `TSK_DOCS_WORKTREE` holds its absolute path.
> - Run by `tsk ledger doc put <path>` after the document is written (one path), and by `tsk ledger push` before the documents commit (every document changed since the last push).
> - Exit 0 passes. A non-zero exit makes `doc put` exit 1, with the document still written locally, or stops the push before anything is pushed. The hook's stdout and stderr are shown unchanged.
> - `TSK_SKIP_DOC_CHECK=1` skips it. Agents are told not to use it.
> - Documents that are not Markdown pass without a check.
>
> ## Acceptance
>
> - In a repo with tsk 0.26.1 and the swe plugin, `/swe:install-commit-hook` offers the documents hook, installs it where the user chooses, and shows `tsk config docs-hook` output.
> - `tsk ledger doc put <path> <file>` with a file that has a swe error exits 1 and prints the findings. After the text is fixed, a second `doc put` exits 0.
> - `tsk ledger push` with an unlinted changed document stops with the findings and pushes nothing.
> - With tsk absent or older than 0.26.1, the command installs only the git hook, as today, and says why it skipped the documents hook.
> - A repo that does not control its own files can get linting through the user place alone, with nothing added to the repo.
>
> ## Open questions
>
> - Whether the script runs only the deterministic tier of the lint, which needs no model call, or both tiers. A push should not wait on a model call, so the deterministic tier is my suggestion.
> - Whether the lint record that the git hook uses (`.git/swe/lint-log.ndjson`) should also be written for ledger documents. They are outside the code repo's `.git`.

## Reading

tsk's ledger documents worktree is a linked worktree, so a `.git/hooks/pre-commit`
installed for the code repo used to apply there too; tsk 0.26.1 disables git
hooks for its own commands and instead calls a `pre-docs-commit` script
through its own hook point. swe needs a second, independent hook that tsk
calls directly (no git hook, no dependency of tsk on swe), installed to one
of three places tsk already understands. The open questions are answered by
the reporter's own suggestion (deterministic tier only) and by the ledger's
scope (code-repo-only, so no cross-write).

## Plan

(From an Opus Plan subagent that read `swe/git-hooks/pre-commit.sh`,
`swe/scripts/install-commit-hook.sh`, `swe/scripts/software_english_lint.py`,
and `swe/skills/install-commit-hook/SKILL.md`.)

### Decisions on the open questions

1. **Deterministic tier only.** A push or `doc put` must not wait on a model
   call, and the hook runs outside any Claude Code session, where no model
   is available. The full two-tier check stays available through
   `/swe:lint-file <path>`.
2. **No row in `lint-log.ndjson`.** That ledger is two-tier-specific, nonce-
   and units-guarded, and read only by the code-repo git hook. The documents
   worktree resolves to the same `.git` (via `git rev-parse
   --git-common-dir`), so a row keyed by a document-relative path would
   clash with a code-repo path of the same name (e.g. `README.md`). The
   hook's exit status and output are all tsk needs. A separate
   `docs-lint-log.ndjson` with `tier: "deterministic"` is a possible
   follow-up, out of scope here.

### Files to create or change

1. **New `swe/tsk-hooks/pre-docs-commit.sh`** — static source, copied
   verbatim by the installer (same pattern as `git-hooks/pre-commit.sh`).
   Marker line `# swe-docs-hook-version: 1`. Filters args to existing
   `*.md`/`*.markdown` paths (passes silently if none). Finds the plugin
   root at run time, in order: `$SWE_PLUGIN_ROOT` → `installed_plugins.json`
   (match `^swe@`, pick highest version) → `${XDG_CONFIG_HOME:-$HOME/.config}/swe/plugin-root`
   pointer → glob of plugin cache dirs, highest version. None found → note
   to stderr, exit 0 (fails open). Runs `fetch-software-english-data.sh`
   (no-op when cache current), then
   `software_english_lint.py --quiet-vocab --cwd "$PWD" <files>`. Exit 0 →
   print warnings (if any) + "documents check passed" summary, exit 0. Exit
   1 → print findings + fix-it pointer to `/swe:lint-file`, exit 1. Any
   other exit → note to stderr, exit 0. Does not read `TSK_SKIP_DOC_CHECK`
   (tsk itself skips the hook) and never mentions it.

2. **New `swe/scripts/install-docs-hook.sh`** — `--detect | --place
   {user|clone|repo} [--uninstall] [<repo-path>]`. Detects tsk
   (`command -v`, parse `tsk --version`, compare to 0.26.1 field-by-field,
   no `sort -V`). Computes the three paths (user: fixed; repo: via
   `git rev-parse --show-toplevel`; clone: via `tsk ledger path` +
   `<git-common-dir>/tsk-clone-id`, walking up to the `repos/<clone-id>`
   ancestor). Reports each place's state (`absent` / `swe <n>` / `foreign` /
   `unavailable <reason>`). `--detect` prints tab-separated status lines.
   `--place P` refuses on tsk absent/too-old (exit 3), refuses to overwrite
   a foreign file (exit 1, no chaining — unlike the git hook, the issue
   says stop), otherwise installs/updates (marker-version compare, same
   as the git installer), `bash -n` + executable check, writes the
   `swe/plugin-root` pointer, runs `tsk config docs-hook` and echoes it.
   `--uninstall` removes only a swe-written file.

3. **Change `swe/skills/install-commit-hook/SKILL.md`** — new Step 3
   ("Check for tsk", runs `install-docs-hook.sh --detect`, short-circuits
   with a one-line reason when tsk is absent/too old), Step 4 ("Ask where",
   one question only, per CLAUDE.md's one-question-at-a-time rule — lists
   the three places with scope/availability, recommends `user`), Step 5
   ("Install", runs `--place <choice>`, reports `tsk config docs-hook`
   output verbatim, flags when a different script takes precedence). Extend
   the report step and the uninstall branch. Frontmatter `description`
   updated (no `": "` — `skill_frontmatter_test.sh` rejects it).

4. **New `swe/tests/docs_hook_test.sh`** — same fixture/assert pattern as
   `commit_check_test.sh`, offline, with a fake `tsk` on `PATH`. Covers
   detection (absent/too-old/ok/unknown-version), install/reinstall
   idempotency, refusing a foreign file, clone-path derivation, repo-path
   derivation, hook behaviour on a lint error / a fixed file / a non-`.md`
   path / a missing path, plugin-root discovery fallbacks (env var →
   `installed_plugins.json` → pointer → cache glob, highest version wins),
   and uninstall.

5. **Docs** — `swe/README.md` (new "Check tsk ledger documents" section)
   and `swe/docs/agent-guide.md` (new "The tsk documents check" section:
   source file + installer, run-time plugin-root discovery and why there's
   no version-pinned pointer, the fail-open boundary, tsk's script
   precedence order, why no ledger row is written). British English, STE,
   no anthropomorphic wording; `/swe:lint-file` each changed `.md` before
   committing.

6. **Release** — bump `swe/.claude-plugin/plugin.json` `0.22.1` → `0.23.0`
   (new feature). `scripts/check-unshipped.sh`. After push:
   `gh workflow run release-plugin.yml -f plugin=swe`.

### Order of work

1. `tsk-hooks/pre-docs-commit.sh`
2. `scripts/install-docs-hook.sh`
3. `tests/docs_hook_test.sh` (plus re-run `commit_check_test.sh`,
   `skill_frontmatter_test.sh`)
4. `SKILL.md`
5. README + agent-guide
6. Version bump, `check-unshipped.sh`, commit (`closes #22`), push, release

### Risks flagged by the planner

- `installed_plugins.json`'s exact format wasn't observable in the planning
  sandbox (only `synced` was present) — parse tolerantly, rely on the
  cache-glob and pointer fallbacks as a safety net.
- The exact shape of `tsk ledger path`'s output on a clone with a minted
  clone id wasn't observable either (this clone has none yet) — the
  clone-path derivation needs a sanity check against real `tsk ledger
  path`/`tsk-clone-id` output during implementation; fall back to marking
  the clone place `unavailable` with a clear reason if the walk doesn't
  find the expected ancestor.
- A repo-place hook on a shared repo fails open (stderr note) for a
  contributor without swe installed — by design, documented in the README.
