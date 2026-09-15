#!/usr/bin/env bash
# ==============================================================================
# setup_check.sh
# Environment inspector & setup validator for the Agentic Flutter Template.
# Checks: OS, Git, Flutter SDK, Dart SDK, Native Desktop Toolchains, Web Runner,
# Flutter Configurations, and Project Dependencies.
# ==============================================================================

set -uo pipefail

# ANSI Color Codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

DIR="$(git rev-parse --show-toplevel 2>/dev/null || (cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd))"
cd "$DIR" || exit 1

AUTO_FIX=false
RUN_VERIFY=false

for arg in "$@"; do
  case "$arg" in
    --fix)
      AUTO_FIX=true
      ;;
    --verify)
      RUN_VERIFY=true
      ;;
    -h|--help)
      echo -e "${BOLD}Usage:${NC} $0 [options]"
      echo ""
      echo "Options:"
      echo "  --fix     Automatically enable missing Flutter platform flags and run 'flutter pub get'"
      echo "  --verify  Run FSD architectural audit and test suite after checks"
      echo "  --help    Show this help message"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown argument:${NC} $arg"
      echo "Use --help for usage."
      exit 1
      ;;
  esac
done

echo -e "${BOLD}${BLUE}======================================================${NC}"
echo -e "${BOLD}${BLUE} 🚀 Agentic Template Environment & Prerequisites Check${NC}"
echo -e "${BOLD}${BLUE}======================================================${NC}"
echo "Repository Root: $DIR"
echo ""

TOTAL_ERRORS=0
TOTAL_WARNINGS=0

pass() {
  echo -e "  [${GREEN}✓ PASS${NC}] $1"
}

warn() {
  echo -e "  [${YELLOW}! WARN${NC}] $1"
  TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
}

fail() {
  echo -e "  [${RED}✗ FAIL${NC}] $1"
  TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
}

info() {
  echo -e "  ${CYAN}•${NC} $1"
}

# ------------------------------------------------------------------------------
# 1. OS & Architecture Detection
# ------------------------------------------------------------------------------
echo -e "${BOLD}1. Operating System & Machine Architecture${NC}"
OS_TYPE="$(uname -s)"
ARCH="$(uname -m)"
info "Kernel / OS: $OS_TYPE"
info "Architecture: $ARCH"

IS_LINUX=false
IS_MACOS=false
IS_WINDOWS=false
IS_WSL=false

case "$OS_TYPE" in
  Linux*)
    IS_LINUX=true
    if grep -qi microsoft /proc/version 2>/dev/null; then
      IS_WSL=true
      info "Environment: WSL (Windows Subsystem for Linux)"
    else
      info "Environment: Native Linux"
    fi
    ;;
  Darwin*)
    IS_MACOS=true
    info "Environment: macOS"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    IS_WINDOWS=true
    info "Environment: Windows (POSIX Shell)"
    ;;
  *)
    warn "Unrecognized operating system: $OS_TYPE"
    ;;
esac
pass "Host operating system detected successfully."
echo ""

# ------------------------------------------------------------------------------
# 2. Git & Repository Status
# ------------------------------------------------------------------------------
echo -e "${BOLD}2. Git & Version Control${NC}"
if command -v git >/dev/null 2>&1; then
  GIT_VER="$(git --version)"
  pass "Git installed: $GIT_VER"
  
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")"
    info "Active branch: $CURRENT_BRANCH"
    pass "Inside valid git repository."

    # Check pre-commit hook
    HOOKS_PATH="$(git config --get core.hooksPath || true)"
    if [ "$HOOKS_PATH" = ".githooks" ] && [ -x "$DIR/.githooks/pre-commit" ]; then
      pass "Git pre-commit hook is active (enforcing FSD & AST analysis)."
    elif [ -x "$DIR/.git/hooks/pre-commit" ]; then
      pass "Git pre-commit hook is active in .git/hooks/pre-commit."
    else
      warn "Git pre-commit hook is NOT configured."
      if [ "$AUTO_FIX" = true ]; then
        info "Configuring Git hooks path to .githooks..."
        if [ -f "$DIR/.githooks/pre-commit" ] &&
           git config core.hooksPath .githooks &&
           chmod +x "$DIR/.githooks/pre-commit" &&
           [ -x "$DIR/.githooks/pre-commit" ]; then
          pass "Git pre-commit hook activated."
        else
          fail "Could not activate Git pre-commit hook. Check .githooks/pre-commit and repository permissions."
        fi
      else
        info "Run to activate hook: git config core.hooksPath .githooks"
      fi
    fi
  else
    fail "Directory is not a valid git repository."
  fi
