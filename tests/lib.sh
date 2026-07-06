#!/usr/bin/env bash
# Shared test helpers. Source this from each test file.
set -u

TESTS_PASSED=0
TESTS_FAILED=0

# Create a temp dir with a fake-bin on PATH front. Sets FAKEBIN and TMPDIR_T.
setup_shims() {
  TMPDIR_T="$(mktemp -d)"
  FAKEBIN="$TMPDIR_T/bin"
  mkdir -p "$FAKEBIN"
  export PATH="$FAKEBIN:$PATH"
}

teardown_shims() {
  rm -rf "$TMPDIR_T"
}

assert_eq() {
  local expected="$1" actual="$2" msg="${3:-}"
  if [ "$expected" = "$actual" ]; then
    TESTS_PASSED=$((TESTS_PASSED+1)); echo "  ok: $msg"
  else
    TESTS_FAILED=$((TESTS_FAILED+1))
    echo "  FAIL: $msg"; echo "    expected: [$expected]"; echo "    actual:   [$actual]"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    TESTS_PASSED=$((TESTS_PASSED+1)); echo "  ok: $msg"
  else
    TESTS_FAILED=$((TESTS_FAILED+1))
    echo "  FAIL: $msg (needle not found: $needle)"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" msg="${3:-}"
  if printf '%s' "$haystack" | grep -qF -- "$needle"; then
    TESTS_FAILED=$((TESTS_FAILED+1))
    echo "  FAIL: $msg (unexpected substring present: $needle)"
  else
    TESTS_PASSED=$((TESTS_PASSED+1)); echo "  ok: $msg"
  fi
}

finish() {
  echo "---"
  echo "passed: $TESTS_PASSED  failed: $TESTS_FAILED"
  [ "$TESTS_FAILED" -eq 0 ]
}
