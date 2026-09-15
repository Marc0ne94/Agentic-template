#!/usr/bin/env bash
# Black-box regression tests. Only sandboxed command stubs reach setup_check.sh;
# no SDK downloads, host configuration changes, or real device queries occur.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP_SCRIPT="${SETUP_CHECK_SCRIPT:-$REPO_ROOT/.agents/skills/setup-repo/scripts/setup_check.sh}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/agentic-setup-test.XXXXXXXX")"
TEST_ROOT="$(cd "$TEST_ROOT" && pwd)"

cleanup() {
  # Resolve and constrain the recursive-delete target to this test's temp root.
  local resolved
  resolved="$(cd "$TEST_ROOT" && pwd)" || return
  if [[ "$resolved" = "$TEST_ROOT" && "$resolved" = /*/agentic-setup-test.* ]]; then
    rm -rf -- "$resolved"
  fi
}
trap cleanup EXIT

STUB_BIN="$TEST_ROOT/bin"
mkdir -p "$STUB_BIN"

# Keep only the POSIX utilities used by the inspector; SDK/toolchain discovery
# must not fall through to whatever happens to be installed on the test host.
for utility in dirname grep head mkdir; do
  printf '#!/bin/bash\nexec %q "$@"\n' "$(command -v "$utility")" > "$STUB_BIN/$utility"
done
printf '#!/bin/bash\n[[ "$SCENARIO" != hook_chmod_failure ]] || exit 1\nexec %q "$@"\n' \
  "$(command -v chmod)" > "$STUB_BIN/chmod"

cat > "$STUB_BIN/uname" <<'STUB'
#!/bin/bash
if [[ "$1" == -m ]]; then
  echo x86_64
elif [[ "$SCENARIO" == linux_web_only ]]; then
  echo Linux
elif [[ "$SCENARIO" == macos_* ]]; then
  echo Darwin
else
  echo MINGW64_NT
fi
STUB

cat > "$STUB_BIN/git" <<'STUB'
#!/bin/bash
case "$*" in
  'rev-parse --show-toplevel') echo "$FIXTURE_ROOT" ;;
  '--version') echo 'git version 2.50.0' ;;
  'rev-parse --is-inside-work-tree') echo true ;;
  'rev-parse --abbrev-ref HEAD') echo fixture ;;
  'config --get core.hooksPath')
    [[ "$SCENARIO" != hook_* ]] || exit 1
    echo .githooks ;;
  'config core.hooksPath .githooks')
    [[ "$SCENARIO" != hook_config_failure ]] || exit 1 ;;
  *) echo "Unexpected git arguments: $*" >&2; exit 99 ;;
esac
STUB

cat > "$STUB_BIN/flutter" <<'STUB'
#!/bin/bash
case "$*" in
  '--version')
    [[ "$SCENARIO" != flutter_broken ]] || { echo 'SDK startup failed' >&2; exit 1; }
    echo 'Flutter 3.44.0'; echo 'Framework fixture' ;;
  'doctor -v')
    if [[ "$SCENARIO" == config_failure || "$SCENARIO" == config_success ]]; then
      echo '    • Feature flags: enable-windows-desktop'
    elif [[ "$SCENARIO" == macos_no_runner ]]; then
      echo '    • Feature flags: enable-macos-desktop'
    elif [[ "$SCENARIO" == native_only || "$SCENARIO" == windows_without_toolchain ]]; then
      echo '    • Feature flags: enable-windows-desktop'
    else
      echo '    • Feature flags: enable-web, enable-linux-desktop, enable-windows-desktop'
    fi
    if [[ "$SCENARIO" == native_only ]]; then
      echo '[✓] Visual Studio - develop Windows apps (Visual Studio 2022 17.14)'
      echo '[!] Android toolchain - develop for Android devices'
      exit 1 # An unrelated doctor issue must not invalidate a healthy runner.
    fi
    echo '[X] Visual Studio - develop Windows apps'
    ;;
  devices)
    echo '1 connected device:'
    echo '  Fixture phone (mobile) • fixture-private-device-id • android-arm64 • Android 16'
    ;;
  'config --enable-web')
    [[ "$SCENARIO" != config_failure ]] || { echo 'Config write failed' >&2; exit 1; } ;;
  'pub get')
    [[ "$SCENARIO" != pub_failure ]] || { echo 'Dependency resolution failed' >&2; exit 65; }
    if [[ "$SCENARIO" != pub_no_config ]]; then
      mkdir -p "$FIXTURE_ROOT/.dart_tool"
      echo '{"configVersion":2,"packages":[]}' > "$FIXTURE_ROOT/.dart_tool/package_config.json"
    fi
    ;;
  test) [[ "$SCENARIO" != verify_test_failure ]] ;;
  *) echo "Unexpected flutter arguments: $*" >&2; exit 99 ;;
esac
STUB

cat > "$STUB_BIN/dart" <<'STUB'
#!/bin/bash
case "$*" in
  --version)
    [[ "$SCENARIO" != dart_broken ]] || { echo 'Dart startup failed' >&2; exit 1; }
    echo 'Dart SDK version: 3.13.2 (stable)' ;;
  'run tool/verify_fsd.dart --strict') [[ "$SCENARIO" != verify_audit_failure ]] ;;
  *) echo "Unexpected dart arguments: $*" >&2; exit 99 ;;
esac
STUB

# cl alone does not prove that Visual Studio has Flutter's required components.
printf '#!/bin/bash\nexit 0\n' > "$STUB_BIN/cl"
printf '#!/bin/bash\nexit 0\n' > "$STUB_BIN/xcodebuild"
chmod +x "$STUB_BIN/"*

PASSED=0
FAILED=0
run_case() {
  local scenario="$1" expected="$2"
  shift 2
  local fixture="$TEST_ROOT/$scenario" output status=0
  mkdir -p "$fixture/.githooks"
  printf 'name: setup_fixture\n' > "$fixture/pubspec.yaml"
  if [[ "$scenario" != hook_missing_file ]]; then
    printf '#!/bin/bash\nexit 0\n' > "$fixture/.githooks/pre-commit"
    chmod +x "$fixture/.githooks/pre-commit"
  fi
  case "$scenario" in
    pub_failure|pub_no_config|pub_success|unresolved_packages) ;;
    *)
      mkdir -p "$fixture/.dart_tool"
      echo '{"configVersion":2,"packages":[]}' > "$fixture/.dart_tool/package_config.json"
      ;;
  esac

  output="$(cd "$fixture" && PATH="$STUB_BIN" CHROME_EXECUTABLE='' \
    FIXTURE_ROOT="$fixture" SCENARIO="$scenario" "$BASH" "$SETUP_SCRIPT" "$@" 2>&1)" || status=$?

  if { [[ "$expected" == pass && "$status" == 0 ]] &&
       [[ "$output" == *'SUCCESS: Minimal development environment criteria MET!'* ]]; } ||
     { [[ "$expected" == fail && "$status" != 0 ]] &&
       [[ "$output" != *'SUCCESS:'* && "$output" != *'All requirements satisfied!'* ]]; } ||
     { [[ "$expected" == verify_fail && "$status" != 0 ]] &&
       [[ "$output" == *'Found 1 issue(s) to resolve!'* && "$output" != *'All requirements satisfied!'* ]]; }; then
    if [[ "$output" == *'fixture-private-device-id'* ]]; then
      echo "FAIL $scenario: inspector exposed a connected device identifier"
      FAILED=$((FAILED + 1))
      return
    fi
    echo "PASS $scenario"
    PASSED=$((PASSED + 1))
  else
    echo "FAIL $scenario: expected $expected, exit=$status"
    printf '%s\n' "$output"
    FAILED=$((FAILED + 1))
  fi
}

run_case pub_failure fail --fix
run_case pub_no_config fail --fix
run_case flutter_broken fail
run_case dart_broken fail
run_case hook_config_failure fail --fix
run_case hook_chmod_failure fail --fix
run_case hook_missing_file fail --fix
run_case config_failure fail --fix
run_case unresolved_packages fail
run_case windows_without_toolchain fail
run_case linux_web_only pass
run_case native_only pass
run_case config_success pass --fix
run_case pub_success pass --fix
run_case web_only pass
run_case macos_no_runner fail
run_case macos_web_only pass --fix
run_case verify_audit_failure verify_fail --verify
run_case verify_test_failure verify_fail --verify
run_case verify_success pass --verify

echo "$PASSED passed; $FAILED failed"
[[ "$FAILED" == 0 ]]
