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

## Status

Design in progress: an opus-model agent has been asked to produce a
concrete design (state-file schema and location, linter/script changes,
new hook script, `/swe:install-commit-hook` command, interaction with
the existing inference-state throttle, test plan) against the actual
`swe` plugin code. Implementation and a release follow once that design
lands.
