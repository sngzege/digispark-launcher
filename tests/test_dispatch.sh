#!/usr/bin/env bash
# Unit tests for dispatch.sh. Run from repo root: bash tests/test_dispatch.sh
set -u

fails=0
assert_eq() {
  if [ "$1" = "$2" ]; then echo "ok   - $3"
  else echo "FAIL - $3 (expected '$2', got '$1')"; fails=$((fails + 1)); fi
}
assert_contains() {
  case "$1" in
    *"$2"*) echo "ok   - $3" ;;
    *) echo "FAIL - $3 (output did not contain '$2')"; fails=$((fails + 1)) ;;
  esac
}

# shellcheck disable=SC1091
. ./dispatch.sh

# read_choice: input validation (1-4 valid)
assert_eq "$(read_choice 1)" "1"    "read_choice: '1' valid"
assert_eq "$(read_choice 4)" "4"    "read_choice: '4' valid"
assert_eq "$(read_choice q)" "quit" "read_choice: 'q' quits"
assert_eq "$(read_choice x)" ""     "read_choice: invalid -> empty"
assert_eq "$(read_choice '')" ""    "read_choice: empty -> empty"
assert_eq "$(read_choice 5)" ""     "read_choice: out of range -> empty"

# parse_menu: 'N=Label' lines, skip blanks/comments
assert_eq "$(parse_menu "$(printf '1=Disk Cleaner\n# note\n\n2=Health')")" \
  "$(printf '1\tDisk Cleaner\n2\tHealth')" "parse_menu: parses valid, skips noise"

# render_menu: human labels
assert_contains "$(render_menu '1=Disk Cleaner')" "1 - Disk Cleaner" "render_menu: shows label"

# run_op: success (fetch reads local fixture)
fetch() { cat ./tests/fixtures/op.sh; }
out="$(run_op 1)"; rc=$?
assert_eq "$rc" "0"           "run_op: success -> 0"
assert_eq "$out" "op ran"     "run_op: executes fetched script"

# run_op: fetch fails -> no crash, returns 1
fetch() { return 1; }
run_op 1 >/dev/null 2>&1; rc=$?
assert_eq "$rc" "1"           "run_op: fetch failure -> 1"

# main: reads input from $TTY, not the pipe (curl|bash scenario)
fetch() { echo "echo RAN:$1"; }
ttyfile="$(mktemp)"; printf '2\nq\n' > "$ttyfile"
out="$(TTY="$ttyfile" main <<<'9')"
rm -f "$ttyfile"
assert_contains "$out" "RAN:ops/0.sh" "main: ops/0 runs automatically"
assert_contains "$out" "RAN:ops/2.sh" "main: reads '2' from \$TTY and runs ops/2"

# load_env: safely exports .env lines
unset TEST_KEY_X TEST_KEY_Y BAD 2>/dev/null
load_env "$(printf '# comment\n\nTEST_KEY_X=val1\nBAD KEY=nope\nTEST_KEY_Y=val2')"
assert_eq "${TEST_KEY_X:-}" "val1" "load_env: exports valid KEY=VALUE"
assert_eq "${TEST_KEY_Y:-}" "val2" "load_env: exports second valid line"
assert_eq "${BAD:-}" ""            "load_env: skips invalid key"

# apply_env_base: rebuilds BASE from GH_* vars
GH_OWNER=foo; GH_REPO=bar; GH_BRANCH=dev
apply_env_base
assert_eq "$BASE" "https://raw.githubusercontent.com/foo/bar/dev/" "apply_env_base: builds BASE from GH_*"
unset GH_OWNER GH_REPO GH_BRANCH

echo "---"
if [ "$fails" -eq 0 ]; then echo "ALL TESTS PASSED"; else echo "$fails test(s) failed"; exit 1; fi
