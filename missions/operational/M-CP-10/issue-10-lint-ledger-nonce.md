# Issue #10: lint-file: the ledger cannot tell a real inference pass from a skipped one

## Ask, verbatim

**Title:** lint-file: the ledger cannot tell a real inference pass from a
skipped one

**Body:**

> ## Verdict
>
> `feature-request` (logged via `/swe:feedback`, 2026-09-21).
>
> ## The problem
>
> `--record-lint-result` trusts its caller completely. It computes the
> blob id and writes `clean`, with no evidence that a model judged the
> content at that blob. An agent can therefore go from a clean
> deterministic tier straight to recording `clean`, skipping Step 4 of
> `/swe:lint-file` entirely, and the ledger cannot tell that pass from a
> real one. The commit hook then reads a row that means less than it
> appears to.
>
> ## Observed
>
> A Copilot CLI session on a private repo, 2026-09-21. `/swe:lint-file`
> ran on two staged files after the pre-commit hook blocked a commit
> for a missing lint record. Steps 2 and 3 ran on both, and both were
> deterministically clean.
>
> - For one file, Step 4 ran properly: the file was read and judged
>   against the inference rules.
> - For the other, Step 4 was skipped and `clean` was recorded anyway,
>   on the reasoning that the only change since an earlier full
>   judgement in the same session was a single token swap, so the
>   earlier verdict still held.
>
> That reasoning is what the blob-keyed ledger exists to refuse: any
> content change invalidates the row. The shortcut only surfaced
> because the user asked directly whether the skill had been used.
>
> A smaller issue in the same run: the Step 3 output was piped through
> `sed -n '1,3p'`, truncating the `===INFERENCE_ADVISED===` block on
> screen, and the judgement ran against the full rule list recalled
> from earlier conversation context. Same rules in the end, but the
> skill run itself no longer showed what was being judged against.
>
> ## Proposed fix direction
>
> Preferred: have `--force-inference` emit a nonce tied to the blob id,
> which `--record-lint-result` must be given back. Recording without
> having run Step 3 on that exact content then fails.
>
> Alternatives, weaker but cheaper:
>
> - Require the recording call to carry the count of inference rules
>   judged, or their ids, so a skipped Step 4 is visible in the ledger.
> - Record a distinct verdict for "deterministic only, inference not
>   judged", rather than collapsing it into `clean`.
> - State in the skill text that a prior judgement in the same session
>   never carries across an edit, since that is the precise
>   rationalisation used here.

Opened by `jimbarritt-pleo` (trusted: repository collaborator, `write`
role — invite accepted mid-session on 2026-09-28, after an initial
check on this same run found only `jimbarritt` as a collaborator and
paused to confirm with Jim directly).

## Reading

The preferred fix direction, implemented as specified: a single-use
nonce, minted by `--force-inference` and bound to the file's exact git
blob id, that `--record-lint-result` must be given back before it will
write a row. This closes the exact shortcut observed (recording
`clean` on the strength of an earlier session's judgement of different
content) because any edit changes the blob, which invalidates the
nonce along with it.

## Plan (from the Opus Plan subagent)

### Constraints found in the existing code

1. `swe/data/` is gitignored and fetched on demand; the test suite
   never fetches it, so `main()` returns 0 before processing any
   source when the catalogue is missing. Tests need a small fixture
   `data/core-rules.toml`, following `lint_fail_open_test.sh`'s
   existing pattern of copying the plugin scripts into a scratch tree.
2. Nothing reads ledger rows beyond `path`, `blob`, `algo`, `status`
   (only `pre-commit.sh`'s embedded `check_ledger.py`, and only for
   blobs staged right now). The row schema is unchanged; `pre-commit.sh`
   and `_lib.sh` need no edits.
3. `record_lint_result()` computes toplevel/rel-path/blob/git-common-dir
   inline; nonce issuing needs the identical steps, so that logic moves
   into a shared `_repo_context()` helper used by both.
4. The existing "outside a git repository: exit 0, nothing recorded"
   path takes no nonce and must keep working unchanged; the repo check
   runs before the nonce check, and `--nonce` is optional at the
   argparse level.
5. Exit codes 0/1/2/3 are already in use (0 success, 1 lint errors, 2
   malformed call, 3 ledger write failure); a nonce refusal gets a new
   code, 4.

### Mechanism