else
  fail "Git is not installed or not available in PATH."
fi
echo ""

# ------------------------------------------------------------------------------
# 3. Flutter & Dart SDK
# ------------------------------------------------------------------------------
echo -e "${BOLD}3. Flutter & Dart SDK${NC}"
FLUTTER_OK=false
DART_OK=false
DOCTOR_OUTPUT=""
if command -v flutter >/dev/null 2>&1; then
  FLUTTER_PATH="$(command -v flutter)"
  if FLUTTER_VER="$(flutter --version 2>&1)"; then
    pass "Flutter installed: ${FLUTTER_VER%%$'\n'*}"
    info "Flutter path: $FLUTTER_PATH"
    FLUTTER_OK=true
    # Doctor may report unrelated Android/iOS issues. Inspect each relevant
    # section below instead of treating its aggregate exit status as readiness.
    DOCTOR_OUTPUT="$(flutter doctor -v 2>&1)" || true
  else
    fail "Flutter SDK was found but 'flutter --version' failed."
  fi
else
  fail "Flutter SDK not found in PATH. Install Flutter: https://docs.flutter.dev/get-started/install"
fi

if command -v dart >/dev/null 2>&1; then
  if DART_VER="$(dart --version 2>&1)"; then
    pass "Dart installed: $DART_VER"
    DART_OK=true
  else
    fail "Dart SDK was found but 'dart --version' failed."
  fi
else
  fail "Dart SDK not found in PATH."
fi
echo ""

# ------------------------------------------------------------------------------
# 4. Native Desktop Development Toolchains
# ------------------------------------------------------------------------------
echo -e "${BOLD}4. Native Desktop Development Dependencies${NC}"
NATIVE_DESKTOP_READY=false

