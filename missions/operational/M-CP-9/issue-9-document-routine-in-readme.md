# Issue #9: document the self-maintaining-repo Routine in swe's README

## Ask, verbatim

**Title:** Document the self-maintaining-repo Routine in swe's README

**Body:**

> A short paragraph, or small new section, in `swe/README.md` (or a new
> doc under `swe/docs/`) explaining that this repository processes some
> issues through an unattended Routine: it reads a briefing on the
> `planning` branch (`MAINTAINER-RUN.md`), works the issue, tests,
> bumps the plugin version, releases, and closes it. Point readers at
> `tasks/future-self-maintaining-repo.md` on the `planning` branch for
> the full design.
>
> Scope: documentation only, inside `swe/`. Bump `swe`'s version per
> the repository's own release rule (`CLAUDE.md`, "Releasing a
> change") since this touches the plugin directory, and run the
> release workflow.
>
> This is the first real test issue for the self-maintaining-repo
> Routine itself.

Opened by `jimbarritt` (trusted, repository owner), labelled `agent:go`.

## Reading

A single new README section describing the Routine's mechanism from a
reader's point of view: what happens to an issue filed against this
repository, in plain terms, with a pointer to the full design on
`planning` rather than restating it. No behaviour change; documentation
only, so the version bump is a patch.

This run is itself the first real issue the Routine has worked, which
is part of why it is worth getting right: the README's description of
"what happens" needs to match this run's actual steps, not an idealised
version of them.

## Plan (from the Opus Plan subagent)

### Decision: a README section, not a new doc under `swe/docs/`

`swe/docs/` holds two files, `agent-guide.md` (for an agent running in
a project with the plugin installed) and `output-taxonomy.md` (a rule
reference table). Neither fits repository process. A new file would
need a README link to be discoverable anyway, so the change lands in
`swe/README.md` directly, plus the version bump.

### Placement

New `##` section after the existing "## Review logged feedback and
file issues" section (`/swe:feedback` and `/swe:send-feedback`, which
ends by filing a `gh issue create` against this repository) and before
"## Exempt a whole file from every check". A reader who just filed an
issue is at the exact point where "what happens to it next" belongs.

### Heading

`## What happens to an issue filed here`

Matches the README's existing descriptive-heading form ("What happens
once it is installed", "What the output style costs").

### Draft prose

```markdown
## What happens to an issue filed here

Some issues on `jimbarritt/claude-plugins` go through an unattended
Routine rather than an attended session. A Routine starts a fresh
Claude session on a schedule. That session reads its briefing,
`MAINTAINER-RUN.md`, from the `planning` branch, then takes one open
issue. It writes a task file on `planning`, then does the work on
`main`. It runs the test suites and the lint checks. It bumps the
affected plugin's `version` in `plugin.json` and runs the release
workflow. It then comments on the issue with the commit and the
release tag, and closes the issue.

An issue qualifies when it has the `agent:go` label, or when a
trusted account opened it. A run that cannot finish the work without
an answer writes one question on the issue. It swaps the
`agent:working` label for `supervisor` and leaves the issue open.

This Routine is part of the repository's own maintenance, not
behaviour the plugin installs.

`tasks/future-self-maintaining-repo.md` on the `planning` branch
holds the full design. It states the labels, the trusted-account
rule, the model split, and the escalation path.
```

Cross-reference style follows the existing precedent at
`swe/docs/agent-guide.md:46` ("See `STATE.md` on the `planning`
branch..."): path in backticks, branch named in prose, no link, since
`planning` shares no history with `main` and a relative link would
404.

### Version bump

`swe/.claude-plugin/plugin.json`: `0.11.0` -> `0.11.1` (patch; docs
only, no new behaviour, matching the `0.10.1` precedent).

### Implementation sequence

1. Edit `swe/README.md`, insert the section.
2. Edit `swe/.claude-plugin/plugin.json`, bump version.
3. Run `/swe:lint-file swe/README.md`; fix any finding.
4. Run the five suites in `swe/tests/`.
5. `git fetch --tags`, then `scripts/check-unshipped.sh`.
6. Commit to `main` directly with `closes #9`, push.
7. `actions_run_trigger` on `release-plugin.yml -f plugin=swe`; poll
   `actions_get` until it finishes.
8. Re-run `scripts/check-unshipped.sh` after `git fetch --tags` to
   confirm the release matches.

### Watch items

- Leave the `<!-- swe: ignore -->` marker on the Slack/Gmail/Drive
  table row undisturbed.
- Keep the gloss sentence defining "Routine" in place, in case the
  inference tier flags the term as unexplained otherwise.
- Deliberately omit the planning-branch version-bump exemption from
  the README; that is process detail for the design document, not for
  README readers.

## Outcome

Shipped as planned, no deviations.

- `swe/README.md`: new "What happens to an issue filed here" section
  inserted after "## Review logged feedback and file issues", exact
  text as drafted above.
- `swe/.claude-plugin/plugin.json`: `0.11.0` -> `0.11.1`.
- Lint: deterministic tier clean (only pre-existing, unrelated
  `vocabulary-membership` warnings across the whole file); reviewed
  the inference-tier rule categories against the new prose by hand
  (no rule catalogue-dispatch subagent available in this session) and
  found nothing to fix. The `tasks/future-self-maintaining-repo.md`
  pointer was weighed against `no-planning-content-in-reference`
  (a Reference document should carry no pointer to a plan document);
  treated as acceptable, following the same already-shipped pattern at
  `swe/docs/agent-guide.md:46` ("See `STATE.md` on the `planning`
  branch...").
- All five `swe/tests/*.sh` suites pass (67 assertions total).
- `scripts/check-unshipped.sh` confirmed pending before release, clean
  after.
- Commit: [`dbf434d`](https://github.com/jimbarritt/claude-plugins/commit/dbf434d25400f24a9b791693c276073b63a3f8e)
  on `main`, `closes #9` (closed the issue automatically).
- Release: `release-plugin.yml` run
  [#6](https://github.com/jimbarritt/claude-plugins/actions/runs/35622003689),
  success, tag `swe-v0.11.1`.
- Issue comment posted with the commit, version, and release tag.

First real issue worked end to end by this Routine, single pass, no
escalation.
