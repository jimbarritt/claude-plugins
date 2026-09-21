# Trusted authors: overlay

The self-maintaining-repo Routine (see
[tasks/future-self-maintaining-repo.md](tasks/future-self-maintaining-repo.md))
treats every `jimbarritt/claude-plugins` collaborator as trusted by
default, checked each run via `list_repository_collaborators`,
which itself requires push access to call. This file is the overlay:
an account listed here is trusted without holding push access to the
repository.

Empty today. Every trusted account is already a collaborator, so
nothing needs adding. Add a login here only for an account Jim wants
to trust without granting it push access, one per line, matched
case-insensitively. `claude-plugins` is a public repository, so an
entry here is visible to anyone who reads this branch; weigh that
before adding one, and prefer a private location (the Routine's own
stored prompt, never published to the repository, or a private gist)
if Jim wants an entry to stay unpublished.

Jim edits this file directly to add or remove an account. No
automation writes to it.

## Accounts

None listed.