if [ "$IS_LINUX" = true ]; then
  info "Checking Linux Desktop requirements (clang, cmake, ninja, pkg-config, libgtk-3-dev)..."
  LINUX_TOOLS_OK=true
  MISSING_LINUX_PKGS=()

  if command -v clang >/dev/null 2>&1 || command -v gcc >/dev/null 2>&1; then
    COMPILER="$(command -v clang || command -v gcc)"
    pass "C++ Compiler: $COMPILER"
  else
    warn "C++ Compiler (clang or gcc) not found (needed for Linux Desktop)."
    LINUX_TOOLS_OK=false
    MISSING_LINUX_PKGS+=("clang")
  fi

  if command -v cmake >/dev/null 2>&1; then
    CMAKE_VER="$(cmake --version | head -n 1)"
    pass "CMake: $CMAKE_VER"
  else
    warn "CMake is not installed (needed for Linux Desktop)."
    LINUX_TOOLS_OK=false
    MISSING_LINUX_PKGS+=("cmake")
  fi

  if command -v ninja >/dev/null 2>&1 || command -v ninja-build >/dev/null 2>&1; then
    NINJA_CMD="$(command -v ninja || command -v ninja-build)"
    pass "Ninja build tool: $NINJA_CMD"
  else
    warn "Ninja is not installed (needed for Linux Desktop)."
    LINUX_TOOLS_OK=false
    MISSING_LINUX_PKGS+=("ninja-build")
  fi

  if command -v pkg-config >/dev/null 2>&1; then
    pass "pkg-config installed."
    if pkg-config --exists gtk+-3.0 >/dev/null 2>&1; then
      GTK_VER="$(pkg-config --modversion gtk+-3.0)"
      pass "GTK 3 headers found: version $GTK_VER"
    else
      warn "GTK 3 development headers (libgtk-3-dev) missing (needed for Linux Desktop)."
      LINUX_TOOLS_OK=false
      MISSING_LINUX_PKGS+=("libgtk-3-dev")
    fi
  else
    warn "pkg-config is not installed (needed for Linux Desktop)."
    LINUX_TOOLS_OK=false
    MISSING_LINUX_PKGS+=("pkg-config" "libgtk-3-dev")
  fi

  if [ "$LINUX_TOOLS_OK" = true ]; then
    NATIVE_DESKTOP_READY=true
    pass "Linux Desktop toolchain is fully ready!"
  else
    warn "Linux Desktop dependencies incomplete; Web can still satisfy the minimal environment."
    if [ -f /etc/debian_version ]; then
      info "Suggested fix for Debian/Ubuntu:"
      info "  sudo apt update && sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev"
    elif [ -f /etc/fedora-release ]; then
      info "Suggested fix for Fedora:"
      info "  sudo dnf install -y clang cmake ninja-build pkgconf-pkg-config gtk3-devel xz-devel"
    elif [ -f /etc/arch-release ]; then
      info "Suggested fix for Arch Linux:"
      info "  sudo pacman -Syu --needed clang cmake ninja pkgconf gtk3"
    fi
  fi
elif [ "$IS_WINDOWS" = true ]; then
  info "Checking Windows Desktop requirements (Visual Studio C++ build tools)..."
  if printf '%s\n' "$DOCTOR_OUTPUT" | grep -Eq '^[[:space:]]*\[(✓|√)\] Visual Studio - develop Windows apps'; then
    pass "Visual Studio toolchain verified by Flutter doctor."
    NATIVE_DESKTOP_READY=true
  else
    warn "Flutter doctor did not confirm a complete Visual Studio C++ toolchain."
    info "To install on Windows: winget install Microsoft.VisualStudio.2022.BuildTools --override \"--passive --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended\""
  fi
elif [ "$IS_MACOS" = true ]; then
  if [ ! -d "$DIR/macos" ]; then
    warn "This project has no macOS desktop runner; use Web on this host."
  elif command -v xcodebuild >/dev/null 2>&1; then
    pass "Xcode detected for macOS desktop."
    NATIVE_DESKTOP_READY=true
  else
    warn "Xcode not installed."
  fi
fi
echo ""

# ------------------------------------------------------------------------------
# 5. Web Development Toolchains
# ------------------------------------------------------------------------------
echo -e "${BOLD}5. Web Development Dependencies${NC}"
WEB_READY=false
CHROME_BIN=""

if [ -n "${CHROME_EXECUTABLE:-}" ] && [ -x "$CHROME_EXECUTABLE" ]; then
  CHROME_BIN="$CHROME_EXECUTABLE"
elif command -v google-chrome >/dev/null 2>&1; then
  CHROME_BIN="$(command -v google-chrome)"
elif command -v google-chrome-stable >/dev/null 2>&1; then
  CHROME_BIN="$(command -v google-chrome-stable)"
elif command -v chromium >/dev/null 2>&1; then
  CHROME_BIN="$(command -v chromium)"
elif command -v chromium-browser >/dev/null 2>&1; then
  CHROME_BIN="$(command -v chromium-browser)"
fi

if [ -n "$CHROME_BIN" ]; then
  pass "Chrome/Chromium detected: $CHROME_BIN"
  WEB_READY=true
else
  warn "Google Chrome / Chromium not found in standard paths."
  info "You can still run web via local web server: 'flutter run -d web-server'"
  info "Or export CHROME_EXECUTABLE=/path/to/chrome"
  # web-server is always built into Flutter Web
  if [ "$FLUTTER_OK" = true ]; then
    WEB_READY=true
  fi
