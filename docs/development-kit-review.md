# Development kit review

Reviewed baseline: `c8eff58` (version `2.0.0+2`), 2026-09-15.

## Purpose and execution flow

Agentic Template is a Flutter development kit for contributors working with AI coding assistants. Its development-time tools are `AGENTS.md`, `.agents/rules`, the setup skill, the FSD auditor, the Git hook, and CI. The running application is a sample of the kit's UI and state-management building blocks.

`main.dart` initializes shared-preference storage and injects it into Riverpod. `AgenticApp` applies theme and contrast settings. `HomePage` selects a layout from the real or simulated viewport and hosts Overview, Slices, and Settings. Overview demonstrates a counter; Slices explains the source structure; Settings controls appearance and device preview. Theme and contrast persist; the counter and preview selection are session state.

The repository contains Android, Windows, Linux, and Web platform projects. The circular preview is a UI layout; Wear OS distribution still requires the platform setup described in the README.

## Verified baseline

On Windows with Flutter 3.47.4 and Dart 3.13.3:

- Strict FSD audit: 40 Dart files, 124 directives, zero reported violations.
- Static analysis: no issues.
- Architecture test target: 5 tests passed; complete Flutter suite: 39 tests passed.
- Configured pre-commit hook: executed successfully.
- `bash build_web.sh`: completed WebAssembly and JavaScript fallback compilation and gzip generation. Flutter emitted a missing Cupertino font-family warning; the build exited successfully.
- Web sample: loaded and incremented the counter; desktop, smartphone, foldable, and watch previews were exercised.

These results describe the tested baseline. The UI edge cases below were reproduced by additional widget probes and are outside the existing baseline suite. Android, Windows native, Linux native, and physical-device release builds were not validated in this review.

## Improvements in this change

### Architecture checks for real template customization

The baseline auditor reads only the first URI on an import/export line. A conditional export from `shared` into `features` can execute the forbidden feature while `--strict` reports zero violations. Conversely, import-like text inside a block comment can trigger a false violation.

The baseline also recognizes only `package:agentic_template/`. After renaming the package, an internal `package:` import with the new name is treated as external, so the architecture check silently skips it.

The correction parses Dart directives, inspects conditional alternatives, and resolves the package identity of the project under audit. Regression fixtures exercise legal syntax as well as forbidden layer and slice dependencies.

### Setup results that reflect command outcomes

In an isolated clone with `flutter pub get` forced to exit 65, the baseline setup script prints that package installation completed and that all requirements are satisfied, then exits zero even though no package configuration exists. Executable presence and Visual Studio folder presence can also be mistaken for working SDKs and a complete native toolchain.

The correction checks command outcomes and the prerequisites for at least one usable development target. The regression suite uses isolated command stubs, without installing SDKs or changing the host's Flutter/Git configuration.

## Validation of the patch

- `dart run tool/verify_fsd.dart --strict`: zero violations on the application.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub test/architecture/fsd_architecture_test.dart`: 13 tests passed, including eight new regressions that failed on the baseline.
- `flutter test --no-pub`: 47 tests passed.
- `bash test/tool/setup_check_test.sh`: 20 isolated scenarios passed under Git Bash, covering SDK startup, package resolution, automatic fixes, target availability, and verification failures. Linux/macOS scenarios use command stubs; they are not native-host execution evidence.
- Live setup on the Windows host: Web prerequisites accepted, incomplete Visual Studio C++ toolchain correctly reported as a warning, exit zero. Connected device identifiers are omitted.

The new CI matrix schedules the setup regression suite on Linux and Windows. Hosted CI execution has not been observed as part of this local review. The parser dependencies (`analyzer`, `yaml`, `path`) are development dependencies; existing runtime dependency versions are unchanged.

## Remaining UI findings

All three are reproducible on the baseline and remain follow-up work; this change focuses on the development checks.

| Priority | Finding and reproduction | Suggested correction and verification |
| --- | --- | --- |
| P2 | The wide branch of `AdaptiveScaffold` omits system safe-area padding. With `AgenticApp` at 800x900 and top inset 32, the header title begins at y=14.5, inside the system area. | Apply safe-area insets to the wide layout and verify that fold/hinge coordinates remain correct. Test top, bottom, and side insets. |
| P2 | At 720x900 with system text scaling 2.0, the foldable detail pane produces horizontal overflows in action buttons (up to 116 px) and the title/badge row (43 px). Small overflows also occur at width 600 with standard text. | Let labels and the badge fit the available width, and let buttons grow vertically when text wraps. Cover widths 600 and 720 at normal and enlarged text scales. |
| P2 | The circular `ThemeToggleButton()` exposes a button label but no semantic tap action: `excludeSemantics` removes the inner `InkWell` action and the outer `Semantics` has no `onTap`. The desktop/foldable header uses this variant; the compact header and Settings use the menu variant. | Share the theme-switch callback with the semantic tap action. Verify both the action's presence and that invoking it changes the theme. |

Relevant source: [wide scaffold](../lib/widgets/adaptive_scaffold/ui/adaptive_scaffold.dart), [buttons](../lib/shared/ui/primitives/app_button.dart), [action card](../lib/features/sample_action/ui/action_trigger_card.dart), [theme toggle](../lib/features/theme_toggle/ui/theme_toggle_button.dart).

## Contribution priorities

1. Keep the kit's setup and automated architecture checks trustworthy when a contributor customizes the template.
2. Correct and test the reproduced accessibility and responsive-layout cases above.
3. Add release-build checks for the platforms maintainers intend to support; keep build success separate from real-device behavior.

The existing sample is sufficient to demonstrate the development workflow. Additional sample features should each teach a reusable pattern and include a small, executable verification example.
