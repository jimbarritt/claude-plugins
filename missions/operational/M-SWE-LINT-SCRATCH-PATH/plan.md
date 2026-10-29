# Plan: claude-plugins#29

## The ask (verbatim)

Issue #29: "lint-file: name a scratch location for the Step 3 output, outside the working tree"

> ## Problem
> Step 3 of `/swe:lint-file` runs `software_english_lint.py` with `--force-inference`, and the step's text forbids filtering or truncating the output. On a document of a few hundred lines that output is 60 to 80 KB, and an agent harness writes output of that size to a file. Step 3 names no location for the file, so an agent writes it to the current working directory, which is usually the repository root.
>
> In one session, four agents each ran the skill on a different file. They wrote ten scratch files to the repository root, under names such as `swe-lint-run1.txt`, `swe-rules.txt` and `.swe-lint-scratch/run1.txt`. This had three effects:
> 1. A later `git add -A` staged all ten files, and a pre-commit check blocked the commit.
> 2. The files are untracked, so they appear in `git status` for every later command in the session.
> 3. Two concurrent runs used the same file name, and one run overwrote the other's output.
>
> ## Proposed fix
> In Step 3:
> 1. Redirect the output to a location outside the working tree that is unique per run, for example:
>        out=$(mktemp -t swe-lint)
>        python3 .../software_english_lint.py <file> --force-inference --quiet-vocab > "$out" 2>&1
> 2. If a fixed command is not wanted, add one sentence: the output must not be written inside the repository, and concurrent runs need distinct file names.
>
> The instruction not to filter the output is what makes the redirect necessary, so the two belong together in Step 3.

## Reading

Confirmed against `swe/skills/lint-file/SKILL.md`: Step 3 (lines 33-37) gives a bare
command with no redirect and no scratch location. The "do not filter or
truncate" instruction (lines 83-89) is what makes a scratch file necessary,
and nothing in the skill names where that file goes, so agents invent one
each run — causing the root-cause clash the issue describes (repo-root
writes, pre-commit blocks, overwrites between concurrent runs).

The issue's own example (`mktemp -t swe-lint`) is BSD/macOS-only and fails
on GNU coreutils ("too few X's in template"). The portable form is
`mktemp "${TMPDIR:-/tmp}/swe-lint.XXXXXX"`. Shell variables do not persist
between separate Bash tool calls, so the command must print the path in
the same call, and must join with `;` not `&&` since the linter's exit
code is non-zero on findings.

Decision: ship both the fixed command and the constraint sentence (per the
issue's own alternative framing) — the command stops the concrete failure
(agents inventing colliding names), the sentence states the invariant in
case the command is edited later.

## Plan

1. Replace Step 3's command block in `swe/skills/lint-file/SKILL.md` with a
   single-line `mktemp`-based redirect that prints the resulting path, e.g.:
   `out="$(mktemp "${TMPDIR:-/tmp}/swe-lint.XXXXXX")"; python3 "${CLAUDE_PLUGIN_ROOT}/scripts/software_english_lint.py" <file-path> --force-inference --quiet-vocab > "$out" 2>&1; echo "swe-lint output: $out"`
2. Add a short paragraph after the command block stating: the output goes
   to a new file outside the working tree, unique per run; never write it
   (or a copy) inside the repository; never use a fixed name; read the
   file in full with `Read`; the file is left outside the repo afterwards
   and is not deleted.
3. Tie the existing "do not filter or truncate" paragraph (lines 83-89) to
   the new redirect with one added clause.
4. Add a regression test (new `swe/tests/lint_file_scratch_output_test.sh`
   or extend `lint_file_pass3_test.sh`) asserting the Step 3 section
   contains `mktemp` + `XXXXXX`, redirects to `"$out"`, and does not
   contain the non-portable `mktemp -t swe-lint` form.
5. Bump `swe/.claude-plugin/plugin.json` version (0.24.11 -> 0.24.12).
6. Run `swe/tests/*.sh` (particularly `lint_file_pass3_test.sh`,
   `register_candidates_test.sh`, `define_and_count_candidates_test.sh`,
   `skill_frontmatter_test.sh`), run `/swe:lint-file`'s own linter against
   the edited SKILL.md prose, and run `scripts/check-unshipped.sh`.
7. Commit with `closes #29`, push `main`, run
   `release-plugin.yml -f plugin=swe`, poll `actions_get` to green.

## Files touched

- `swe/skills/lint-file/SKILL.md` (main edit)
- `swe/.claude-plugin/plugin.json` (version bump)
- `swe/tests/lint_file_pass3_test.sh` or a new test file (regression test)

No open question in the issue; no decision needed beyond the command-vs-sentence
choice recorded above, which the issue itself offered as either/or and this
plan resolves as both.
