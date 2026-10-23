#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/chiakey-secure-input.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
IMK_DIR="$ROOT_DIR/ChiaKey-Source/Loaders/OSX-IMK"
clang -fblocks -Wall -Wextra -Werror -I"$IMK_DIR" \
  "$ROOT_DIR/Scripts/tests/TestSecureInputWatch.m" \
  -framework Foundation -o "$TEST_DIR/test-secure-input-watch"
"$TEST_DIR/test-secure-input-watch"