fi

if command -v gzip >/dev/null 2>&1; then
  pass "gzip utility found (used for optimized WASM-GC web releases in build_web.sh)."
else
  warn "gzip not found; production build_web.sh static pre-compression will be skipped."
fi
echo ""

# ------------------------------------------------------------------------------
# 6. Flutter Platform Configuration
# ------------------------------------------------------------------------------
echo -e "${BOLD}6. Flutter Platform Configuration & Target Devices${NC}"
NATIVE_PLATFORM_ENABLED=false
WEB_PLATFORM_ENABLED=false
if [ "$FLUTTER_OK" = true ]; then
  DOCTOR_FLAGS="$(printf '%s\n' "$DOCTOR_OUTPUT" | grep -i 'Feature flags:' || true)"
  if ! DEVICES_OUTPUT="$(flutter devices 2>&1)"; then
    warn "Could not query Flutter target devices; checking platform flags only."
    DEVICES_OUTPUT=""
  fi
  
  check_platform_enabled() {
    local platform_name="$1"
    local flag_name="$2"
    local enable_cmd="$3"
    local device_id="$4"

    if printf '%s\n' "$DOCTOR_FLAGS" | grep -Eq "(^|[[:space:],:])$flag_name([[:space:],]|$)" ||
       printf '%s\n' "$DEVICES_OUTPUT" | grep -Eq "•[[:space:]]*$device_id[[:space:]]*•"; then
      pass "$platform_name support is enabled."
      return 0
    else
      warn "$platform_name is NOT enabled or device runner missing."
      if [ "$AUTO_FIX" = true ]; then
        info "Enabling $flag_name..."
        if flutter config "$enable_cmd"; then
          pass "$flag_name enabled successfully."
          return 0
        else
          fail "Could not enable $flag_name."
        fi
      else
        info "Run to enable: flutter config $enable_cmd"
      fi
      return 1
    fi
  }

  if [ "$IS_LINUX" = true ]; then
    if check_platform_enabled "Linux Desktop" "enable-linux-desktop" "--enable-linux-desktop" "linux"; then
      NATIVE_PLATFORM_ENABLED=true
    fi
  fi
  if [ "$IS_WINDOWS" = true ]; then
    if check_platform_enabled "Windows Desktop" "enable-windows-desktop" "--enable-windows-desktop" "windows"; then
      NATIVE_PLATFORM_ENABLED=true
    fi
  fi
  if [ "$IS_MACOS" = true ] && [ -d "$DIR/macos" ]; then
    if check_platform_enabled "macOS Desktop" "enable-macos-desktop" "--enable-macos-desktop" "macos"; then
      NATIVE_PLATFORM_ENABLED=true
    fi
  fi
  if check_platform_enabled "Web" "enable-web" "--enable-web" "chrome"; then
    WEB_PLATFORM_ENABLED=true
  fi

  info "Target availability checked; connected device identifiers are omitted."
else
  fail "Cannot inspect Flutter config because Flutter is not available."
fi
echo ""

# ------------------------------------------------------------------------------
# 7. Project Dart Dependencies
# ------------------------------------------------------------------------------
echo -e "${BOLD}7. Project Dependencies (Pub Packages)${NC}"
DEPENDENCIES_READY=false
if [ -f "$DIR/pubspec.yaml" ]; then
  pass "pubspec.yaml present."
  
  if [ -f "$DIR/.dart_tool/package_config.json" ]; then
    pass "Package configuration (.dart_tool/package_config.json) exists."
    DEPENDENCIES_READY=true
  else
    warn "Dependencies not resolved yet (.dart_tool/package_config.json missing)."
    if [ "$AUTO_FIX" = true ] && [ "$FLUTTER_OK" = true ]; then
      info "Running 'flutter pub get'..."
      if flutter pub get; then
        if [ -f "$DIR/.dart_tool/package_config.json" ]; then
          pass "'flutter pub get' completed and generated package configuration."
          DEPENDENCIES_READY=true
        else
          fail "'flutter pub get' returned success but package configuration is missing."
        fi
      else
        fail "'flutter pub get' failed; project dependencies are not ready."
      fi
    else
      info "Run: flutter pub get"
    fi
  fi
