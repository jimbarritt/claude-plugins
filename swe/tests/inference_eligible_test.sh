#!/usr/bin/env bash
# Unit tests for inference_eligible() and save_inference_state() in
# scripts/software_english_lint.py: the growth-since-last-pass throttle
# behind --advise-inference. Deterministic and offline: exercises the
# functions directly via python3 -c, against a scratch $HOME, so it
# needs no fetched rule catalogue, no network, and no `claude` on PATH.
#
# Run: swe/tests/inference_eligible_test.sh
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS="$HERE/../scripts"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $desc"
    echo "  expected: $expected"
    echo "  actual:   $actual"
  fi
}

TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT

run_py() {
  HOME="$TMPHOME" PYTHONPATH="$SCRIPTS" python3 -c "$1"
}

CFG='{"threshold_words": 60, "threshold_sentences": 4}'

OUT="$(run_py "
import software_english_lint as m
cfg = $CFG
print(m.inference_eligible('/tmp/none-yet.md', 10, 1, cfg))
")"
assert_eq "no recorded state, below absolute threshold: not eligible" "False" "$OUT"

OUT="$(run_py "
import software_english_lint as m
cfg = $CFG
print(m.inference_eligible('/tmp/none-yet.md', 70, 8, cfg))
")"
assert_eq "no recorded state, past absolute threshold: eligible" "True" "$OUT"

OUT="$(run_py "
import software_english_lint as m
cfg = $CFG
print(m.inference_eligible(None, 500, 50, cfg))
")"
assert_eq "no key (a text/HTML source): eligible, same as first pass" "True" "$OUT"

run_py "
import software_english_lint as m
m.save_inference_state('/tmp/note.md', 80, 8)
"
OUT="$(run_py "
import software_english_lint as m
cfg = $CFG
print(m.inference_eligible('/tmp/note.md', 85, 8, cfg))
")"
assert_eq "recorded pass, small edit since (below threshold growth): not eligible" "False" "$OUT"

OUT="$(run_py "
import software_english_lint as m
cfg = $CFG
print(m.inference_eligible('/tmp/note.md', 145, 8, cfg))
")"
assert_eq "recorded pass, grown past threshold_words since: eligible" "True" "$OUT"

OUT="$(run_py "
import software_english_lint as m
cfg = $CFG
print(m.inference_eligible('/tmp/note.md', 82, 15, cfg))
")"
assert_eq "recorded pass, grown past threshold_sentences since (words alone would not qualify): eligible" "True" "$OUT"

OUT="$(run_py "
import software_english_lint as m
cfg = $CFG
print(m.inference_eligible('/tmp/note.md', 60, 6, cfg))
")"
assert_eq "recorded pass, prose shrank since: not eligible" "False" "$OUT"

OUT="$(run_py "
import software_english_lint as m
before = sorted(m.load_inference_state())
m.save_inference_state(None, 999, 99)
after = sorted(m.load_inference_state())
print(before == after)
")"
assert_eq "save_inference_state(None, ...) adds no entry" "True" "$OUT"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
