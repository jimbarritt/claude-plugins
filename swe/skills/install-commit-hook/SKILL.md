---
name: install-commit-hook
description: Install swe's git pre-commit check here, and the tsk documents hook when tsk 0.26.1 or later is installed
argument-hint: "[uninstall] [repo-path]"
allowed-tools: Bash, Read
disable-model-invocation: false
---

# install-commit-hook

Install a git `pre-commit` hook in one repository. Once installed, a
commit that stages a markdown file is blocked unless that file's exact
staged content has a `clean` verdict recorded by `/swe:lint-file`. When
[tsk](https://github.com/jimbarritt/tsk) 0.26.1 or later is installed
and `swe/config.json`'s `docs_hook.enabled` is `true`, also offer tsk's
own documents hook, so a `tsk ledger push` or `tsk ledger doc put` of a
ledger document gets the same check, since tsk runs its own git
commands with git hooks disabled. `docs_hook.enabled` defaults to
`false` (claude-plugins#22: built and released, off by default pending
some use of the manual route).

## Step 1: Read the arguments

Arguments given: $ARGUMENTS

This is blank, a repository path, the word `uninstall`, or `uninstall`
followed by a path. Blank means the current project. Pass `uninstall` to
the installer as `--uninstall`, and pass any path as `<repo-path>`.

## Step 2: Run the git-commit-hook installer

```
"${CLAUDE_PLUGIN_ROOT}/scripts/install-commit-hook.sh" [--uninstall] [<repo-path>]
```

Exit 0 means the hook is in place (installed, updated, already current,
or removed for `--uninstall`). Exit 1 means nothing was changed: the
path is not a git repository, or a `pre-commit` hook and a
`pre-commit.local` file both already exist there, which the installer
never overwrites. Report the script's own lines as it printed them.

If the installer reported that it chained an existing hook, name the
file it moved (`pre-commit.local`) and say that hook still runs first,
unchanged. Continue to Step 3 either way: the tsk documents hook needs
no git repository for its own user place, so a Step 2 failure does not
rule it out.

## Step 3: Check for tsk

First read `${CLAUDE_PLUGIN_ROOT}/config.json`'s `docs_hook.enabled`
field. When it is `false`, say "the tsk documents hook is off for now
(`swe/config.json`'s `docs_hook.enabled` is `false`)" and go to Step 6,
running none of the commands below.

```
"${CLAUDE_PLUGIN_ROOT}/scripts/install-docs-hook.sh" --detect [<repo-path>]
```

This always exits 0 and prints tab-separated lines. Read the first:

- `tsk	absent`: say "tsk is not installed, so the documents hook was
  skipped." Go to Step 6.
- `tsk	too-old	<ver>` or `tsk	unknown-version	...`: say "The
  documents hook needs tsk 0.26.1 or later; found `<ver>`. Skipped." Go
  to Step 6.
- `tsk	ok	<ver>`: continue to Step 4.

## Step 4: Ask where

When `tsk` is `ok`, the remaining lines name the three places tsk's own
`config docs-hook` understands, each as `place	<name>	<path>	<state>`
(`<state>` is `absent`, `swe <n>` meaning already installed, `foreign`
meaning a file this script did not write, or `unavailable` with a
reason as a fifth field), and a final `active	...` block with the raw
lines of `tsk config docs-hook` (which place currently applies, if
any). Present the three places to the user, one line each:

- **user**: every ledger of this user, including a repository the user
  does not control. The right default there.
- **clone**: this clone only.
- **repo**: committed, so every contributor is checked. Use only in a
  repository the user controls.

Name each place's path and state, mark `foreign` or `unavailable` as
not available (with the reason), and show the `active` lines. Ask one
question, per this project's one-question-at-a-time convention:
"Which place: user, clone, repo, or none?" Recommend `user`. Wait for
the answer. If the answer is `none`, go to Step 6.

## Step 5: Install the documents hook

```
"${CLAUDE_PLUGIN_ROOT}/scripts/install-docs-hook.sh" --place <choice> [<repo-path>]
```

Exit 3 means tsk is absent or too old (re-checked; should not happen
right after Step 3). Exit 1 means the chosen place is unavailable, or
already has a foreign `pre-docs-commit` file the script will not
overwrite: report where the file is and stop; this command does not
relocate or overwrite it. Exit 0 means it installed, updated, or was
already current; report the script's own lines, including the `tsk
config docs-hook` output it prints at the end. If that output names a
different script than the one just installed (another place, set
earlier, has precedence), name the file that applies instead.

For `--uninstall`: after Step 2's uninstall, run `--detect` again. If
any place reports `swe <n>`, ask the user which of those places to
remove the documents hook from, then run `install-docs-hook.sh
--uninstall --place <choice> [<repo-path>]`.

## Step 6: Report what the check does

State, in a few short lines: which file(s) it installed and where; that
a staged markdown file then needs a `clean` record from
`/swe:lint-file` for its exact staged content; and that `.git/` is
never cloned, so each clone of this repository needs this command run
again.

If a tsk documents hook was also installed, add: `tsk ledger doc put`
and `tsk ledger push` now run the deterministic tier on changed
Markdown ledger documents; an error-severity finding makes `doc put`
exit 1 (the document is still written locally) or stops `push` before
anything is pushed; no model is called. The script finds the installed
swe plugin's linter at run time, so running this command again after a
swe update is what keeps the documents hook working.

## Step 7: State how to bypass the check

Say once, plainly: `git commit --no-verify` bypasses the git commit
check, and the block message repeats that. Do not use it to work
around a block without saying so. Say nothing here about bypassing the
documents hook: that bypass exists for tsk itself, not for an agent
working in this repository, to use.