- **Storage:** `<git-common-dir>/swe/lint-nonces.json`, a JSON object
  keyed by a `secrets.token_hex(16)` value, each entry holding
  `{path, toplevel, blob, algo, issued_at}`. Written atomically (temp
  file + `os.replace`).
- **Issuing** (`--force-inference`, single named file, inside a git
  repo, not `.swe-ignore`'d): always issues a nonce, whether or not the
  `INFERENCE_ADVISED` block printed (a no-prose file, and a
  deterministically-failed file, both still need a row later) and
  whether or not the deterministic tier found errors. Any prior pending
  nonce for the same `(toplevel, path)` is dropped first: only the
  newest Step 3 run stays valid. Printed as the *last* line of stdout,
  `swe-lint-nonce: <hex>`, deliberately last so the truncation-by-`sed`
  failure mode in the issue's "smaller issue" now fails loudly (Step 5
  has nothing to pass) instead of silently dropping the rules block.
  When no nonce can be issued (outside a repo, `.swe-ignore`'d, no
  blob), prints `swe: no lint nonce issued for <file>: <reason>`
  instead; issuing never changes the linter's own exit code.
- **Validating** (`--record-lint-result`, required for both `clean` and
  `failed`; a `failed` row needs one too, otherwise an agent could
  record `failed` then flip to `clean` on the same nonce without
  judging again): checked in order — repo context first (unchanged
  exit-0 "nothing recorded" case), then nonce given, known, matching
  `(path, toplevel)`, matching current blob. On success the entry is
  deleted from the store *before* the ledger row is appended (a ledger
  write failure after that still exits 3, but the nonce is already
  spent, forcing a fresh Step 3 rather than a retry with the same
  value).
- **Why it resists the exact shortcut in the issue:** a fabricated nonce
  matches nothing in the store; a stale nonce's stored blob no longer
  equals the current one the instant the file changes (the token-swap
  case is exactly this); a used nonce is deleted, so it cannot record
  twice. Stated limit, documented rather than solved: the nonce proves
  Step 3 ran on this content and its stdout reached the caller, not
  that Step 4's judgement happened inside the model — that step is
  invisible to the script by construction. A caller with raw shell
  access can still write the ledger or the nonce store directly; the
  design converts an accidental shortcut into a deliberate forgery.

### Changes

- `swe/scripts/software_english_lint.py`: `_repo_context()`,
  `issue_lint_nonce()`, nonce store read/write helpers,
  `--nonce` argparse flag, `record_lint_result()` gains a `nonce`
  parameter and the validation order above, `main()` prints the nonce
  line for a single-file `--force-inference` run, module docstring
  extended to describe the third state file and its scope.
  `--advise-inference` issues no nonce (hooks never record to the
  ledger).
