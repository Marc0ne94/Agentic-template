import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../model/github_repository.dart';

class GithubRepositoryException implements Exception {
  const GithubRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GithubRepositoryClient {
  GithubRepositoryClient(this._client);

  final http.Client _client;

  /// Loads the public template repository without authentication or retries.
  Future<GithubRepository> fetch() async {
    try {
      final response = await _client
          .get(
            Uri.parse('https://api.github.com/repos/Cris92bb/Agentic-template'),
            headers: {
              'Accept': 'application/vnd.github+json',
              'X-GitHub-Api-Version': '2026-03-10',
              if (!kIsWeb) 'User-Agent': 'Agentic-template',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 404) {
        throw const GithubRepositoryException(
          'This repository could not be found.',
        );
      }
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw const GithubRepositoryException(
          'GitHub is limiting requests. Please try again later.',
        );
      }
      if (response.statusCode != 200) {
        throw const GithubRepositoryException(
          'GitHub is unavailable right now. Please try again.',
        );
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a repository object.');
      }
      return GithubRepository.fromJson(decoded);
    } on TimeoutException {
      throw const GithubRepositoryException(
        'The GitHub request timed out. Please try again.',
      );
    } on http.ClientException {
      throw const GithubRepositoryException(
        'Could not connect to GitHub. Check your connection and try again.',
      );
    } on FormatException {
      throw const GithubRepositoryException(
        'GitHub returned an unexpected response. Please try again.',
      );
    }
  }
}
