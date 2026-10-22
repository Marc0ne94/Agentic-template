# Agent Guidelines for Agentic Template Repository

These instructions apply to all AI coding agents working on this project.

## Code Quality & Architecture Standards

### 1. File Size & Modularity Standard (<= 300 LOC)
- **Hard Target**: Dart source files should ideally **not cross 300 lines of code (LOC)** per file.
- **Componentization**: Large classes, complex modals, monolithic views, and oversized builders must be broken down into modular, single-responsibility sub-components in dedicated `components/` or `views/` subdirectories.
- **Doctype & Documentation Comments**: Every component, class, method, and state provider must have rich Dart doc comments (`///`) describing its role, behavioral mechanics, parameter contracts, and architectural layer.

### 2. Strict Design Token Consistency & Zero Hardcoded Colors
- **Zero Hardcoded Colors**: Raw `Color(0x...)` or random hex literals are strictly forbidden across UI components.
- **Single Source of Truth**: All colors, borders, shadows, radii, and animations must be sourced directly from `AppTokens`, `AppPalette.of(context)`, or `Theme.of(context)`. Never branch on `isDark` directly in widgets.
- **Palette Integrity**: Preserve the defined light, dark, and high-contrast palettes without visual fragmentation.

### 3. Strict Feature-Sliced Design (FSD v2.1) Compliance
- Maintain strict unidirectional layer hierarchy:
  $$\text{app} \succ \text{pages} \succ \text{widgets} \succ \text{features} \succ \text{entities} \succ \text{shared}$$
- A file in a layer may **ONLY** import from layers strictly below it.
- **Rule of Cross-Slice Isolation**: Slices residing in the same layer (`features`, `entities`, `widgets`) must **NEVER** import directly from sibling slices. Cross-slice orchestration occurs at higher layers (`widgets` or `pages`).
- **Public API Barrels**: Slices must expose their public interface via `<slice>.dart`. Never perform deep internal segment imports from outside the slice.
- **Automated Verification**: Run `dart run tool/verify_fsd.dart --strict` and `flutter test test/architecture/fsd_architecture_test.dart`. Zero violations are tolerated.

### 4. Multi-Platform & Form-Factor Compatibility
When building or updating UI:
- **Wearable (Smartwatch / Wear OS)**: Both sides $\le 320.0$, circular screen safe padding (`WearableUtils.getSafeCircularPadding`), glanceable cards, high contrast.
- **Smartphone**: Portrait single-pane layout, touch targets $\ge 44 \times 44$, safe area insets.
- **Foldable**: Dual-pane master-detail reacting smoothly when unfolded ($600 \le \text{width} < 1024$), split along reported hinges.
- **Desktop & Web**: Responsive navigation rail, keyboard shortcuts (Ctrl/⌘ + 1–3), mouse hover states, window controls (`WindowControlService` on Linux).

## Mandatory Git Commits for Impactful Changes

You MUST create a Git commit for every impactful change made to this repository.

### When to Commit
- New feature implementation or enhancement (UI widgets, pages, state management).
- Bug fixes and layout adjustments.
- Window management, GTK runner, or platform channel modifications.
- Configuration or build script changes (`build_release.sh`, `launch_app.sh`, `pubspec.yaml`).
- Documentation updates (`README.md`, guides, architecture references).
- Test additions or updates.

### Commit Requirements
1. **Verification First**: Validate changes before committing (run `flutter test`, `flutter analyze`, `dart run tool/verify_fsd.dart --strict` and `dart run tool/verify_toolchain.dart --strict`).
2. **Code & Documentation Consistency**: Before committing code changes, always inspect related documentation markdown files (`README.md`, `docs/`, `.agents/rules/`). Verify that architecture trees, models, APIs, shortcuts, tokens, breakpoints, and workflows in the documentation accurately reflect the active code, and update the documentation in lockstep.
3. **Conventional Commits Format**:
   - `feat(...)`: new features or capabilities
   - `fix(...)`: bug and layout fixes
   - `docs(...)`: documentation updates
   - `style(...)`: styling, theme, and UI adjustments
   - `refactor(...)`: structural code improvements
   - `test(...)`: test additions and updates
   - `chore(...)`: build scripts, configs, launcher shortcuts, dependencies
4. **Clean Staging**: Stage only the files associated with the change. Never commit temporary files, logs, or build artifacts.

## Branching & Pull Request Policy

- **Merge to `develop` Only via PR**: Direct pushes to `develop` or `main` are strictly forbidden. All changes must be developed on dedicated branches (`feat/...`, `fix/...`, `chore/...`) and merged into `develop` exclusively through a Pull Request.
- **CI Quality Checks**: Every PR must pass all CI checks (FSD architecture verification, AST static analysis, and automated tests) before merging.