- `swe/skills/lint-file/SKILL.md`: Step 3 tells the agent not to
  filter/truncate the output and to note the trailing
  `swe-lint-nonce:` line; Step 4 states a prior judgement never carries
  across an edit; Step 5's two commands gain `--nonce <value>` and the
  exit-code list gains 4 ("go back to Step 3, not retry with another
  value").
- `swe/docs/agent-guide.md`: "The commit check" section documents the
  nonce store (a third state file, per-repo, short-lived), the
  validation order, and the stated limit; the "Run the linter directly"
  example and "Known limits" updated to match.
- `swe/tests/commit_check_test.sh`: a fixture `data/core-rules.toml` (no
  cached data in the test tree otherwise), helpers to mint a nonce and
  record with it, and new assertions covering replay, a skipped Step 3,
  a fabricated nonce, a stale blob after an edit (the issue's own
  scenario), wrong-file, failed-then-clean, superseded nonces, no-prose
  files, deterministic-error files, outside-a-repo, `.swe-ignore`'d
  files, and a ledger write failure consuming the nonce anyway.
- `swe/.claude-plugin/plugin.json`: `0.12.1` -> `0.13.0` (minor: CLI
  contract change, following this plugin's existing feature-vs-fix
  bump convention).

No changes needed in `swe/git-hooks/pre-commit.sh` or
`swe/hooks/_lib.sh`.

### Implementation order

1. `_repo_context()` refactor.
2. `issue_lint_nonce()` and `main()`'s printing of it.
3. `record_lint_result()` validation.
4. Tests, including the fixture.
5. `SKILL.md`.
6. `agent-guide.md` and the module docstring.
7. Version bump and release.

## Outcome

Shipped as planned, no deviations from the Opus plan beyond wording
fixes found while actually linting the changed files.

- `swe/scripts/software_english_lint.py`: `_repo_context()` (shared
  toplevel/rel-path/blob/algo/git-common resolution), `issue_lint_nonce()`,
  `_load_nonces()`/`_save_nonces()` (atomic write via a sibling temp file
  plus `os.replace`), `--nonce` argparse flag, `record_lint_result()`
  gains a `nonce` parameter and the validation order from the plan
  (given, known, matching file, matching blob; consumed before the
  ledger write). `main()` prints `swe-lint-nonce: <value>` as the last
  line of a single-file `--force-inference` run, or the "no lint nonce
  issued" reason line, regardless of whether the rules block printed or
  the deterministic tier found errors. Module docstring extended.
- `swe/skills/lint-file/SKILL.md`: Step 3 tells the agent not to
  filter/truncate the output and to note the trailing nonce line; Step 4
  states a prior judgement never applies to changed content; Step 5's
  two commands gain `--nonce <value>` and exit 4 is documented (go back
  to Step 3, don't retry with another value).
- `swe/docs/agent-guide.md`: new "Proof that Step 3 ran" section;
  "Two state files" renamed "Three state files"; "Run the linter
  directly" and "Known limits" updated to match.
- `swe/tests/commit_check_test.sh`: added a fixture plugin copy with a
  minimal `data/core-rules.toml` (`--force-inference` needs a rule
  catalogue to reach the sources loop where a nonce is minted;
  `--record-lint-result` never needed one, so the existing tests'
  behaviour is unchanged). 34 new assertions: nonce issuance and its
  store entry, recording with a valid nonce, replay, no-nonce, a
  fabricated nonce, the stale-blob case from the issue itself (with the
  refusal message asserted to name the content change), wrong-file,
  failed-then-clean flip, superseded nonces, no-prose and
  deterministically-failing files still getting a nonce, outside-a-repo
  and `.swe-ignore`'d files getting none, and a ledger write failure
  that still consumes the nonce. All five suites pass (97 assertions
  total, up from 63).
- `swe/.claude-plugin/plugin.json`: `0.12.1` -> `0.13.0` (minor: CLI
  contract change).

Two wording fixes found only by actually running `/swe:lint-file` on
the changed files, not anticipated in the plan:

- `SKILL.md`'s new Step 3/4/5 prose tripped four deterministic findings
  on the first pass: `note that` (banned, CUT), `carries` and `refuses`
  (both banned, reworded), and a `no-continuous-tense` false-positive on
  "it was missing" (rephrased as a bare list item). Fixed; the file
  re-lints clean, both tiers, and its `clean` row is now in the ledger.
- The new docstring paragraph in `software_english_lint.py` tripped one
  finding purely from a tooling quirk: `extract_comments()` tracks
  quote state per line only, so a literal `#` inside a docstring
  (`claude-plugins#10`) gets misread as a `#`-comment start, and
  whatever text follows it on that line gets checked as if it were a
  real comment. Moved the issue reference to end its line so nothing
  trails after the `#`; not a tool bug worth fixing for this issue (it
  is pre-existing, and the docstring's prose is otherwise not checked by
  this same extractor at all, since it has no protection for
  triple-quoted strings beyond the one line at a time). Also found by
  hand-checking the diff against the full `banned.tsv` word list, since
  the tool only checks fragments after a literal `#`: `refuses`/`gates`
  in prose the extractor never reaches, in `software_english_lint.py`'s
  docstring and `agent-guide.md` respectively (the latter is
  `.swe-ignore`'d entirely). Both reworded, even though nothing would
  have caught them automatically. `agent-guide.md`'s pre-existing em
  dashes were left alone (13 already in the file before this change;
  the file's own established style, and it is exempt from the check).
- Commit: [`fd9d3c8`](https://github.com/jimbarritt/claude-plugins/commit/fd9d3c8)
  on `main`, `closes #10` (closed the issue automatically).
- Release: `release-plugin.yml` run
  [#9](https://github.com/jimbarritt/claude-plugins/actions/runs/36444774755),
  success, tag `swe-v0.13.0`. `scripts/check-unshipped.sh` confirmed
  pending before release, matching after.
- Issue comment posted with the commit, the mechanism, and the release
  tag; `agent:working` label removed after the automatic close.

No escalation. Single pass, aside from the two wording rounds above,
both caught by actually running the checks rather than assuming the
new prose was clean.
