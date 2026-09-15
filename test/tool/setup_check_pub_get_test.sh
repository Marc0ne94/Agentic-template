#!/usr/bin/env bash
# Exercise the real setup script without invoking installed SDKs or changing Git configuration.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP_SCRIPT="$REPO_ROOT/.agents/skills/setup-repo/scripts/setup_check.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/setup-pub-get-test.XXXXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd)"
cleanup() {
  local resolved
  resolved="$(cd "$TEST_ROOT" && pwd)" || return
  if [[ "$resolved" == "$TEST_ROOT" && "$resolved" == /*/setup-pub-get-test.* ]]; then
    rm -rf -- "$resolved"
  fi
}
trap cleanup EXIT

# The child shell receives only these utilities and the exported fake tools.
mkdir -p "$TEST_ROOT/bin"
for utility in grep head; do
  printf '#!/bin/bash\nexec %q "$@"\n' "$(command -v "$utility")" > "$TEST_ROOT/bin/$utility"
done
chmod +x "$TEST_ROOT/bin/"*

git() {
  case "$*" in
    'rev-parse --show-toplevel') echo "$FIXTURE_ROOT" ;;
    '--version') echo 'git version 2.50.0' ;;
    'rev-parse --is-inside-work-tree') echo true ;;
    'rev-parse --abbrev-ref HEAD') echo fixture ;;
    'config --get core.hooksPath') echo .githooks ;;
    *) echo "Unexpected git arguments: $*" >&2; return 99 ;;
  esac
}
flutter() {
  case "$*" in
    '--version') echo 'Flutter SDK fixture' ;;
    'doctor -v') echo '    Feature flags: enable-web' ;;
    devices) echo 'No devices found.' ;;
    'pub get')
      [[ "$PUB_GET_EXIT" == 0 ]] || echo 'Fixture dependency resolution failed.' >&2
      return "$PUB_GET_EXIT"
      ;;
    *) echo "Unexpected flutter arguments: $*" >&2; return 99 ;;
  esac
}
dart() {
  [[ "$*" == --version ]] || return 99
  echo 'Dart SDK fixture'
}
uname() {
  case "$*" in
    -s) echo Darwin ;;
    -m) echo x86_64 ;;
    *) return 99 ;;
  esac
}
export -f git flutter dart uname

for pub_get_exit in 0 65; do
  fixture="$TEST_ROOT/pub-get-$pub_get_exit"
  mkdir -p "$fixture/.githooks"
  echo 'name: setup_fixture' > "$fixture/pubspec.yaml"
  printf '#!/bin/bash\nexit 0\n' > "$fixture/.githooks/pre-commit"
  chmod +x "$fixture/.githooks/pre-commit"
  status=0
  output="$(cd "$fixture" && PATH="$TEST_ROOT/bin" CHROME_EXECUTABLE='' \
    FIXTURE_ROOT="$fixture" PUB_GET_EXIT="$pub_get_exit" \
    "$BASH" "$SETUP_SCRIPT" --fix 2>&1)" || status=$?

  if [[ "$pub_get_exit" == 65 && "$status" == 1 &&
        "$output" == *'Fixture dependency resolution failed.'* &&
        "$output" != *"'flutter pub get' completed."* && "$output" != *'SUCCESS:'* &&
        "$output" != *'All requirements satisfied!'* ]] ||
     [[ "$pub_get_exit" == 0 && "$status" == 0 &&
        "$output" == *"'flutter pub get' completed."* && "$output" == *'All requirements satisfied!'* ]]; then
    echo "PASS: pub get exit=$pub_get_exit, setup exit=$status"
  else
    echo "FAIL: pub get exit=$pub_get_exit, setup exit=$status"
    printf '%s\n' "$output"
    exit 1
  fi
done

echo '2 passed; 0 failed'
