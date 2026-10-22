# Multi-Device & Form Factor Guide

This project is built from the ground up to support modern multi-device form factors:

1. **Wearable (Wear OS & Smartwatches)**
2. **Smartphone (Portrait Compact)**
3. **Foldable & Tablet (Unfolded Dual-Pane)**
4. **Web & Desktop (Windows, macOS, Linux — Expanded Multi-Column)**

---

## 1. Breakpoint Philosophy

Breakpoints are centralized in `lib/shared/ui/breakpoints.dart`:

```dart
enum ScreenTier {
  /// Smartwatches / Wear OS (both display sides <= 320 logical pixels)
  wearable,

  /// Smartphones & Folded devices (width < 600)
  compact,

  /// Foldables unfolded & Tablets (600 <= width < 1024)
  foldOrTablet,

  /// Desktop monitors & wide Web browsers (width >= 1024)
  desktopWeb,
}
```

A viewport is a wearable only when **both** sides are small, so a short but wide desktop or browser window keeps the desktop layout.

### Usage:
```dart
final tier = Breakpoints.getTier(context);
if (tier == ScreenTier.wearable) {
  return const WearableHomeView();
}
```

---

## 2. Wearable (Smartwatch) Implementation

Smartwatches present unique constraints:
- **Circular Display Insets**: Square viewports clip corners on circular screens. Use `WearableUtils.getSafeCircularPadding(context)` to compute the maximal inscribed rectangular padding.
- **Fit the safe area**: Glanceable content should scale down (e.g. `FittedBox(fit: BoxFit.scaleDown)`) rather than overflow on small faces.
- **Gesture Conflict Resolution**: Smartwatch OSes use horizontal edge-swipes to dismiss applications. Prefer vertical scrolling, or custom `ScrollPhysics` that only allow one horizontal direction.
- **Glanceable Hierarchy**: Display large typography, concise counters, high contrast, and large touch zones.
- **OLED Black Splash Screen & Circular Icon**: Smartwatch builds should configure the splash screen window background to pure `#000000` black (`values-watch/` and `values-watch-v31/`) to blend into circular bezels during process startup, and provide a round launcher icon (`android:roundIcon`).
- **Publishing**: the watch layout runs inside the Android app, but a Wear OS release needs a watch-specific manifest (`uses-feature android.hardware.type.watch`, standalone meta-data), typically as a separate build flavor.

---

## 3. Smartphone & Foldable Implementation

- **Smartphone**: Single-pane layout with bottom navigation or compact app bar. Touch targets must follow mobile platform minimum guidelines ($44 \times 44$ pt).
- **Foldable (Unfolded)**: Dual-pane layout dividing the screen into master and detail surfaces. `FoldHomeView` reads `MediaQuery.displayFeaturesOf(context)` and splits the panes along a vertical hinge or fold when the device reports one, falling back to a 5:6 split.
- Keep navigation state above the tier views (as `HomePage` does) so it survives fold/unfold transitions.

---

## 4. Web & Desktop Implementation

- **Desktop Workspace**: Navigation rail, multi-column dashboard, and keyboard shortcuts — **Ctrl + 1 / 2 / 3** (⌘ on macOS) switch destinations.
- **Windows**: standard Flutter Windows runner (`flutter run -d windows`, `flutter build windows`).
- **Linux GTK Integration**:
  - Window theme synchronization via `MethodChannel('app/theme')` (`PlatformThemeService`).
  - Window drag, edge resize and close via `MethodChannel('app/window')`, exposed in Dart as `WindowControlService`. Drag and resize rely on GTK pointer grabs: they work on X11 and are ignored by most Wayland compositors.
  - `.desktop` launcher installed with `install_desktop_entry.sh`, plus `launch_app.sh` and `build_release.sh`.
- **Web**:
  - WASM-GC compilation via `build_web.sh`.
  - Smooth multi-device scroll behavior with `AppScrollBehavior`.

---

## 5. Built-in In-App Form Factor Simulator

For rapid prototyping and AI testing without physical hardware or multiple emulators:
- The template includes `DeviceSimulatorPicker` and `FormFactorPreviewFrame`.
- Select **Auto**, **Watch (Wear OS) 220×220**, **Smartphone 390×780**, **Foldable (Unfolded) 720×760**, or **Desktop** from the header, the app bar or Settings.
- The frame passes the inner viewport size (bezel excluded) to layouts, clears host insets and hinges, and scales down when the window is smaller than the device. In watch mode the picker is shown next to the frame; Desktop simulated in a window narrower than 1024px uses a scaled 1280×800 preview.
