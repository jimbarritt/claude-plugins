#!/usr/bin/env bash
# Reports a plugin whose committed work has not been released.
#
# A plugin that declares a version in its own plugin.json is pinned to
# that string: an installed copy takes a new version only when the
# string changes. Pushing to main delivers nothing on its own. Work can
# therefore sit on main, correct and merged, and be installed by nobody.
#
# That happened six times in this repository before this check existed.
# Each was carried to users later, by the next commit that did bump the
# version, so nothing was lost; each sat undelivered until then.
#
# The rule, per plugin:
#
#   plugin.json's version is still the version of the newest release
#   tag, AND commits since that tag touch the plugin's own directory
#   -> those commits are not released and cannot be installed.
#
# A version already ahead of the newest tag is a release in progress,
# not a fault. A plugin with no tag at all has never been released, so
# there is nothing to compare against.
#
# Usage: scripts/check-unshipped.sh [<plugin> ...]
# With no argument, every plugin in .claude-plugin/marketplace.json.
# Exit 0 when every plugin checked is released, 1 when one is not.
set -uo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
cd "$HERE" || exit 1

PLUGINS=("$@")
if [ "${#PLUGINS[@]}" -eq 0 ]; then
  while IFS= read -r name; do
    [ -n "$name" ] && PLUGINS+=("$name")
  done < <(jq -r '.plugins[].name' .claude-plugin/marketplace.json 2>/dev/null)
fi

if [ "${#PLUGINS[@]}" -eq 0 ]; then
  echo "check-unshipped: no plugin to check." >&2
  exit 0
fi

STATUS=0
for plugin in "${PLUGINS[@]}"; do
  manifest="$plugin/.claude-plugin/plugin.json"
  if [ ! -f "$manifest" ]; then
    echo "check-unshipped: $manifest not found; skipping $plugin." >&2
    continue
  fi

  version="$(jq -r '.version // empty' "$manifest" 2>/dev/null)"
  if [ -z "$version" ]; then
    # No declared version: the resolved commit is the version, so every
    # push delivers and there is nothing here to miss.
    echo "$plugin: no version declared, so each commit delivers on its own. Nothing to check."
    continue
  fi

  tag="$(git tag -l "$plugin-v*" --sort=-v:refname | head -1)"
  if [ -z "$tag" ]; then
    echo "$plugin: never released (no $plugin-v* tag). Nothing to compare against."
    continue
  fi

  tag_version="${tag#"$plugin"-v}"
  if [ "$version" != "$tag_version" ]; then
    echo "$plugin: version $version is ahead of the newest tag $tag. A release is pending; run the release workflow."
    continue
  fi

  count="$(git rev-list --count "$tag..HEAD" -- "$plugin/" 2>/dev/null)"
  if [ -z "$count" ] || [ "$count" -eq 0 ]; then
    echo "$plugin: $version is released and matches $tag. Up to date."
    continue
  fi

  STATUS=1
  echo
  echo "$plugin: $count commit(s) since $tag change $plugin/ and are not released."
  echo "Anyone installing $plugin today gets $version, which does not hold them:"
  echo
  git log --format='  %h %s' "$tag..HEAD" -- "$plugin/"
  echo
  echo "Bump \"version\" in $manifest, commit, then run the release workflow:"
  echo "  gh workflow run release-plugin.yml -f plugin=$plugin"
done

exit "$STATUS"