else
  fail "pubspec.yaml not found at $DIR"
fi
echo ""

# ------------------------------------------------------------------------------
# 8. Minimal Development Environment Assessment
# ------------------------------------------------------------------------------
echo -e "${BOLD}8. Minimal Development Environment Assessment${NC}"
echo -e "   ${CYAN}Rule:${NC} The app features an In-App Device Simulator supporting:"
echo -e "   ⌚ Watch (Wear OS 220×220) | 📱 Smartphone (390×780) | 📖 Foldable (720×760) | 🖥️ Desktop (1280×800)"
echo -e "   Therefore, having EITHER Native Desktop OR Web is sufficient to develop and preview all tiers!"
echo ""

MINIMAL_ENV_SATISFIED=false
if [ "$FLUTTER_OK" = true ] && [ "$DART_OK" = true ] &&
   [ "$DEPENDENCIES_READY" = true ] && [ "$TOTAL_ERRORS" -eq 0 ]; then
  if [ "$NATIVE_DESKTOP_READY" = true ] && [ "$NATIVE_PLATFORM_ENABLED" = true ]; then
    pass "Native Desktop prerequisites are ready for the host platform."
    MINIMAL_ENV_SATISFIED=true
  fi

  if [ "$WEB_READY" = true ] && [ "$WEB_PLATFORM_ENABLED" = true ]; then
    pass "Web prerequisites are ready. Run: 'flutter run -d web-server' (or -d chrome if installed)."
    MINIMAL_ENV_SATISFIED=true
  fi
fi

if [ "$MINIMAL_ENV_SATISFIED" = true ]; then
  echo ""
  echo -e "${GREEN}${BOLD}✓ SUCCESS: Minimal development environment criteria MET!${NC}"
  echo -e "Prerequisite checks passed. Launch the app to verify the runner and in-app device switcher."
else
  echo ""
  echo -e "${RED}${BOLD}✗ FAILED: Minimal development environment criteria NOT MET.${NC}"
  echo -e "Resolve the reported errors, check Flutter/Dart and project packages, and enable Web or a complete host desktop toolchain."
  TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
fi
echo ""

# ------------------------------------------------------------------------------
# 9. Optional Verification Suite (--verify)
# ------------------------------------------------------------------------------
if [ "$RUN_VERIFY" = true ]; then
  echo -e "${BOLD}9. Architecture & Test Verification Suite${NC}"
  if [ "$FLUTTER_OK" = true ] && [ "$DART_OK" = true ] && [ "$DEPENDENCIES_READY" = true ]; then
    info "Running FSD v2.1 architectural audit..."
    if dart run tool/verify_fsd.dart --strict; then
      pass "FSD architecture audit passed with 0 violations!"
    else
      fail "FSD architecture audit failed."
    fi

    info "Running Flutter test suite..."
    if flutter test; then
      pass "All Flutter unit and widget tests passed!"
    else
      fail "Flutter tests failed."
    fi
  else
    fail "Cannot run verification suite: Flutter/Dart or project dependencies unavailable."
  fi
  echo ""
fi

# ------------------------------------------------------------------------------
# Summary & Exit Code
# ------------------------------------------------------------------------------
echo -e "${BOLD}======================================================${NC}"
if [ "$TOTAL_ERRORS" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}Environment Check Complete: All requirements satisfied! (Warnings: $TOTAL_WARNINGS)${NC}"
  exit 0
else
  echo -e "${RED}${BOLD}Environment Check Complete: Found $TOTAL_ERRORS issue(s) to resolve! (Warnings: $TOTAL_WARNINGS)${NC}"
  exit 1
fi
