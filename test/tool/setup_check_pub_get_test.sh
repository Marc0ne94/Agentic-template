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
for utility in grep head mkdir; do
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
      if [[ "$PUB_GET_EXIT" != 0 ]]; then
        echo 'Fixture dependency resolution failed.' >&2
        return "$PUB_GET_EXIT"
      fi
      mkdir -p "$FIXTURE_ROOT/.dart_tool"
      echo '{"configVersion":2,"packages":[]}' > "$FIXTURE_ROOT/.dart_tool/package_config.json"
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
xcodebuild() { return 0; }
export -f git flutter dart uname xcodebuild

failures=0
for pub_get_exit in 65 0; do
  fixture="$TEST_ROOT/pub-get-$pub_get_exit"
  mkdir -p "$fixture/.githooks"
  echo 'name: setup_fixture' > "$fixture/pubspec.yaml"
  printf '#!/bin/bash\nexit 0\n' > "$fixture/.githooks/pre-commit"
  chmod +x "$fixture/.githooks/pre-commit"
  status=0
  output="$(cd "$fixture" && PATH="$TEST_ROOT/bin" CHROME_EXECUTABLE='' \
    FIXTURE_ROOT="$fixture" PUB_GET_EXIT="$pub_get_exit" \
    "$BASH" "$SETUP_SCRIPT" --fix 2>&1)" || status=$?

  if [[ "$pub_get_exit" == 65 ]]; then
    if [[ "$status" == 1 && "$output" == *'Fixture dependency resolution failed.'* &&
          "$output" != *"'flutter pub get' completed."* && "$output" != *'SUCCESS:'* &&
          "$output" != *'All requirements satisfied!'* ]] &&
       [[ ! -f "$fixture/.dart_tool/package_config.json" ]]; then
      echo 'PASS: failed pub get rejects setup without reporting success'
      continue
    fi
  elif [[ "$status" == 0 && "$output" == *"'flutter pub get' completed."* &&
          "$output" == *'All requirements satisfied!'* ]] &&
       [[ -f "$fixture/.dart_tool/package_config.json" ]]; then
    echo 'PASS: successful pub get preserves successful setup'
    continue
  fi
  echo "FAIL: pub get exit=$pub_get_exit, setup exit=$status"
  printf '%s\n' "$output"
  failures=$((failures + 1))
done

echo "$((2 - failures)) passed; $failures failed"
[[ "$failures" == 0 ]]
