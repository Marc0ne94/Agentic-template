import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:agentic_template/features/github_repository/github_repository.dart';
import 'package:agentic_template/pages/home/views/fold_home_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpFoldView(
  WidgetTester tester, {
  List<DisplayFeature> displayFeatures = const [],
}) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        githubRepositoryProvider.overrideWith((ref) async => const GithubRepository(
          fullName: 'Cris92bb/Agentic-template', description: null,
          stars: 42, pushedAt: null,
        )),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              displayFeatures: displayFeatures,
            ),
            child: const Scaffold(body: FoldHomeView()),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('FoldHomeView', () {
    testWidgets('uses a 5:6 split with a divider when there is no hinge',
        (tester) async {
      await _pumpFoldView(tester);

      expect(find.byType(VerticalDivider), findsOneWidget);
    });

    testWidgets('splits the panes along a vertical hinge', (tester) async {
      await _pumpFoldView(
        tester,
        displayFeatures: const [
          DisplayFeature(
            bounds: Rect.fromLTRB(390, 0, 410, 900),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      );

      expect(
        tester.getSize(find.byKey(FoldHomeView.masterPaneKey)).width,
        390,
      );
      expect(find.byType(VerticalDivider), findsNothing);
    });
  });
}
