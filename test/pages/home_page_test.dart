import 'package:agentic_template/app/app.dart';
import 'package:agentic_template/features/github_repository/github_repository.dart';
import 'package:agentic_template/shared/shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      githubRepositoryProvider.overrideWith((ref) async => const GithubRepository(
        fullName: 'Cris92bb/Agentic-template', description: 'Connected example',
        stars: 42, pushedAt: null,
      )),
    ],
    child: const AgenticApp(),
  ));
  await tester.pumpAndSettle();
}

/// Taps a device chip in the wide header picker.
Future<void> _tapDeviceChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Selects a device from the compact popup picker.
Future<void> _selectFromPopup(WidgetTester tester, String label) async {
  // The Settings destination also hosts a picker, offstage in the IndexedStack.
  await tester.tap(find.byTooltip('Simulate Device Viewport').hitTestable());
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(720, 900),
    const Size(1280, 800),
    const Size(220, 220),
  ]) {
    testWidgets('Overview includes the GitHub example at $size', (tester) async {
      await _pumpApp(tester, size);
      expect(find.text('GitHub project'), findsOneWidget);
      expect(find.text('42 stars'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  group('HomePage smoke tests', () {
    testWidgets('phone layout has no overflow after incrementing the counter',
        (tester) async {
      await _pumpApp(tester, const Size(390, 844));
      await tester.ensureVisible(find.text('Increment'));
      await tester.tap(find.text('Increment'));
      await tester.pumpAndSettle();

      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('fold layout has no overflow after incrementing the counter',
        (tester) async {
      await _pumpApp(tester, const Size(720, 900));
      await tester.ensureVisible(find.text('Increment'));
      await tester.tap(find.text('Increment'));
      await tester.pumpAndSettle();

      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('watch simulation keeps the device picker reachable',
        (tester) async {
      await _pumpApp(tester, const Size(1280, 800));
      await _tapDeviceChip(tester, 'Watch (Wear OS)');
      expect(find.text('WATCH VIEW'), findsOneWidget);

      await _selectFromPopup(tester, 'Auto Detect');
      expect(find.text('WATCH VIEW'), findsNothing);
    });

    testWidgets('simulation banner is not rendered with the error text style',
        (tester) async {
      await _pumpApp(tester, const Size(1280, 800));
      await _tapDeviceChip(tester, 'Smartphone');

      final bannerContext = tester.element(find.textContaining('Simulating'));
      expect(
        DefaultTextStyle.of(bannerContext).style.decoration,
        isNot(TextDecoration.underline),
      );
    });

    testWidgets('phone simulation reports the inner viewport size of the frame',
        (tester) async {
      await _pumpApp(tester, const Size(1280, 800));
      await _tapDeviceChip(tester, 'Smartphone');

      final viewContext = tester.element(find.text('Smartphone Tier (Compact)'));
      expect(MediaQuery.sizeOf(viewContext), const Size(374, 764));
    });

    testWidgets('desktop simulation in a narrow window has no overflow',
        (tester) async {
      await _pumpApp(tester, const Size(390, 844));
      await _selectFromPopup(tester, 'Desktop / Web');

      expect(find.text('Desktop & Web Workspace (Tier 4)'), findsOneWidget);
    });
  });

  group('HomePage navigation', () {
    Finder railDestination(String label) => find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(label),
        );

    testWidgets('rail destinations switch the visible view', (tester) async {
      await _pumpApp(tester, const Size(1280, 800));

      await tester.tap(railDestination('Slices'));
      await tester.pumpAndSettle();
      expect(find.text('features').hitTestable(), findsOneWidget);

      await tester.tap(railDestination('Settings'));
      await tester.pumpAndSettle();
      expect(find.text('High contrast').hitTestable(), findsOneWidget);
    });

    testWidgets('Ctrl+3 opens Settings and Ctrl+1 returns to Overview',
        (tester) async {
      await _pumpApp(tester, const Size(1280, 800));

      Future<void> pressCtrl(LogicalKeyboardKey key) async {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
      }

      await pressCtrl(LogicalKeyboardKey.digit3);
      expect(find.text('High contrast').hitTestable(), findsOneWidget);

      await pressCtrl(LogicalKeyboardKey.digit1);
      expect(
        find.text('Desktop & Web Workspace (Tier 4)').hitTestable(),
        findsOneWidget,
      );
    });

    testWidgets('high contrast setting applies the high contrast palette',
        (tester) async {
      await _pumpApp(tester, const Size(1280, 800));
      await tester.tap(railDestination('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      final palette = AppPalette.of(tester.element(find.text('High contrast')));
      expect(
        palette.textSecondary,
        AppPalette.highContrastLight.textSecondary,
      );
    });
  });
}
