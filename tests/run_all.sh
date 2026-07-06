#!/usr/bin/env bash
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
fail=0
for t in "$HERE"/test_*.sh; do
  echo "=== $t ==="
  bash "$t" || fail=1
done
exit "$fail"
