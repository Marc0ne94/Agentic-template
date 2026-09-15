import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../api/github_repository_client.dart';
import '../model/github_repository.dart';

final githubRepositoryClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Keeps the last result across layout changes; invalidate to refresh it.
final githubRepositoryProvider = FutureProvider<GithubRepository>((ref) {
  return GithubRepositoryClient(ref.watch(githubRepositoryClientProvider))
      .fetch();
});
