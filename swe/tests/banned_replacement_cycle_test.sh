#!/usr/bin/env bash
# Covers software-english#23: no row's replacement text in
# vocabulary/banned.tsv may itself contain a phrase that banned.tsv bans,
# or a writer who follows the suggested fix trades one banned-word finding
# for another.
#
# Uses the real load_banned() from scripts/software_english_lint.py, so the
# matching is exactly the banned-word rule's own \b<phrase>\b
# case-insensitive regex per row, not a reimplementation that could drift
# from it.
#
# Runs against real Software English data, the same convention as
# motion_idiom_test.sh: SWE_SRC=<software-english checkout> copies
# vocabulary/ and rules/ from a local checkout; without it, the fixture
# fetches the tag pinned in software-english.json. Skips with exit 0 if
# neither source is available (offline, no local checkout).
#
# Run: swe/tests/banned_replacement_cycle_test.sh
#      SWE_SRC=/path/to/software-english swe/tests/banned_replacement_cycle_test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PLUGIN_ROOT="$HERE/.."

PASS=0
FAIL=0

assert() {
  local desc="$1" ok="$2"
  if [ "$ok" -eq 0 ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
  fi
}

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

FIXTURE="$TMP/plugin"
mkdir -p "$FIXTURE"
cp -r "$PLUGIN_ROOT/scripts" "$FIXTURE/scripts"
cp "$PLUGIN_ROOT/config.json" "$PLUGIN_ROOT/software-english.json" "$FIXTURE/"
if [ -n "${SWE_SRC:-}" ]; then
  mkdir -p "$FIXTURE/data"
  cp "$SWE_SRC"/vocabulary/*.tsv "$FIXTURE/data/"
  cp "$SWE_SRC"/rules/core-rules.toml "$FIXTURE/data/"
elif ! "$FIXTURE/scripts/fetch-software-english-data.sh" >/dev/null 2>&1; then
  echo "SKIP: no SWE_SRC and the pinned software-english tag could not be fetched"
  exit 0
fi

# --- precondition: real banned.tsv data loaded (else the check below is vacuous) ---
assert "banned.tsv present in the fixture" "$([ -f "$FIXTURE/data/banned.tsv" ]; echo $?)"
ROW_COUNT="$(PYTHONPATH="$FIXTURE/scripts" python3 -B -c "
import software_english_lint as m
print(len(m.load_banned()))
")"
assert "load_banned() returns more than 0 rows" "$([ "$ROW_COUNT" -gt 0 ]; echo $?)"

# --- core check: no row's fix matches any row's banned phrase, by the real regex ---
CYCLES="$(PYTHONPATH="$FIXTURE/scripts" python3 -B -c "
import software_english_lint as m
rules = m.load_banned()
for phrase, fix, _ in rules:
    for banned, _, pattern in rules:
        if pattern.search(fix):
            print(f'{phrase}\t{fix}\t{banned}')
")"
if [ -n "$CYCLES" ]; then
  while IFS=$'\t' read -r phrase fix banned; do
    echo "FAIL: replacement for \"$phrase\" (\"$fix\") contains banned \"$banned\""
  done <<<"$CYCLES"
fi
assert "no banned.tsv replacement contains a banned phrase" "$([ -z "$CYCLES" ]; echo $?)"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
