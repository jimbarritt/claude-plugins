# Future task: pre-commit hook gating on a clean inference lint

No GitHub issue filed yet. Raised by Jim in conversation, brainstorming
a new gate on top of the existing `swe` deterministic/inference tiers.

## Ask

Jim, verbatim, across the brainstorm:

> I'm thinking about adding a commit hook that runs the see linter if it
> detects and markdown files in the commit. Wdyt. Don't would run the
> deterministic linter which should give the session some feedback. But
> then it could also put some output like "markdown files in this
> commit, run full inference lint"
>
> Question is, how would it know we ran the inference lint or not?
>
> Maybe we could put some state file in the .git dir?
>
> Every time lint file is called it could write a ndjson row there with
> the file name and hash of the file. The commit hook could check this
> file and see if the files about to be committed have been linted or
> not. If not then it stops the commit, outputs a message to the
> session saying "unable to commit you need to lint the following files
> then retry the commit.
>
> We can add a command swe:install-commit-hook that does the
> installation in the current repo.

Then, once this session raised the "ran vs passed" gap:

> Oh yes good catch it should have a status like "clean" or "failed"
>
> Don't let a commit happen unless it's clean! Like it

Then, on process: "make a task for it. Ask an opus agent to design it
then you just do it. Make a new release at the end of the task."

## Read as

A `pre-commit` git hook, installed per repo by a new
`/swe:install-commit-hook` command, that:

- Detects staged markdown files.
- Runs the deterministic tier itself, there and then, for immediate
  feedback (cheap, no model call needed).
- Blocks the commit unless every staged markdown file has a recorded
  inference-tier pass with status `clean`, keyed to that file's exact
  current content (a content hash, not just a filename — an edit after
  the last lint must invalidate the record). A recorded `failed` status,
  a hash mismatch, or no record at all all block the commit, with a
  message naming which files need linting and how.
- The record lives under `.git/` (repo-local, never committed) as an
  append-only NDJSON log, one row per lint pass: filename, content hash,
  status (`clean`/`failed`), timestamp.

Open design questions for the opus design pass:

- How this relates to the existing `~/.claude/swe/inference-state.json`
  mechanism (word/sentence-count throttle for `--advise-inference`,
  global, keyed by resolved path, no hash or status today) — reuse,
  extend, or a genuinely separate per-repo log. They serve different
  purposes (throttle vs. commit-blocking proof) but both currently
  attach to the same lint pass.
- Where the status (`clean`/`failed`) actually gets set: the linter
  script itself never judges inference findings (no model access by
  design — see `software_english_lint.py`'s module docstring); the
  calling session judges them, today only as prose in its own reply
  (`/swe:lint-file` Step 4/5). Recording a machine-readable verdict
  needs a new step or flag the session calls after judging.
  the same lint pass.
- Hook mechanics: a real `.git/hooks/pre-commit` script (bash, matching
  the plugin's existing hook style) vs. something installed through
  Claude Code's own hook system. A git pre-commit hook runs outside any
  Claude Code session (no model, no plugin runtime available), so it can
  only shell out to the deterministic tier and read the NDJSON log; it
  cannot itself invoke `/swe:lint-file` or judge anything.
- `swe:install-commit-hook` behaviour: idempotent re-install, whether it
  chains an existing `pre-commit` hook already in the target repo rather
  than overwriting it, and what "the current repo" means when invoked
  from inside a plugin-owned worktree.
- Whether this only gates markdown, or the same source types the linter
  already covers elsewhere.

## Design decisions

An opus-model agent designed this against the actual `swe` code; the
design was implemented largely as given, with two corrections found
during implementation:

- The state file is a wholly separate, per-repository, append-only
  NDJSON ledger (`<git-common-dir>/swe/lint-log.ndjson`, one ledger per
  repository, shared by every linked worktree), never merged into
  `~/.claude/swe/inference-state.json`. That file is global, per-user,
  and answers "is a fresh advisory pass worth it"; the ledger is
  per-repository and answers "was this exact content judged, and what
  was the verdict". Keyed on `(path, git-blob-id)` — git's own blob
  object id via `git hash-object`, not a `sha256` of the working-tree
  file, so it matches what a partial `git add -p` actually staged.
  Last-write-wins among rows matching the same key.
- The verdict is recorded by a new standalone mode on the linter,
  `--record-lint-result {clean|failed} --findings N <file>`, called by
  `/swe:lint-file`'s new Step 5 right after it judges the inference
  tier itself. Exit 3 (not silent) on a ledger write failure, since a
  lost row becomes a commit blocked with no visible cause.
- The `pre-commit` hook (`swe/git-hooks/pre-commit.sh`, installed
  verbatim as `.git/hooks/pre-commit`) runs the deterministic tier as
  advisory feedback only (prints, does not block, unless
  `commit-check.block_on_deterministic` is set) and blocks solely on
  the ledger: no matching `clean` row for a staged file's exact staged
  blob blocks the commit, naming the fix. Fails open only when it
  cannot evaluate at all (no `python3`, an unreadable ledger); an
  absent ledger is an evaluated "no record", so it blocks, not skips.
  `git commit --no-verify` is the standing bypass.
- `/swe:install-commit-hook` chains an existing `pre-commit` hook
  (moved to `pre-commit.local`, run first) rather than overwriting it;
  refuses only when both a foreign hook and an existing
  `pre-commit.local` are already present. `--uninstall` reverses it.
- Markdown only by default (`commit-check.paths` in the project's
  `.claude/swe-lint.json`, default `["*.md"]`).

Two corrections found only while implementing, not in the design
itself:

- The design's own terminology, "the commit gate", violates Software
  English's own banned-word list (`gate`/`gated` -> "need, require, or
  check" in `data/banned.tsv`). Renamed throughout to "the commit
  check": the config key (`commit-gate` -> `commit-check`), the marker
  comment, every doc and skill. `agent-guide.md` is exempt from the
  plugin's own lint (listed in `.swe-ignore`) but was renamed too, for
  consistency, everywhere the new section itself introduced the word
  (three pre-existing, unrelated uses of "gate" elsewhere in that file
  were left untouched).
- The installed hook has no file extension (git requires the literal
  name `pre-commit`), so the linter's own extension-based dispatch
  treated the whole script as prose rather than as a `.sh` file's
  comments-only, producing false positives on ordinary shell syntax.
  Fixed by naming the source `swe/git-hooks/pre-commit.sh`; the
  installer copies it to the target's `pre-commit` (no extension)
  regardless of the source's own name, so the installed hook is
  unaffected.

## Status

Done — shipped on `main` at
[`af7dfdc`](https://github.com/jimbarritt/claude-plugins/commit/af7dfdc):
`--record-lint-result` on the linter, `swe/git-hooks/pre-commit.sh`,
`swe/scripts/install-commit-hook.sh`, `/swe:install-commit-hook`,
`/swe:lint-file`'s new Step 5, and docs (`README.md`,
`docs/agent-guide.md`, `docs/output-taxonomy.md`). New test suite
`swe/tests/commit_check_test.sh` (34 assertions: the recorder, the
installer's fresh/idempotent/chain/refuse/uninstall paths, and the
hook itself through real `git commit` calls, including hash
invalidation on edit and the `--no-verify` bypass). All three
pre-existing suites still pass unchanged. Version bumped to 0.10.0 and
released as `swe-v0.10.0` via the manual release workflow.
