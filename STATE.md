# State

Last updated: 2026-09-21

## In progress

None.

## Next

[tasks/future-self-maintaining-repo.md](tasks/future-self-maintaining-repo.md)
(draft plan for an hourly Routine that takes a labelled issue in a
fresh session, works it through the planning branch, releases, and
escalates on the issue thread with a push notification; briefing now
drafted as `MAINTAINER-RUN.md` on this branch; escalation label is
`supervisor`, not `needs-jim`; cadence settled at hourly, 07:00 to
22:00 UK local; the Routine's session runs on Sonnet and dispatches
an Opus subagent for issue analysis and planning; two open questions
remain, the `tsk` framework question first), then
[tasks/future-lint-document-profiles.md](tasks/future-lint-document-profiles.md)
(idea only, not scoped — needs a follow-up conversation on the doc-type
list and what "layered"/"filtered" rules means), then
[tasks/future-stop-reply-check.md](tasks/future-stop-reply-check.md)
(resolved for Claude Code already; still open for Copilot CLI — though
worth re-reading with fresh eyes given how much changed in the pass
below; may already be moot or need restating).

## Recently done

- `software-english` v0.0.5: `rules/core-rules.yaml` is now generated
  from `core-rules.toml` by `scripts/generate-rules-yaml.py`, with CI
  checking it stays generated. It had drifted to 10 of 20 rules, a
  section reference the TOML had moved, and a header describing an
  implementation that changed at v0.5.0. The round-trip check caught
  the generator folding `learning-oriented` into `learning- oriented`
  on its first run, which would have corrupted three rule descriptions
  invisibly. No `swe` release: nothing the plugin fetches differs
  between v0.0.4 and v0.0.5, so the pin stays put. Full record in
  [tasks/issue-7-8-design-type-and-style-cost.md](tasks/issue-7-8-design-type-and-style-cost.md).
