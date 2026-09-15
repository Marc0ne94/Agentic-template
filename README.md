# Agentic Template for Flutter

A clean, modular Flutter template designed from first principles for **AI agentic pair-programming** and modern multi-device applications, based on architectural patterns from [Pin](https://github.com/cris92bb/Pin).

### What "agentic" means here

This is a **Flutter development kit for working with AI coding assistants**. The kit combines a runnable UI sample, reusable components, architecture rules, an environment setup skill, and automated checks. The agent instructions guide development in your editor; the sample app demonstrates layouts, navigation, preferences, and local state. An agent execution service or an LLM integration would be an application feature to build on top of this foundation.

See the [development kit review](docs/development-kit-review.md) for verified capabilities, fixes, and remaining improvement areas.

It follows **Feature-Sliced Design (FSD v2.1)**, checked automatically by an import scanner and tests, and ships responsive layouts for:
- ⌚ **Wearable**: circular watch displays with safe insets and a glanceable UI
- 📱 **Smartphone**: single-column layout with bottom navigation and 44×44 touch targets
- 📖 **Foldable / Tablet**: dual-pane layout, split along the hinge when the device reports one
- 🌐 **Web**: WASM-GC build script and PWA manifest
- 🖥️ **Desktop (Windows, Linux)**: navigation rail and keyboard shortcuts; on Linux a native GTK runner with theme sync, a window-control channel and a `.desktop` launcher

What's new in 2.0: see [CHANGELOG.md](CHANGELOG.md).

---

## 🚀 Quick Start

### 1. Check Environment & Prerequisites
Audit host OS, Git, Flutter/Dart SDKs, desktop/web build toolchains, and packages:

On Windows, run this diagnostic script in **Git Bash**. The `flutter` and `dart` commands below also work directly in PowerShell once the Flutter SDK is on PATH.

```bash
bash .agents/skills/setup-repo/scripts/setup_check.sh

# Or auto-enable missing platform flags and fetch packages:
bash .agents/skills/setup-repo/scripts/setup_check.sh --fix
```

### 2. Run the App
```bash
flutter pub get
flutter run -d windows   # or: -d linux, -d chrome
```

### 3. Verify Architecture & Tests
```bash
# FSD import audit (exits with an error on violations)
dart run tool/verify_fsd.dart --strict

# Static analysis and the full test suite
flutter analyze
flutter test
```
CI runs the same checks on every push to `main` and on pull requests (`.github/workflows/ci.yml`).

A git pre-commit hook is included in `.githooks/pre-commit` to prevent committing code if FSD architecture rules, AST static analysis, or architecture tests fail:
```bash
git config core.hooksPath .githooks
```

### 4. Build Production Releases
```bash
# Windows desktop bundle (Windows host)
flutter build windows --release

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

All three rules are checked by `tool/verify_fsd.dart`, using the Dart parser to inspect `import` and `export` directives, including conditional alternatives. The auditor reads the package name from `pubspec.yaml`, so internal `package:` imports remain checked after renaming the template. `test/architecture/fsd_architecture_test.dart` exercises both the application and regression fixtures.

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

See [.agents/rules/design-system.md](.agents/rules/design-system.md).

---

## 🤖 AI Agent Workflow

AI coding agents (e.g., Claude, Gemini, GPT) working in this repository must follow:
- [AGENTS.md](AGENTS.md): Global agent guidelines and commit policies.
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

# Check setup behavior with isolated SDK/toolchain stubs (Git Bash on Windows)
bash test/tool/setup_check_test.sh
```

The suite covers the FSD auditor rules, breakpoints, settings persistence, the theme toggle, the device simulator, navigation and shortcuts, the hinge-aware foldable layout, and layout overflows across tiers.

The setup regression suite exercises missing and failing prerequisites, failed automatic fixes, and Web-only development without a native desktop toolchain. CI runs it on Linux and Windows. It does not download SDKs or alter the host's Git/Flutter configuration.

---

## 📱 Platform Notes

- **Wear OS**: the watch layout runs inside the Android app, but publishing to Wear OS requires a watch-specific manifest (`uses-feature android.hardware.type.watch`, standalone meta-data), usually as a separate build flavor.
- **Android release signing**: `android/app/build.gradle.kts` still signs release builds with the debug key; configure your own keystore before publishing.
- **Linux window control**: `WindowControlService` drag and resize rely on GTK pointer grabs, which work on X11 and are ignored by most Wayland compositors.

---

## 📄 License
MIT License. Free to use, adapt, and build upon.
