import 'package:agentic_template/widgets/adaptive_scaffold/adaptive_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdaptiveScaffold', () {
    testWidgets('renders navigation destinations and title in compact mode', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int selected = 0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AdaptiveScaffold(
              title: 'Test App',
              selectedIndex: selected,
              onDestinationSelected: (i) => selected = i,
              destinations: const [
                NavigationDestinationItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Home',
                ),
                NavigationDestinationItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: 'Settings',
                ),
              ],
              body: const Text('Body Content'),
            ),
          ),
        ),
      );

      expect(find.text('Test App'), findsOneWidget);
      expect(find.text('Body Content'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('wide layout respects vertical system insets after resizing', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(top: 32, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      const bodyKey = ValueKey('wide-body');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AdaptiveScaffold(
              title: 'Wide App',
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: const [
                NavigationDestinationItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Home',
                ),
                NavigationDestinationItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: 'Settings',
                ),
              ],
              body: const SizedBox.expand(key: bodyKey),
            ),
          ),
        ),
      );

      void expectSafeLayout(double width) {
        final rail = tester.getRect(find.byType(NavigationRail));
        final body = tester.getRect(find.byKey(bodyKey));
        expect(tester.getRect(find.text('Wide App')).top, greaterThanOrEqualTo(32));
        expect(rail.top, greaterThanOrEqualTo(32));
        expect(rail.bottom, lessThanOrEqualTo(876));
        expect(body.bottom, lessThanOrEqualTo(876));
        expect(rail.left, 0);
        expect(body.right, width);
      }

      expectSafeLayout(800);
      tester.view.physicalSize = const Size(1200, 900);
      await tester.pumpAndSettle();
      expectSafeLayout(1200);
    });
  });
}
