import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:agentic_template/app/theme/app_theme.dart';
import 'package:agentic_template/features/github_repository/github_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _repository = GithubRepository(
  fullName: 'Cris92bb/Agentic-template',
  description: 'A Flutter development kit for connected applications.',
  stars: 42,
  pushedAt: DateTime.utc(2026, 9, 15),
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required Future<GithubRepository> Function() load,
  double width = 390,
  double textScale = 1,
  bool compact = false,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [githubRepositoryProvider.overrideWith((ref) => load())],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: GithubRepositoryCard(compact: compact),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows loading until the repository arrives', (tester) async {
    final response = Completer<GithubRepository>();
    await _pumpCard(tester, load: () => response.future);
    expect(find.text('GitHub project'), findsOneWidget);
    expect(find.text('Loading repository…'), findsOneWidget);
    response.complete(_repository);
    await tester.pumpAndSettle();
    expect(find.text(_repository.fullName), findsOneWidget);
    expect(find.text(_repository.description!), findsOneWidget);
    expect(find.text('42 stars'), findsOneWidget);
    expect(find.text('Last push · Sep 15, 2026'), findsOneWidget);
  });

  testWidgets('retry recovers from an error and refresh replaces data', (
    tester,
  ) async {
    var calls = 0;
    await _pumpCard(
      tester,
      load: () async {
        calls++;
        if (calls == 1) {
          throw const GithubRepositoryException('Repository not found.');
        }
        return GithubRepository(
          fullName: _repository.fullName,
          description: null,
          stars: calls,
          pushedAt: null,
        );
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('Repository not found.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('2 stars'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('3 stars'), findsOneWidget);
  });

  testWidgets(
    'fits a narrow pane with enlarged text and an accessible refresh',
    (tester) async {
      await _pumpCard(
        tester,
        load: () async => _repository,
        width: 240,
        textScale: 2,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('42 stars'), findsOneWidget);
      final button = find.widgetWithText(OutlinedButton, 'Refresh');
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      final semantics = tester.ensureSemantics();
      expect(
        tester
            .getSemantics(button)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      semantics.dispose();
    },
  );

  testWidgets('compact card fits the circular watch safe width', (
    tester,
  ) async {
    await _pumpCard(
      tester,
      load: () async => _repository,
      width: 132,
      compact: true,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('42 stars'), findsOneWidget);
    expect(find.text(_repository.description!), findsNothing);
    expect(
      tester.getSize(find.byType(GithubRepositoryCard)).height,
      lessThanOrEqualTo(132),
    );
  });
}
