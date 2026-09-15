import 'dart:async';
import 'dart:convert';

import 'package:agentic_template/features/github_repository/github_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _repositoryJson = {
  'full_name': 'Cris92bb/Agentic-template',
  'description': 'A Flutter template — for every screen.',
  'stargazers_count': 42,
  'pushed_at': '2026-09-15T08:30:00Z',
};

http.Response _response(Object? body) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  200,
  headers: {'content-type': 'application/json'},
);

Matcher _errorContaining(String message) =>
    isA<GithubRepositoryException>().having(
      (error) => error.message,
      'message',
      allOf(contains(message), isNot(contains('private error'))),
    );

class _TrackingClient extends MockClient {
  _TrackingClient(super.fn);

  bool closed = false;

  @override
  void close() {
    closed = true;
    super.close();
  }
}

void main() {
  group('GithubRepositoryClient', () {
    test(
      'fetches the public repository with the requested API contract',
      () async {
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          return _response(_repositoryJson);
        });
        addTearDown(client.close);

        final repository = await GithubRepositoryClient(client).fetch();

        expect(requests, hasLength(1));
        expect(requests.single.method, 'GET');
        expect(
          requests.single.url.toString(),
          'https://api.github.com/repos/Cris92bb/Agentic-template',
        );
        expect(
          requests.single.headers['accept'],
          'application/vnd.github+json',
        );
        expect(requests.single.headers['x-github-api-version'], '2026-03-10');
        expect(requests.single.headers['user-agent'], isNotEmpty);
        expect(repository.fullName, 'Cris92bb/Agentic-template');
        expect(
          repository.description,
          'A Flutter template — for every screen.',
        );
        expect(repository.stars, 42);
        expect(repository.pushedAt, DateTime.utc(2026, 9, 15, 8, 30));
      },
    );

    test('accepts absent optional repository metadata', () async {
      final client = MockClient(
        (_) async => _response({
          'full_name': 'Cris92bb/Agentic-template',
          'description': null,
          'stargazers_count': 0,
          'pushed_at': null,
        }),
      );
      addTearDown(client.close);

      final repository = await GithubRepositoryClient(client).fetch();

      expect(repository.fullName, 'Cris92bb/Agentic-template');
      expect(repository.description, isNull);
      expect(repository.pushedAt, isNull);
      expect(repository.stars, 0);
    });

    for (final (status, message) in [
      (404, 'not be found'),
      (403, 'limiting requests'),
      (429, 'limiting requests'),
      (500, 'unavailable'),
    ]) {
      test('turns HTTP $status into a friendly error', () async {
        final client = MockClient(
          (_) async => http.Response('private error', status),
        );
        addTearDown(client.close);

        await expectLater(
          GithubRepositoryClient(client).fetch(),
          throwsA(_errorContaining(message)),
        );
      });
    }

    for (final (label, body) in [
      ('non-object JSON', <Object>[]),
      ('missing required fields', <String, Object?>{}),
      ('invalid stars', {..._repositoryJson, 'stargazers_count': '42'}),
      ('negative stars', {..._repositoryJson, 'stargazers_count': -1}),
      ('invalid description', {..._repositoryJson, 'description': 123}),
      ('invalid date', {..._repositoryJson, 'pushed_at': 'not-a-date'}),
    ]) {
      test('rejects $label with a friendly response error', () async {
        final client = MockClient((_) async => _response(body));
        addTearDown(client.close);

        await expectLater(
          GithubRepositoryClient(client).fetch(),
          throwsA(_errorContaining('unexpected response')),
        );
      });
    }

    test('does not expose malformed JSON in its error', () async {
      final client = MockClient(
        (_) async => http.Response('private error', 200),
      );
      addTearDown(client.close);

      await expectLater(
        GithubRepositoryClient(client).fetch(),
        throwsA(_errorContaining('unexpected response')),
      );
    });

    test('turns transport failures into connection guidance', () async {
      final client = MockClient(
        (_) async => throw http.ClientException('private error'),
      );
      addTearDown(client.close);

      await expectLater(
        GithubRepositoryClient(client).fetch(),
        throwsA(_errorContaining('Check your connection')),
      );
    });

    testWidgets('stops waiting after ten seconds', (tester) async {
      final response = Completer<http.Response>();
      final client = MockClient((_) => response.future);
      addTearDown(client.close);
      Object? outcome;
      var settled = false;
      final future = GithubRepositoryClient(client).fetch().then<void>(
        (repository) {
          outcome = repository;
          settled = true;
        },
        onError: (Object error) {
          outcome = error;
          settled = true;
        },
      );

      await tester.pump(const Duration(seconds: 9));
      expect(settled, isFalse);
      await tester.pump(const Duration(seconds: 1));
      expect(settled, isTrue);
      expect(outcome, _errorContaining('timed out'));
      await future;
      response.complete(_response(_repositoryJson));
      await tester.pump();
    });
  });

  group('githubRepositoryProvider', () {
    test('keeps loaded data until an explicit refresh fetches again', () async {
      var requests = 0;
      final client = _TrackingClient((_) async {
        requests++;
        return _response({..._repositoryJson, 'stargazers_count': requests});
      });
      addTearDown(client.close);
      final container = ProviderContainer(
        overrides: [githubRepositoryClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      expect((await container.read(githubRepositoryProvider.future)).stars, 1);
      await container.pump();
      expect((await container.read(githubRepositoryProvider.future)).stars, 1);
      expect(requests, 1);

      container.invalidate(githubRepositoryProvider);

      expect((await container.read(githubRepositoryProvider.future)).stars, 2);
      expect(requests, 2);
      expect(client.closed, isFalse);
    });

    test('closes its owned HTTP client when the scope is disposed', () async {
      final client = _TrackingClient((_) async => _response(_repositoryJson));

      await http.runWithClient(() async {
        final container = ProviderContainer();
        await container.read(githubRepositoryProvider.future);

        expect(client.closed, isFalse);
        container.dispose();
        expect(client.closed, isTrue);
      }, () => client);
    });
  });
}
