# Future task: list `swe` in the Claude plugin directory

No GitHub issue. Raised by Jim in conversation on 2026-09-30. Jim
submitted the plugin through the developer portal on 2026-10-01.

## Ask

Jim, verbatim: "we need to add a license so we can be listed in the
Claude plugin directory", with the Anthropic Software Directory Policy
as the reference. He named the license as the blocking requirement.

## What the requirement is

- The policy article
  (`support.claude.com/en/articles/13145358-anthropic-software-directory-policy`)
  has no license section. Its sections are Safety and Security,
  Compatibility, Developer Requirements, Unsupported Use Cases, and
  MCP server specifics.
- The license requirement comes from the directory's own submission
  process. Each plugin repository needs its own open source `LICENSE`
  file. The official directory repository,
  `anthropics/claude-plugins-official`, says only "see each linked
  plugin for the relevant LICENSE file". Anthropic does not mandate one
  license. Third-party guides name MIT and Apache-2.0 as common
  choices. Submission is through a form at `clau.de/plugin-directory-submission`.
- The portal validator asked for two more things, found as it ran:
  an `author` field and an icon.
- Developer Requirements in the policy article: a privacy policy link,
  verified contact and support channels, documentation of function and
  troubleshooting, a test account with sample data, three example
  prompts, verified ownership of connected APIs and domains, ongoing
  maintenance, and agreement to the Software Directory Terms. My
  reading is that several do not apply to a plugin with no OAuth, no
  external API, and no user data. That reading is unverified. Jim
  completed the portal himself, and this record does not show what
  else it asked for.

## What shipped

All on `claude-plugins` `main`. `plugin.json` is the only place the
metadata is set, per `CLAUDE.md`.

- **License.** Apache-2.0, Jim's choice over MIT. Reasons: it matches
  `software-english`, it grants patents explicitly (section 3), and its
  trademark clause (section 6) states in the license text that using
  the Claude and Anthropic names confers no trademark right. A root
  `LICENSE` file (copied from `software-english`, `Copyright 2026 Jim
  Barritt`), the `"license": "Apache-2.0"` field in `plugin.json`, and
  a Licence section in the root `README.md`.
  [`bc66312`](https://github.com/jimbarritt/claude-plugins/commit/bc66312),
  merged at
  [`18a0ba8`](https://github.com/jimbarritt/claude-plugins/commit/18a0ba8),
  released as `swe-v0.16.2`.
- **Author.** `name` and the GitHub URL. No email, since publishing a
  personal address in a public file is Jim's choice. `claude plugin
  validate` then passed with no warnings.
  [`2379677`](https://github.com/jimbarritt/claude-plugins/commit/2379677),
  `swe-v0.16.3`.
- **Icon.** `swe/.claude-plugin/icon.png`, 1024 x 1024 px, 21 KB: "swe"
  in white monospace bold on black. Jim reviewed two drafts first,
  because the portal takes the icon only once, at the first save or
  submission. The icon is therefore fixed now.
  [`bca25f3`](https://github.com/jimbarritt/claude-plugins/commit/bca25f3),
  `swe-v0.16.4`.

## One thing that cost time

The first push was rejected. Six Routine commits were already on
`main` (issues #10 to #14, including the nonce-based lint ledger and the
`software-english` v0.0.9 and v0.0.10 pins), taking `swe` from 0.12.1 to
0.16.1. The merge conflicted only on the `version` line of
`plugin.json`. Resolution: keep the newer 0.16.1 as the base, add the
license field, bump to 0.16.2.

After the merge, the pre-commit check blocked the merge commit for three
markdown files the Routine had already vetted and pushed. The lint
ledger lives under `.git/` and is per clone, so another session's
records do not travel. The files were re-linted locally with the new
`--nonce` step before the merge commit went through. The cost was small,
but a merge that pulls in already-vetted markdown always repeats it.

## Open

- The directory's review of the submission. Status on 2026-10-01, as
  Jim reported it: waiting for review. The listing sits on Jim's manage
  plugins page in the portal, which needs his sign-in, so a session
  cannot read it (HTTP 403). Check the outcome when Jim reports it. A reviewer may ask for changes
  to `plugin.json`, the README, or the plugin's own documentation.
- Any change to `plugin.json` needs a version bump and a release,
  per `CLAUDE.md`, or an installed copy does not pick it up.
- Optional: `claude plugin validate .` warns that `marketplace.json` has
  no description. A one-line fix outside `swe/`, so no release. Offered
  to Jim on 2026-10-01, not yet answered.
