#!/usr/bin/env bash
set -euo pipefail

suite="${1-smoke}"
if [ "$#" -gt 1 ] || { [ "$suite" != smoke ] && [ "$suite" != extended ]; }; then
  echo "Usage: bash tests/run_smoke.sh [smoke|extended]" >&2
  exit 2
fi

cd "$(dirname "$0")/.."
godot="${GODOT_BIN:-godot}"
if ! command -v "$godot" >/dev/null 2>&1; then
  echo "Godot executable not found: $godot (set GODOT_BIN to its path)." >&2
  exit 127
fi

tests=(audio branding editing interface layout localization loop preset schedule simulation terminal train_controls transfer urban)
if [ "$suite" = extended ]; then
  tests+=(intersection)
fi

total_start=$SECONDS
for test in "${tests[@]}"; do
  command=("$godot" --headless --path . --script "res://tests/${test}_smoke.gd")
  if [ "$suite" = smoke ] && { [ "$test" = schedule ] || [ "$test" = preset ] || [ "$test" = terminal ]; }; then
    command+=(-- --fast)
  fi
  echo "=== $suite: $test ==="
  start=$SECONDS
  if "${command[@]}"; then
    echo "PASS $test ($((SECONDS - start))s)"
  else
    status=$?
    echo "FAIL $test ($((SECONDS - start))s), exit $status" >&2
    exit "$status"
  fi
done
echo "PASS $suite: ${#tests[@]} scripts ($((SECONDS - total_start))s)"
