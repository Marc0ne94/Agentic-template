# Changelog

## Unreleased

### Added
- Toolchain baseline 2026.10.1: `toolchain.json` with one shared set of versions, checked by `tool/verify_toolchain.dart` in CI and in the pre-commit hook.
- iOS and macOS runners (`flutter create`, bundle id `com.template.agenticTemplate`).

### Changed
- Toolchain: Flutter 3.47.7 in CI, Dart `^3.13.5`, `actions/checkout@v7`, `shared_preferences` 2.5.6 with the lockfile upgraded.
- Android: AGP 9.4.1, Kotlin 2.4.21, Gradle 9.8.2 and compileSdk 37.
- Android: Kotlin incremental compilation disabled, as it fails on Windows when the pub cache and the project are on different drives.

## 2.0.0

### Fixed
- **Device simulator**: watch mode no longer hides the device picker (there was no way back); the preview frame renders inside a `Material` (no red, underlined error text); layouts receive the inner viewport size instead of the outer frame size; Desktop simulated in a narrow window uses a scaled 1280×800 preview instead of the desktop layout in a phone-sized box.
- **Layout overflows** on phones, in the foldable detail pane and in the watch view.
- A short but wide window is no longer detected as a wearable.
- Theme and high-contrast preferences now persist across restarts (the storage adapter was never wired).
- **FSD audit**: `--strict` is honored, `export` directives are scanned, deep imports that bypass a public barrel are reported, and imports between `app`/`shared` segments are no longer false cross-slice violations. The architecture test reuses the auditor instead of a copy of its logic.
- An `AppButton` test that could never fail now checks the disabled and loading states.
- Dark theme `secondary` color no longer matches the surface; dark-mode accent icons meet contrast guidelines.
- **Linux runner**: method channels are released on dispose and the window channel no longer holds a dangling window pointer.
- **Scripts**: the `.desktop` launcher no longer hardcodes the original author's home directory; builds work without the executable bit and on arm64 Linux; gzip errors are no longer hidden.
- **Web**: real app name, description and colors in `index.html` and `manifest.json`; orientation is no longer locked to portrait.

### Added
- Slices and Settings destinations, with Ctrl/⌘ + 1–3 keyboard shortcuts.
- High-contrast light and dark themes with a Settings switch.
- `AppPalette` theme extension replacing per-widget `isDark` color branching.
- Theme button cycles System → Light → Dark with a 44×44 touch target.
- Hinge-aware foldable layout using `MediaQuery.displayFeatures`.
- `WindowControlService`, a Dart API for the Linux `app/window` channel.
- Windows desktop runner.
- `install_desktop_entry.sh` and a GitHub Actions workflow (analyze, FSD audit, tests).
- Tests for the HomePage across tiers, navigation, shortcuts, settings persistence, the theme toggle, the hinge layout and the FSD auditor rules.

### Changed
- `ProviderScope` moved from `AgenticApp` to `main()`: wrap `AgenticApp` in a `ProviderScope` when using it directly (for example in tests).
- `WearableUtils.maxWatchShortestSide` is deprecated in favor of `maxWatchSide`, and both display sides must fit within it.
- `StatusBadge` renders its icon and label as a single rich text; use `find.textContaining` to find it in tests.

## 1.0.0
- Initial template.