- [tasks/issue-7-8-design-type-and-style-cost.md](tasks/issue-7-8-design-type-and-style-cost.md)
  ([#7](https://github.com/jimbarritt/claude-plugins/issues/7),
  [#8](https://github.com/jimbarritt/claude-plugins/issues/8)): two
  issues shipped together as `swe` v0.11.0. #7 put the output style's
  measured cost in the README (6% to 11% more input tokens per turn,
  no latency cost established). #8 added a Design document type to
  `software-english` (v0.0.4), by reference to IEEE Std 1016-2009 and
  Ubl's "Design Docs at Google", so a design document's open-questions
  and future-extension sections stop drawing a
  `no-planning-content-in-reference` finding on every entry. The part
  that changes behaviour is in the two rule descriptions, since
  `rules/core-rules.toml` and the vocabulary are the only files the
  plugin fetches: the judging agent never reads `templates/` or
  `SPEC.md`. Left open deliberately: `core-rules.yaml` is stale, at 10
  of 20 rules with a wrong section reference, and whether to delete or
  generate it is Jim's call.

- [tasks/issue-lint-file-invisible-copilot.md](tasks/issue-lint-file-invisible-copilot.md):
  `/swe:lint-file` was invisible to GitHub Copilot CLI from v0.7.0 to
  v0.10.0, while every other skill in the same plugin loaded. Its
  frontmatter description held `on demand: `, a colon then a space
  inside an unquoted plain YAML scalar, which a strict parser rejects
  outright. Claude Code's parser accepts it, so the fault never showed
  locally. Fixed with a comma (not quotes, which a split-on-first-colon
  harness would carry into the description), guarded by a new
  `tests/skill_frontmatter_test.sh` covering every frontmatter block in
  the plugin, and documented in `docs/agent-guide.md`. Two wrong
  theories preceded it, both about Copilot CLI's own behaviour; parsing
  the files settled it. Released as `swe-v0.10.1`, on `main` at
  [`9479980`](https://github.com/jimbarritt/claude-plugins/commit/9479980).
- [tasks/future-precommit-lint-gate.md](tasks/future-precommit-lint-gate.md):
  a git pre-commit check (`/swe:install-commit-hook`) that blocks a
  commit staging a markdown file unless `/swe:lint-file` already
  recorded a `clean` verdict for that file's exact staged content (git
  blob id, not a path or mtime), via a new repository-local NDJSON
  ledger under `.git/` and a new `--record-lint-result` flag on the
  linter. Deliberately not merged into the existing, global
  `~/.claude/swe/inference-state.json` throttle: different scope,
  different question answered. Designed by an opus-model agent against
  the real code, then implemented with two corrections found only
  during implementation: the design's own "commit gate" terminology
  violated Software English's own banned-word list (renamed to "commit
  check" throughout), and the installed hook's extensionless filename
  (`git` requires the literal name `pre-commit`) meant the linter's own
  extension-based dispatch was linting the whole script as prose, not
  bash comments, fixed by naming the plugin's own source copy
  `pre-commit.sh`. New 34-assertion test suite; all three prior suites
  still pass. Version bumped to 0.10.0, released as `swe-v0.10.0`.
  Shipped on `main` at
  [`af7dfdc`](https://github.com/jimbarritt/claude-plugins/commit/af7dfdc).
- Release tooling, plus a first real release of each repo. Added
  `workflow_dispatch`-only GitHub Actions workflows (triggered from
  here, on demand, never on push) that tag and release:
  - `claude-plugins/.github/workflows/release-plugin.yml`: takes a
    `plugin` input (default `swe`), reads that plugin's version
    straight out of its own `.claude-plugin/plugin.json`, tags
    `<plugin>-v<version>`, refuses to re-tag an existing version,
    creates a GitHub Release with notes scoped to that plugin's own
    previous tag (not the repo's last tag generally, so a second
    plugin's tags don't pollute each other's changelogs later).
  - `software-english/.github/workflows/release.yml`: that repo has
    no version-bearing manifest, so version is a typed input instead;
    same tag/refuse/scoped-notes shape otherwise, plain `v<version>`
    (single-product repo, no plugin prefix needed).
  Used them for real: `swe-v0.9.0` (first-ever release, plugin
  already at that version, never previously tagged), then
  `software-english`'s `v0.0.3` (the load-bearing ban commit that
  was sitting on `main` unreleased, plus an already-existing but
  never-pushed local `v0.0.3` tag from an earlier session, discarded
  in favour of letting the new workflow create the authoritative one).
  `swe/software-english.json`'s pin bumped to that tag, fetched and
  verified locally (the deterministic tier now catches "load-bearing"
  directly), then `swe-v0.9.1` released to carry the update. All on
  `main` at
  [`4b8cd38`](https://github.com/jimbarritt/claude-plugins/commit/4b8cd38)
  (workflow),
  [`1e0acf6`](https://github.com/jimbarritt/claude-plugins/commit/1e0acf6)
  (pin bump + version), and `software-english`'s
  [`20ec1e3`](https://github.com/jimbarritt/software-english/commit/20ec1e3)
  (workflow). No task file: infrastructure work raised and done
  directly in conversation, not from an issue.
- [tasks/issue-5-gh-session-scope-friction.md](tasks/issue-5-gh-session-scope-friction.md)
  ([issue #5](https://github.com/jimbarritt/claude-plugins/issues/5)):
  `gh issue create` is refused until the target repo is attached to
  the session's GitHub scope. Not a claude-plugins code fix (harness
  behaviour, flagged for escalation elsewhere per the issue itself);
  the actionable scope was a one-line note in
  `send-feedback/SKILL.md` Step 4, near the `gh issue create` call,
  so a future run recognises the denial and knows the fix
  (`add_repo`, then retry). Lint run on the edited file caught one
  real finding (`banned-word` on "refuses"), fixed; the file's
  pre-existing `vocabulary-membership` warnings (~344, spread
  through the whole document) are unrelated to this change,
  confirmed by linting the pre-edit version separately. All three
  test suites pass. Shipped on `main` at
  [`7e7abdd`](https://github.com/jimbarritt/claude-plugins/commit/7e7abdd),
  which closed the issue automatically.
- [tasks/issue-4-feedback-tooling-gaps.md](tasks/issue-4-feedback-tooling-gaps.md):
  `/swe:feedback` gained a fourth verdict, `feature-request`, for
  feedback about the tooling itself, logged with `rule_id: null` (not
  the string `"unknown"`, which already means something else).
  `/swe:send-feedback`'s Step 2 now only clusters by a real `rule_id`;
  a placeholder (`null` or `"unknown"`) always surfaces its entries
  individually, closing the false-clustering bug the issue reported
  directly, and a singleton with a real `rule_id` is raised too,
  instead of waiting for a sibling. Took the task file's own "always
  individually" default for the one open question left in it, rather
  than stopping to ask again, since Jim's instruction ("do the
  feedback gaps, this is important") read as wanting execution.
  Verified against a scratch fixture, dry-run through the skill's own
  Steps 1-3 with no real GitHub calls: four distinct items came out,
  not the false-cluster bug. Full lint run over both edited skill
  files and the two docs referencing the verdict list; fixed what it
  found. All three test suites pass. Version bumped to 0.9.0. Shipped
  on `main` at
  [`233ee3d`](https://github.com/jimbarritt/claude-plugins/commit/233ee3d),
  which closed the issue automatically.

- Three-part removal, decided in one conversation and shipped in one
  commit: the `Stop` hook, the `PostToolUse` (`file-check.sh`) hook,
  and `force-for-plugin` on the output style. Jim asked to review the
  Stop hook's actual purpose before fixing issue #6's ~2s delay;
  found its reply check was already unconditionally dead under Claude
  Code (the output style was assumed to cover it), leaving only a
  once-per-turn markdown diff for that cost. Verdict: overbuilt from
  before the output style existed, remove rather than fix. Once that
  landed, `file-check.sh` (which deferred to the Stop hook for tracked
  markdown) went the same way — "output style is already doing
  something like this," `/swe:lint-file` covers on-demand checking —
  and `force-for-plugin` came off in the same pass, since its own
  justification (the Stop hook's reactive fallback) no longer existed.
  This also resolved `future-remove-force-for-plugin.md`'s open
  question, which depended on that same fallback.
  Net effect: no automatic checking of a file edit or a chat reply
  anymore, on either harness. `bash-check.sh`, `artifact-check.sh`,
  `mcp-send-check.sh` unaffected. Every doc/test reference to the
  removed hooks and flag updated in the same commit; full lint run
  over every touched file with real prose (README.md, the feedback
  skill), two findings fixed (a contrastive-framing warning, an
  overlong frontmatter description). All three test suites pass.
  Version bumped to 0.8.0. Shipped on `main` at
  [`cec8f1a`](https://github.com/jimbarritt/claude-plugins/commit/cec8f1a).
  Issue #6 closed with a comment explaining the actual resolution
  (the commit itself carried no `closes #6` trailer, since the fix
  ended up different from what was planned when the message was
  written). Full record split across
  [`issue-6-stop-hook-delay.md`](tasks/issue-6-stop-hook-delay.md),
  [`future-remove-force-for-plugin.md`](tasks/future-remove-force-for-plugin.md),
  and the new
  [`future-remove-file-check-hook.md`](tasks/future-remove-file-check-hook.md).
- The inference-tier mechanics discussion resolved by removing the
  subprocess entirely, at Jim's direction, once he pointed out
  `software_english_lint.py` should never spawn a process at all
  (everything here already runs inside a skill or a hook-dispatched
  subagent, which already has a model attached). `run_inference()`,
  `build_inference_prompt()`, and the `claude -p --safe-mode` call are
  gone; `--advise-inference`/`--force-inference` now both print a
  fenced `===INFERENCE_ADVISED===` rules block instead of running
  anything, gated for the former, unconditional for the latter. Every
  caller (the four hooks' dispatched subagent, `/swe:lint-file`'s own
  session) judges the prose against those rules directly, in its own
  context, deliberately not isolated from it the way `--safe-mode` used
  to be. `bash-check.sh`/`mcp-send-check.sh` no longer need a scratch
  file, since the checked text goes straight into the advisory message.
  `config.json`'s `fast_model`/`model_call_timeout_seconds` are gone
  too, dead once there was no subprocess to configure.
  `send-feedback/SKILL.md`'s stalled-call pattern detection is gone,
  since there is no longer a call to stall. Caught and fixed several
  deterministic-tier findings (em dashes, a banned word, two overlong
  frontmatter descriptions) in files this touched, by actually running
  the full lint over them rather than assuming they were clean. Version
  bumped to 0.7.0. Shipped on `main` at
  [`bd9edac`](https://github.com/jimbarritt/claude-plugins/commit/bd9edac).
- Small follow-ups after the inference-tier rework shipped: the output
  style's picker description revised twice more at Jim's direction
  (added the spec URL, then made it a real clickable `https://` link);
  `swe/README.md` brought current with the rework (subagent-dispatch
  mechanism named explicitly, a stale duplicate closing line cut) and
  then actually run through the plugin's own full lint as asked — caught
  four em dashes that edit itself introduced (fixed) and one
  `banned-word` false positive on "Drive" in "Slack/Gmail/Drive" (the
  product name, not the verb; logged via `/swe:feedback`, text left as
  is). Shipped on `main` at
  [`4a75dfe`](https://github.com/jimbarritt/claude-plugins/commit/4a75dfe),
  [`a53b53d`](https://github.com/jimbarritt/claude-plugins/commit/a53b53d),
  [`bed5dec`](https://github.com/jimbarritt/claude-plugins/commit/bed5dec),
  [`b3b1732`](https://github.com/jimbarritt/claude-plugins/commit/b3b1732).
- [tasks/future-inference-tier-rework.md](tasks/future-inference-tier-rework.md):
  both ideas shipped together. Idea 1: the four non-`Stop` hooks no
  longer call `claude -p --safe-mode` themselves; each calls the
  linter with a new `--advise-inference` flag, which only decides
  whether a fresh pass is worth dispatching, and the hook turns that
  into a non-blocking advisory hook response telling Claude to
  dispatch a subagent to run the real check and report back. Idea 2:
  a single named file is throttled by growth since its last recorded
  `--force-inference` pass (`~/.claude/swe/inference-state.json`), not
  a flat per-edit threshold, so a file with known outstanding findings
  is not re-advised on every follow-up fix. Also fixed the output
  style's picker description (Jim's second ask this session). Both
  existing test suites pass; a new
  `tests/inference_eligible_test.sh` covers the throttle directly.
  Shipped on `main` at
  [`3108620`](https://github.com/jimbarritt/claude-plugins/commit/3108620).
- [tasks/future-plugin-rename.md](tasks/future-plugin-rename.md): renamed
  the plugin `software-english-lint` -> `swe` and dropped the `swe-`
  prefix from each command, so the picker shows `swe:feedback` instead
  of `software-english-lint:swe-feedback`. Full scope from the task
  file applied, including the directory rename, the three skill
  directory renames, the local state paths under `~/.claude/`, and
  every cross-reference in the docs. Both test suites pass. Shipped on
  `main` at
  [`b27f7e5`](https://github.com/jimbarritt/claude-plugins/commit/b27f7e5).
- [tasks/future-lint-command.md](tasks/future-lint-command.md): a new
  `/swe-lint-file` command runs a full lint (deterministic tier plus a
  forced, ungated inference tier) on a named file, on demand. Added
  `--force-inference` to the linter for it; `--run-inference`'s gate,
  used by the four hooks, is unchanged. Shipped on `main` at
  [`b06d0fc`](https://github.com/jimbarritt/claude-plugins/commit/b06d0fc).
- [tasks/issue-3-data-fetch-crash.md](tasks/issue-3-data-fetch-crash.md)
  ([issue #3](https://github.com/jimbarritt/claude-plugins/issues/3)):
  a cloud session's egress policy blocked the plugin's raw-HTTPS data
  fetch, and the linter crashed instead of failing open, which blocked
  every turn. Fixed (git-clone-based fetch, plus a real fail-open path
  in the linter) and shipped on `main` at
  [`6f08705`](https://github.com/jimbarritt/claude-plugins/commit/6f08705),
  closing the issue automatically. Diagnosed and fixed in one pass, no
  design discussion needed.
- [tasks/future-swe-output-style.md](tasks/future-swe-output-style.md):
  a plugin output style, forced on with `force-for-plugin: true`, puts
  Software English's rules directly in the system prompt. Claude
  Code's `stop-check.sh` reply/transcript check now skips outright;
  Copilot CLI, which has no output-style mechanism, keeps it unchanged.
  Shipped on `main`, pushed.
- [Issue #2](https://github.com/jimbarritt/claude-plugins/issues/2):
  `software-english-lint` per-hook enable/disable. Shipped on `main` at
  [`36391c4`](https://github.com/jimbarritt/claude-plugins/commit/36391c4),
  which closed the issue automatically. See
  [tasks/issue-2-per-hook-toggle.md](tasks/issue-2-per-hook-toggle.md)
  for the full record, including a jq gotcha the new unit test caught.

See [tasks/index.md](tasks/index.md) for the full task list.

## Repos in scope

- `jimbarritt/claude-plugins` - primary repo for this work.
- `jimbarritt/software-english` - upstream spec repo, changed when a
  plugins-repo task needs a spec change.
