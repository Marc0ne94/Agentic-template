# Agentic Template for Flutter

A clean, modular Flutter template designed from first principles for **AI agentic pair-programming** and modern multi-device applications, based on architectural patterns from [Pin](https://github.com/cris92bb/Pin).

It follows **Feature-Sliced Design (FSD v2.1)**, checked automatically by an import scanner and tests, and ships responsive layouts for:
- ⌚ **Wearable**: circular watch displays with safe insets and a glanceable UI
- 📱 **Smartphone (Android, iOS)**: single-column layout with bottom navigation and 44×44 touch targets
- 📖 **Foldable / Tablet**: dual-pane layout, split along the hinge when the device reports one
- 🌐 **Web**: WASM-GC build script and PWA manifest
- 🖥️ **Desktop (Windows, macOS, Linux)**: navigation rail and keyboard shortcuts; on Linux a native GTK runner with theme sync, a window-control channel and a `.desktop` launcher

What's new in 2.0: see [CHANGELOG.md](CHANGELOG.md).

---

## 🚀 Quick Start

### 1. Check Environment & Prerequisites
Audit host OS, Git, Flutter/Dart SDKs, desktop/web build toolchains, and packages:
```bash
bash .agents/skills/setup-repo/scripts/setup_check.sh

# Or auto-enable missing platform flags and fetch packages:
bash .agents/skills/setup-repo/scripts/setup_check.sh --fix
```

### 2. Run the App
```bash
flutter pub get
flutter run -d windows   # or: -d macos, -d linux, -d chrome, an Android or iOS device
```

### 3. Verify Architecture & Tests
```bash
# FSD import audit (exits with an error on violations)
dart run tool/verify_fsd.dart --strict

# Toolchain baseline check against toolchain.json
dart run tool/verify_toolchain.dart --strict

# Static analysis and the full test suite
flutter analyze
flutter test
```
CI runs the same checks on every push to `main` and on pull requests (`.github/workflows/ci.yml`).

A git hooks suite is included in `.githooks/` (`pre-commit` prevents committing code on FSD, AST, test or toolchain baseline failure; `pre-push` blocks direct pushes to `develop` and `main`, requiring Pull Requests):
```bash
git config core.hooksPath .githooks
```

### 4. Build Production Releases
```bash
# Windows desktop bundle (Windows host)
flutter build windows --release

# macOS app and iOS archive (macOS host with Xcode)
flutter build macos --release
flutter build ipa --release

# Android App Bundle
flutter build appbundle --release

# Linux desktop bundle (Linux host)
bash build_release.sh linux

# Optimized Web bundle (WASM-GC + gzip)
bash build_release.sh web
```

### 5. Linux Launcher (optional)
```bash
bash install_desktop_entry.sh
```
Installs `app.desktop` and the app icon for the current user, pointing at this checkout's `launch_app.sh`.

---

## 🏛️ Architecture: Feature-Sliced Design (FSD v2.1)

The codebase is organized into strict hierarchical layers:

```
lib/
├── app/          # Application root, theme definitions, scroll behaviors
├── pages/        # Full-screen views / route targets
│   └── home/     # Adaptive Home orchestrator, tier views, Slices & Settings
├── widgets/      # Composite UI blocks orchestrating features & entities
├── features/     # Discrete user action slices (theme toggle, device simulator, actions)
├── entities/     # Domain business models and state (app settings)
└── shared/       # Tokens, palette, primitives, breakpoints, storage, platform services
```

### Unidirectional Import Hierarchy
$$\text{app} \succ \text{pages} \succ \text{widgets} \succ \text{features} \succ \text{entities} \succ \text{shared}$$

- Code in any layer can **only** import from layers strictly below it.
- Slices in the same layer (e.g., two `features` or two `entities`) **never** import each other directly.
- Code outside a slice imports it **only** through its public barrel (`<slice>/<slice>.dart`). `app` and `shared` are split into segments instead of slices; `shared` is consumed through `shared/shared.dart`.

All three rules are enforced by `tool/verify_fsd.dart` (a line-based scan of `import` and `export` directives) and by `test/architecture/fsd_architecture_test.dart`.

---

## 🖥️ In-App Device Simulator

Use the device picker in the desktop header, the phone app bar or **Settings** to preview every tier:
1. **Auto Detect**: follows the real window/screen size.
2. **Watch (Wear OS) 220×220**: round frame with safe circular insets; the picker stays next to the frame.
3. **Smartphone 390×780**: portrait phone viewport.
4. **Foldable (Unfolded) 720×760**: dual-pane surface.
5. **Desktop / Web**: the real window, or a scaled 1280×800 preview when the window is narrower than 1024px.

The frame reports its inner viewport (bezel excluded) to layouts and scales down when the window is smaller than the simulated device.

---

## ⚙️ Settings & Shortcuts

- **Theme**: System, Light or Dark. The round header button cycles through the three modes.
- **High contrast**: stronger text, border and accent colors; also applied when the operating system requests high contrast.
- Preferences persist across restarts through `shared_preferences`.
- **Ctrl + 1 / 2 / 3** (⌘ on macOS) switch between Overview, Slices and Settings.

---

## 🎨 Design System

Raw values live in `AppTokens`; widgets read color roles from the `AppPalette` theme extension, which has light, dark and high-contrast variants:

```dart
final palette = AppPalette.of(context);
Text('Title', style: TextStyle(color: palette.textPrimary));
```

See [docs/design_system.md](docs/design_system.md) and [.agents/rules/design-system.md](.agents/rules/design-system.md).

---

## 🏛️ Code Quality, Architecture & Design Tokens

This repository adheres to strict code quality and architectural guidelines:

- **Feature-Sliced Design (FSD v2.1)**: Strictly unidirectional dependencies (`app` → `pages` → `widgets` → `features` → `entities` → `shared`) with zero cross-slice coupling and public barrel encapsulation. Verify with `dart run tool/verify_fsd.dart --strict`.
- **File Sizing & Modularity (<= 300 LOC)**: All Dart source files must remain under 300 lines of code. Monolithic views and compound builders are broken down into clean, modular sub-components in dedicated `components/` or `views/` subdirectories.
- **Doctype & Documentation Comments**: Every component, class, method, and state provider is documented with descriptive Dart doc comments (`///`) providing role descriptions, architectural context, and parameter specifications.
- **Design Token Consistency & Zero Hardcoded Colors**: No hardcoded `Color(0x...)` or random hex literals in UI files. All visual styles, borders, radii, and shadows reference `AppTokens`, `AppPalette.of(context)`, or `Theme.of(context)`.
- **Modern Riverpod 3 State Management**: Employs Riverpod 3 `Notifier` and `NotifierProvider` primitives across feature controllers and domain entities with fallback state access for isolated unit testing.
- **Branching & Pull Request Policy**: Direct pushes to `develop` and `main` are blocked by `.githooks/pre-push`. All changes are developed on dedicated feature branches and merged via Pull Requests after passing CI checks.

---

## 🧰 Toolchain Baseline

`toolchain.json` is the single set of versions shared by this template and every app built on it; `tool/verify_toolchain.dart` checks a repository against it (CI and pre-commit run it with `--strict`).

| Area | Baseline 2026.10.1 |
| --- | --- |
| Flutter / Dart | 3.47.7 / `^3.13.5` |
| Android | AGP 9.4.1, Kotlin 2.4.21, Gradle 9.8.2, compileSdk 37, targetSdk 36, minSdk ≥ 24, Java 17, `kotlin.incremental=false` |
| Apple | iOS 15.0, macOS 12.0 |
| CI | `actions/checkout@v7`, `subosito/flutter-action@v2` |
| Packages | `flutter_riverpod ^3.4.3`, `shared_preferences ^2.5.6`, `flutter_lints ^6.0.0` |

To move every app forward: bump `toolchain.json` in the template first and verify it, then copy `toolchain.json` and `tool/verify_toolchain.dart` into each derived repository, fix what the tool reports and release. targetSdk stays on Flutter's default until a new target has been verified on devices.

---

## 🤖 AI Agent Workflow

AI coding agents (e.g., Claude, Gemini, GPT) working in this repository must follow:
- [AGENTS.md](AGENTS.md) (with symlinks [CLAUDE.md](CLAUDE.md) and [GEMINI.md](GEMINI.md)): Global agent guidelines and commit policies.
- [.agents/rules/architecture.md](.agents/rules/architecture.md): FSD v2.1 specifications.
- [.agents/rules/design-system.md](.agents/rules/design-system.md): Semantic design tokens and palette.
- [.agents/rules/form-factors.md](.agents/rules/form-factors.md): Multi-device layout guidelines.
- [.agents/rules/git-commits.md](.agents/rules/git-commits.md): Conventional Commits standard.
- [.agents/skills/setup-repo/SKILL.md](.agents/skills/setup-repo/SKILL.md): Environment inspection and onboarding skill.

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run architecture boundary audit specifically
flutter test test/architecture/fsd_architecture_test.dart
```

The suite covers the FSD auditor rules, breakpoints, settings persistence, the theme toggle, the device simulator, navigation and shortcuts, the hinge-aware foldable layout, and layout overflows across tiers.

---

## 📱 Platform Notes

- **Wear OS**: the watch layout runs inside the Android app, but publishing to Wear OS requires a watch-specific manifest (`uses-feature android.hardware.type.watch`, standalone meta-data), usually as a separate build flavor.
- **Android release signing**: `android/app/build.gradle.kts` still signs release builds with the debug key; configure your own keystore before publishing.
- **iOS / macOS**: building, signing and running on a device need a Mac with Xcode (set the signing Team in Xcode).
- **Android on Windows**: `kotlin.incremental=false` in `android/gradle.properties` avoids a Kotlin compiler failure when the pub cache and the project are on different drives.
- **Linux window control**: `WindowControlService` drag and resize rely on GTK pointer grabs, which work on X11 and are ignored by most Wayland compositors.

---

## 📄 License
MIT License. Free to use, adapt, and build upon.
